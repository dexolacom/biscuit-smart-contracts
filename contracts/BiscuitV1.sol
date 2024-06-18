// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import {IWETH} from "@uniswap/swap-router-contracts/contracts/interfaces/IWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {OracleLibrary} from "./libraries/OracleLibrary.sol";
import {PortfolioManager} from "./PortfolioManager.sol";

error NotContract(address account);
error PortfolioDoesNotExist();
error PortfolioManagerAlreadySet();
error PortfolioManagerNotSet();
error PortfolioIsDisabled();
error ValueUnchanged();
error PoolDoesNotExist();
error NotApprovedOrOwner();
error MixedPaymentNotAllowed();
error PaymentAmountZero();
error WithdrawFailed();
error ETHTransferFailed();

contract BiscuitV1 is ERC721, AccessControl {
    using SafeERC20 for IERC20;

    struct PurchasedToken {
        address token;
        uint256 amount;
    }

    struct PurchasedPortfolio {
        bool purchasedWithETH;
        PurchasedToken[] purchasedTokens;
    }

    IUniswapV3Factory public immutable UNISWAP_FACTORY;
    IV3SwapRouter public immutable SWAP_ROUTER;
    IERC20 public immutable TOKEN;
    IWETH public immutable WETH;

    PortfolioManager public portfolioManager;

    uint256 public constant BIPS = 100_00;
    uint256 public constant SLIPPAGE_MULTIPLIER = BIPS - 5_00;
    uint256 public constant DEFAULT_TRANSACTION_TIMEOUT = 15 minutes;
    uint24 public constant DEFAULT_POOL_FEE = 3_000;

    // Time interval during that price will be taken between current pair
    uint32 public secondsAgo = 2 hours;
    uint256 public serviceFee = 1_00;
    uint256 public tokenId;

    mapping(uint256 => PurchasedPortfolio) public purchasedPortfolios;

    event PortfolioManagerSet(address indexed portfolioManager);
    event PortfolioPurchased(uint256 indexed portfolioId, address indexed buyer, uint256 amountToken, uint256 amountETH);
    event PortfolioSold(uint256 indexed tokenId, address indexed seller);

    event SecondsAgoUpdated(uint32 newSecondsAgo);
    event ServiceFeeUpdated(uint256 serviceFee);

    constructor(
        address _admin,
        address _uniswapFactory,
        address _swapRouter,
        address _token,
        address _weth
    ) ERC721("BiscuitV1", "BSC") {
        _checkIsContract(_uniswapFactory);
        _checkIsContract(_swapRouter);
        _checkIsContract(_token);

        UNISWAP_FACTORY = IUniswapV3Factory(_uniswapFactory);
        SWAP_ROUTER = IV3SwapRouter(_swapRouter);
        TOKEN = IERC20(_token);
        WETH = IWETH(_weth);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function buyPortfolio(
        uint256 _portfolioId,
        uint256 _amountToken,
        uint256 _transactionTimeout,
        uint24 _poolFee
    ) external payable {
        if (portfolioManager.getPortfolio(_portfolioId).tokens.length == 0) revert PortfolioDoesNotExist();
        if (!portfolioManager.getPortfolio(_portfolioId).enabled) revert PortfolioIsDisabled();
        if (address(portfolioManager) == address(0)) revert PortfolioManagerNotSet();
        if (msg.value > 0 && _amountToken > 0) revert MixedPaymentNotAllowed();
        if (msg.value == 0 && _amountToken == 0) revert PaymentAmountZero();

        address tokenIn = _amountToken > 0 ? address(TOKEN) : address(WETH);
        uint256 amountPayment = tokenIn == address(TOKEN) ? _amountToken : msg.value;
        uint256 transactionTimeout = _transactionTimeout != 0 ? _transactionTimeout : DEFAULT_TRANSACTION_TIMEOUT;
        uint24 poolFee = _poolFee != 0 ? _poolFee : DEFAULT_POOL_FEE;

        _buyPortfolio(tokenIn, _portfolioId, amountPayment, transactionTimeout, poolFee);
        emit PortfolioPurchased(_portfolioId, msg.sender, _amountToken, msg.value);
    }

    function sellPortfolio(
        uint256 _tokenId,
        uint256 _transactionTimeout,
        uint24 _poolFee
    ) external {
        if (!_isAuthorized(ownerOf(_tokenId), msg.sender, _tokenId)) revert NotApprovedOrOwner();

        address tokenOut = purchasedPortfolios[_tokenId].purchasedWithETH ? address(WETH) : address(TOKEN);
        uint256 transactionTimeout = _transactionTimeout != 0 ? _transactionTimeout : DEFAULT_TRANSACTION_TIMEOUT;
        uint24 poolFee = _poolFee != 0 ? _poolFee : DEFAULT_POOL_FEE;

        _sellPortfolio(tokenOut, _tokenId, transactionTimeout, poolFee);
        emit PortfolioSold(_tokenId, msg.sender);
    }

    function getExpectedMinAmountToken(
        address _baseToken,
        address _quoteToken,
        uint256 _amountIn,
        uint24 _poolFee
    ) public view returns (uint256 amountOutMinimum) {
        address pool = UNISWAP_FACTORY.getPool(
            _baseToken,
            _quoteToken,
            _poolFee
        );
        if (pool == address(0)) revert PoolDoesNotExist();

        (int24 tick, ) = OracleLibrary.consult(pool, secondsAgo);
        uint256 amountOut = OracleLibrary.getQuoteAtTick(
            tick,
            uint128(_amountIn),
            _baseToken,
            _quoteToken
        );

        amountOutMinimum = (amountOut * SLIPPAGE_MULTIPLIER) / BIPS;
    }

    function setPortfolioManager(address _portfolioManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address(portfolioManager) != address(0)) revert PortfolioManagerAlreadySet();
        portfolioManager = PortfolioManager(_portfolioManager);
        emit PortfolioManagerSet(_portfolioManager);
    }
    
    function getPurchasedPortfolio(uint256 _tokenId) public view returns (PurchasedPortfolio memory) {
        return purchasedPortfolios[_tokenId];
    }

    function getPurchasedPortfolioTokenCount(uint256 _tokenId) public view returns (uint256) {
        return purchasedPortfolios[_tokenId].purchasedTokens.length;
    }

    function updateSecondsAgo(uint32 _newSecondsAgo) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (secondsAgo == _newSecondsAgo) revert ValueUnchanged();

        secondsAgo = _newSecondsAgo;
        emit SecondsAgoUpdated(_newSecondsAgo);
    }

    function updateServiceFee(uint256 _newServiceFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (serviceFee == _newServiceFee) revert ValueUnchanged();

        serviceFee = _newServiceFee;
        emit ServiceFeeUpdated(_newServiceFee);
    }

    function withdrawTokens(address _token, address _receiver, uint256 _amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(_token).safeTransfer(_receiver, _amount);
    }

    function withdrawAllTokens() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = TOKEN.balanceOf(address(this));
        TOKEN.safeTransfer(msg.sender, balance);
    }

    function withdrawETH(address _receiver, uint256 _amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool success, ) = _receiver.call{value: _amount}(new bytes(0));
        if (!success) revert WithdrawFailed();
    }

    function withdrawAllETH() public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}(new bytes(0));
        if (!success) revert WithdrawFailed();
    }

    function _buyPortfolio(
        address _tokenIn,
        uint256 _portfolioId,
        uint256 _amountPayment,
        uint256 _transactionTimeout,
        uint24 _poolFee
    ) private {
        // Invested amount token or ETH that including service fee
        uint256 investedAmount = _amountPayment * (BIPS - serviceFee) / BIPS;
        PortfolioManager.TokenShare[] memory portfolioTokens = portfolioManager.getPortfolio(_portfolioId).tokens;
        PurchasedToken[] memory purchasedTokens = new PurchasedToken[](portfolioTokens.length);

        // When buying with a token, all tokens are transferred from user. The investedAmount is taken for the swap
        // When buying with ETH, we have to convert investedAmount to WETH. Percentage of the service fee stays in ETH
        if (_tokenIn == address(TOKEN)) {
            IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountPayment);
        } else {
            WETH.deposit{value: investedAmount}();
        }

        IERC20(_tokenIn).approve(address(SWAP_ROUTER), investedAmount);
        for (uint256 i = 0; i < portfolioTokens.length; i++) {
            PortfolioManager.TokenShare memory portfolioToken = portfolioTokens[i];

            uint256 tokenAmount = (investedAmount * portfolioToken.share) / BIPS;
            uint256 amountOutToken = _swap(_tokenIn, portfolioToken.token, tokenAmount, _poolFee);

            purchasedTokens[i] = PurchasedToken({
                token: portfolioToken.token,
                amount: amountOutToken
            });
        }

        tokenId++;
        purchasedPortfolios[tokenId].purchasedTokens = purchasedTokens;
        purchasedPortfolios[tokenId].purchasedWithETH = _tokenIn == address(WETH);
        _mint(msg.sender, tokenId);
    }

    function _sellPortfolio(
        address _tokenOut,
        uint256 _tokenId,
        uint256 _transactionTimeout,
        uint24 _fee
    ) private {
        PurchasedPortfolio memory purchasedPortfolio = purchasedPortfolios[_tokenId];

        for (uint256 i = 0; i < purchasedPortfolio.purchasedTokens.length; i++) {
            PurchasedToken memory portfolioToken = purchasedPortfolio.purchasedTokens[i];

            IERC20(portfolioToken.token).approve(address(SWAP_ROUTER), portfolioToken.amount);
            uint256 amountOut = _swap(portfolioToken.token, _tokenOut, portfolioToken.amount, _fee);
            if (purchasedPortfolio.purchasedWithETH) {
                WETH.withdraw(amountOut);
                (bool success, ) = msg.sender.call{value: amountOut}("");
                if(!success) revert ETHTransferFailed();
            } else {
                IERC20(portfolioToken.token).safeTransferFrom(address(this), msg.sender, amountOut);
            }
        }
        
        delete purchasedPortfolios[_tokenId];
        _burn(_tokenId);
    }

    function _swap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint24 _fee
    ) private returns (uint256 amountOut) {
        uint256 amountOutMinimum = getExpectedMinAmountToken(
            _tokenIn,
            _tokenOut,
            _amountIn,
            _fee
        );

        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: _fee,
                recipient: address(this),
                amountIn: _amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            });

        amountOut = SWAP_ROUTER.exactInputSingle(params);
    }

    function _checkIsContract(address _address) private view {
        if (!(_address.code.length > 0)) {
            revert NotContract(_address);
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    receive() external payable {}
}

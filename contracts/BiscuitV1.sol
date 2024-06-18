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
import "hardhat/console.sol";

error NotContract(address account);
error ValueUnchanged();
error TokenDoesNotExist(address token);
error PortfolioDoesNotExist(uint256 portfolioId);
error PoolDoesNotExist();
error IncorrectTotalShares(uint256 totalShares);
error NotApprovedOrOwner();
error MixedPaymentNotAllowed();
error PaymentAmountZero();
error WithdrawFailed();
error ETHTransferFailed();

contract BiscuitV1 is ERC721, AccessControl {
    using SafeERC20 for IERC20;

    struct TokenShare {
        address token;
        uint256 share;
    }

    struct TokenAmount {
        address token;
        uint256 amount;
    }

    struct PurchasedPortfolio {
        bool purchasedWithETH;
        TokenAmount[] portfolio;
    }

    IUniswapV3Factory public immutable UNISWAP_FACTORY;
    IV3SwapRouter public immutable SWAP_ROUTER;
    IERC20 public immutable TOKEN;
    IWETH public immutable WETH;

    uint256 public constant BIPS = 100_00;
    uint256 public constant SLIPPAGE_MULTIPLIER = BIPS - 5_00;
    uint256 public constant DEFAULT_TRANSACTION_TIMEOUT = 15 minutes;
    uint24 public constant DEFAULT_POOL_FEE = 3_000;

    uint256 serviceFee = 1_00;
    // Time interval during that price will be taken between current pair
    uint32 public secondsAgo = 2 hours;

    uint256 public portfolioId;
    uint256 public tokenId;

    // This mapping includes existing portfolios
    mapping(uint256 => TokenShare[]) public portfolios;
    mapping(uint256 => PurchasedPortfolio) public purchasedPortfolios;

    event PortfolioAdded(uint256 indexed portfolioId, TokenShare[] portfolioTokens);
    event PortfolioUpdated(uint256 indexed portfolioId, TokenShare[] portfolioTokens);
    event PortfolioRemoved(uint256 indexed portfolioId);
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
        _checkPortfolioExistence(_portfolioId);
        if (msg.value > 0 && _amountToken > 0) revert MixedPaymentNotAllowed();
        if (msg.value == 0 && _amountToken == 0) revert PaymentAmountZero();

        address tokenIn = _amountToken > 0 ? address(TOKEN) : address(WETH);
        uint256 amountPayment = _amountToken > 0 ? _amountToken : msg.value;
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
        if (!_isAuthorized(ownerOf(_tokenId), msg.sender, _tokenId)) {
            revert NotApprovedOrOwner();
        }

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

    function getTokenExists(address _token) public view returns (bool) {
        address pair = UNISWAP_FACTORY.getPool(
            _token,
            address(WETH),
            DEFAULT_POOL_FEE
        );
        return pair != address(0);
    }

    function getPortfolio(uint256 _portfolioId) public view returns (TokenShare[] memory) {
        return portfolios[_portfolioId];
    }

    function getPortfolioTokenCount(uint256 _portfolioId) public view returns (uint256) {
        return portfolios[_portfolioId].length;
    }

    
    function getPurchasedPortfolio(uint256 _tokenId) public view returns (PurchasedPortfolio memory) {
        return purchasedPortfolios[_tokenId];
    }

    function getPurchasedPortfolioTokenCount(uint256 _tokenId) public view returns (uint256) {
        return purchasedPortfolios[_tokenId].portfolio.length;
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

    function addPortfolios(TokenShare[][] memory _portfolios) public onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < _portfolios.length; i++) {
            addPortfolio(_portfolios[i]);
        }
    }

    function addPortfolio(TokenShare[] memory _portfolio) public onlyRole(DEFAULT_ADMIN_ROLE) {
        portfolioId++;
        _checkPortfolioTokens(_portfolio);
        _addPortfolio(portfolioId, _portfolio);
        emit PortfolioAdded(portfolioId, _portfolio);
    }

    function removePortfolios(uint256[] memory _portfolioIds) public onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < _portfolioIds.length; i++) {
            removePortfolio(_portfolioIds[i]);
        }
    }

    function removePortfolio(uint256 _portfolioId) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _checkPortfolioExistence(_portfolioId);
        delete portfolios[_portfolioId];
        emit PortfolioRemoved(_portfolioId);
    }

    function updatePortfolio(uint256 _portfolioId, TokenShare[] memory _newPortfolio) public onlyRole(DEFAULT_ADMIN_ROLE) {
        removePortfolio(_portfolioId);
        _addPortfolio(_portfolioId, _newPortfolio);
        emit PortfolioRemoved(_portfolioId);
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

    function _addPortfolio(uint256 _portfolioId, TokenShare[] memory _portfolio) private {
        TokenShare[] storage newPortfolio = portfolios[_portfolioId];

        for (uint256 i = 0; i < _portfolio.length; i++) {
            newPortfolio.push(_portfolio[i]);
        }
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
        TokenShare[] memory portfolio = portfolios[_portfolioId];
        TokenAmount[] memory boughtPortfolio = new TokenAmount[](portfolio.length);

        if (_tokenIn == address(TOKEN)) {
            IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountPayment);
        } else {
            WETH.deposit{value: investedAmount}();
        }

        IERC20(_tokenIn).approve(address(SWAP_ROUTER), investedAmount);
        for (uint256 i = 0; i < portfolio.length; i++) {
            TokenShare memory portfolioToken = portfolio[i];

            uint256 tokenAmount = (investedAmount * portfolioToken.share) / BIPS;
            uint256 amountOutToken = _swap(_tokenIn, portfolioToken.token, tokenAmount, _poolFee);

            boughtPortfolio[i] = TokenAmount({
                token: portfolioToken.token,
                amount: amountOutToken
            });
        }

        tokenId++;
        _mint(msg.sender, tokenId);

        PurchasedPortfolio storage purchasedPortfolio = purchasedPortfolios[tokenId];
        purchasedPortfolio.purchasedWithETH = _tokenIn == address(WETH);
        for (uint256 i = 0; i < boughtPortfolio.length; i++) {
            purchasedPortfolio.portfolio.push(boughtPortfolio[i]);
        }
    }

    function _sellPortfolio(
        address _tokenOut,
        uint256 _tokenId,
        uint256 _transactionTimeout,
        uint24 _fee
    ) private {
        PurchasedPortfolio memory purchasedPortfolio = purchasedPortfolios[_tokenId];

        for (uint256 i = 0; i < purchasedPortfolio.portfolio.length; i++) {
            TokenAmount memory portfolioToken = purchasedPortfolio.portfolio[i];

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

    function _checkPortfolioTokens(
        TokenShare[] memory _portfolio
    ) private view {
        uint256 totalShares = 0;

        for (uint256 i = 0; i < _portfolio.length; i++) {
            TokenShare memory portfolioToken = _portfolio[i];

            if (!getTokenExists(portfolioToken.token)) {
                revert TokenDoesNotExist(portfolioToken.token);
            }

            totalShares += portfolioToken.share;
        }

        if (totalShares != BIPS) {
            revert IncorrectTotalShares(totalShares);
        }
    }

    function _checkPortfolioExistence(uint256 _portfolioId) private view {
        if (portfolios[_portfolioId].length == 0) {
            revert PortfolioDoesNotExist(_portfolioId);
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    receive() external payable {}
}

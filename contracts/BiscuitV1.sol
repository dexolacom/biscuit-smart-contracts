// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import {IWETH} from "@uniswap/swap-router-contracts/contracts/interfaces/IWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SwapLibrary} from "./libraries/SwapLibrary.sol";

import {PortfolioManager} from "./PortfolioManager.sol";

error NotContract(address account);
error PortfolioDoesNotExist();
error PortfolioManagerIsZeroAddrress();
error PortfolioManagerNotSet();
error PortfolioIsDisabled();
error ValueUnchanged();
error PoolDoesNotExist();
error NotApprovedOrOwner();
error MixedPaymentNotAllowed();
error SecondsAgoTooSmall();
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
    IERC20 public immutable PURCHASE_TOKEN;
    IWETH public immutable WETH;

    PortfolioManager public portfolioManager;

    uint256 public constant MAX_BIPS = 100_00;
    uint256 public constant SLIPPAGE_MULTIPLIER = MAX_BIPS - 5_00;
    uint256 public constant DEFAULT_TRANSACTION_TIMEOUT = 15 minutes;
    uint24 public constant DEFAULT_POOL_FEE = 3_000;

    // Time interval during that price will be taken between current pair
    uint32 public secondsAgo = 2 hours;
    uint256 public serviceFee = 1_00;
    uint256 public nextTokenId;

    mapping(uint256 => PurchasedPortfolio) public purchasedPortfolios;

    event PortfolioManagerUpdated(address indexed portfolioManager);
    event PortfolioPurchased(uint256 indexed portfolioId, address indexed buyer, uint256 amountToken, uint256 amountETH);
    event PortfolioSold(uint256 indexed tokenId, address indexed seller);

    event SecondsAgoUpdated(uint32 newSecondsAgo);
    event ServiceFeeUpdated(uint256 serviceFee);

    constructor(
        address _admin,
        address _uniswapFactory,
        address _swapRouter,
        address _purchaseToken,
        address _weth
    ) ERC721("BiscuitV1", "BSC") {
        _checkIsContract(_uniswapFactory);
        _checkIsContract(_swapRouter);
        _checkIsContract(_purchaseToken);

        UNISWAP_FACTORY = IUniswapV3Factory(_uniswapFactory);
        SWAP_ROUTER = IV3SwapRouter(_swapRouter);
        PURCHASE_TOKEN = IERC20(_purchaseToken);
        WETH = IWETH(_weth);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function buyPortfolio(
        uint256 _portfolioId,
        uint256 _amountToken,
        uint256 _transactionTimeout,
        uint24 _poolFee
    ) external payable {
        if (address(portfolioManager) == address(0)) revert PortfolioManagerNotSet();
        if (portfolioManager.getPortfolio(_portfolioId).tokens.length == 0) revert PortfolioDoesNotExist();
        if (!portfolioManager.getPortfolio(_portfolioId).enabled) revert PortfolioIsDisabled();
        if (msg.value > 0 && _amountToken > 0) revert MixedPaymentNotAllowed();
        if (msg.value == 0 && _amountToken == 0) revert PaymentAmountZero();

        address tokenIn = _amountToken > 0 ? address(PURCHASE_TOKEN) : address(WETH);
        uint256 amountPayment = tokenIn == address(PURCHASE_TOKEN) ? _amountToken : msg.value;
        uint256 transactionTimeout = _transactionTimeout != 0 ? _transactionTimeout : DEFAULT_TRANSACTION_TIMEOUT;
        uint24 poolFee = _poolFee != 0 ? _poolFee : DEFAULT_POOL_FEE;

        _buyPortfolio(tokenIn, _portfolioId, amountPayment, transactionTimeout, poolFee);
    }

    function sellPortfolio(
        address _tokenOut,
        uint256 _tokenId,
        uint256 _transactionTimeout,
        uint24 _poolFee
    ) external {
        if (!_isAuthorized(ownerOf(_tokenId), msg.sender, _tokenId)) revert NotApprovedOrOwner();

        uint256 transactionTimeout = _transactionTimeout != 0 ? _transactionTimeout : DEFAULT_TRANSACTION_TIMEOUT;
        uint24 poolFee = _poolFee != 0 ? _poolFee : DEFAULT_POOL_FEE;

        _sellPortfolio(_tokenOut, _tokenId, transactionTimeout, poolFee);
    }

    function setPortfolioManager(address _portfolioManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_portfolioManager == address(0)) revert PortfolioManagerIsZeroAddrress();
        if (_portfolioManager == address(portfolioManager)) revert ValueUnchanged();

        portfolioManager = PortfolioManager(_portfolioManager);
        emit PortfolioManagerUpdated(_portfolioManager);
    }

    function updateSecondsAgo(uint32 _newSecondsAgo) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (1 minutes > _newSecondsAgo) revert SecondsAgoTooSmall();
        if (secondsAgo == _newSecondsAgo) revert ValueUnchanged();

        secondsAgo = _newSecondsAgo;
        emit SecondsAgoUpdated(_newSecondsAgo);
    }

    function updateServiceFee(uint256 _newServiceFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (serviceFee == _newServiceFee) revert ValueUnchanged();

        serviceFee = _newServiceFee;
        emit ServiceFeeUpdated(_newServiceFee);
    }

    function withdrawTokens(address _token, address _receiver, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(_token).safeTransfer(_receiver, _amount);
    }

    function withdrawAllTokens() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = PURCHASE_TOKEN.balanceOf(address(this));
        PURCHASE_TOKEN.safeTransfer(msg.sender, balance);
    }

    function withdrawETH(address _receiver, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool success, ) = _receiver.call{value: _amount}(new bytes(0));
        if (!success) revert WithdrawFailed();
    }

    function withdrawAllETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}(new bytes(0));
        if (!success) revert WithdrawFailed();
    }

    function getPurchasedPortfolio(uint256 _tokenId) public view returns (PurchasedPortfolio memory) {
        return purchasedPortfolios[_tokenId];
    }

    function getPurchasedPortfolioTokenCount(uint256 _tokenId) public view returns (uint256) {
        return purchasedPortfolios[_tokenId].purchasedTokens.length;
    }

    function _buyPortfolio(
        address _tokenIn,
        uint256 _portfolioId,
        uint256 _amountPayment,
        uint256 _transactionTimeout,
        uint24 _poolFee
    ) private {
        // In _amountPayment can be amoumt ether or token
        // Invested amount token or ETH that including service fee
        uint256 investedAmount = _amountPayment * (MAX_BIPS - serviceFee) / MAX_BIPS;
        PortfolioManager.TokenShare[] memory portfolioTokens = portfolioManager.getPortfolio(_portfolioId).tokens;
        PurchasedToken[] memory purchasedTokens = new PurchasedToken[](portfolioTokens.length);

        // When buying with ETH, we have to convert investedAmount to WETH. Percentage of the service fee stays in ETH
        // When buying with a token, all tokens are transferred from user. The investedAmount is taken for the swap
        if (_tokenIn == address(WETH)) {
            WETH.deposit{value: investedAmount}();
        } else {
            IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountPayment);
        }

        IERC20(_tokenIn).approve(address(SWAP_ROUTER), investedAmount);
        for (uint256 i = 0; i < portfolioTokens.length; i++) {
            PortfolioManager.TokenShare memory portfolioToken = portfolioTokens[i];

            uint256 tokenAmount = (investedAmount * portfolioToken.share) / MAX_BIPS;
            uint256 amountOutToken = SwapLibrary.swap(BiscuitV1(this), _tokenIn, portfolioToken.token, tokenAmount, _poolFee);

            purchasedTokens[i] = PurchasedToken({
                token: portfolioToken.token,
                amount: amountOutToken
            });
        }

        nextTokenId++;
        _addPurchasedPortfolio(nextTokenId, _tokenIn, purchasedTokens);
        _mint(msg.sender, nextTokenId);
        emit PortfolioPurchased(_portfolioId, msg.sender, _amountPayment, msg.value);
    }

    function _sellPortfolio(
        address _tokenOut,
        uint256 _tokenId,
        uint256 _transactionTimeout,
        uint24 _fee
    ) private {
        PurchasedPortfolio memory purchasedPortfolio = purchasedPortfolios[_tokenId];

        uint256 totalAmountOut;
        for (uint256 i = 0; i < purchasedPortfolio.purchasedTokens.length; i++) {
            PurchasedToken memory purchasedToken = purchasedPortfolio.purchasedTokens[i];

            IERC20(purchasedToken.token).approve(address(SWAP_ROUTER), purchasedToken.amount);
            uint256 amountOut = SwapLibrary.swap(BiscuitV1(this), purchasedToken.token, _tokenOut, purchasedToken.amount, _fee);

            totalAmountOut += amountOut;
        }

        // If portolio was purchased with ETH, we have to convert totalAmountOut to ETH and send user
        // If portolio was purchased with token, we have to  just send totalAmountOut to the user
        if (purchasedPortfolio.purchasedWithETH) {
            WETH.withdraw(totalAmountOut);
            (bool success, ) = msg.sender.call{value: totalAmountOut}("");
            if (!success) revert ETHTransferFailed();
        } else {
            IERC20(_tokenOut).safeTransfer(msg.sender, totalAmountOut);
        }
        
        delete purchasedPortfolios[_tokenId];
        _burn(_tokenId);
        emit PortfolioSold(_tokenId, msg.sender);
    }


    function _addPurchasedPortfolio(uint256 _tokenId, address _tokenIn, PurchasedToken[] memory _purchasedTokens) private {
        purchasedPortfolios[_tokenId].purchasedWithETH = _tokenIn == address(WETH);
        for (uint256 i = 0; i < _purchasedTokens.length; i++) {
            purchasedPortfolios[_tokenId].purchasedTokens.push(_purchasedTokens[i]);
        }
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

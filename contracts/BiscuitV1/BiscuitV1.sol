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


/// @dev Thrown when the provided address is not a contract.
/// @param account The address that is not a contract.
error NotContract(address account);
/// @dev Thrown when the specified portfolio does not exist.
error PortfolioDoesNotExist();
/// @dev Thrown when the portfolio manager address is zero.
error PortfolioManagerIsZeroAddrress();
/// @dev Thrown when the portfolio manager is already set to the provided address.
error PortfolioManagerNotSet();
/// @dev Thrown when the specified portfolio is disabled.
error PortfolioIsDisabled();
/// @dev Thrown when there is no change in value.
error ValueUnchanged();
/// @dev Thrown when the Uniswap pool does not exist.
error PoolDoesNotExist();
/// @dev Thrown when the caller is not the approved or owner.
error NotApprovedOrOwner();
/// @dev Thrown when mixed payment (ETH and token) is not allowed.
error MixedPaymentNotAllowed();
/// @dev Thrown when the specified time interval is too small.
error SecondsAgoTooSmall();
/// @dev Thrown when the payment amount is zero.
error PaymentAmountZero();
/// @dev Thrown when token withdrawal fails.
error WithdrawFailed();
/// @dev Thrown when ETH transfer fails.
error ETHTransferFailed();

/// @title BiscuitV1
/// @notice This contract allows users to buy and sell portfolios of tokens via Uniswap V3.
/// @dev Inherits ERC721 for NFT representation of portfolios and AccessControl for role-based access control.
contract BiscuitV1 is ERC721, AccessControl {
    using SafeERC20 for IERC20;

    /// @dev Structure to store purchased token details.
    /// @param token Address of the purchased token.
    /// @param amount Amount of the purchased token.
    struct PurchasedToken {
        address token;
        uint256 amount;
    }

    /// @dev Structure to store purchased portfolio details.
    /// @param purchasedWithETH Indicates if the portfolio was purchased with ETH.
    /// @param purchasedTokens Array of purchased tokens.
    struct PurchasedPortfolio {
        bool purchasedWithETH;
        PurchasedToken[] purchasedTokens;
    }

    /// @notice Address of the Uniswap V3 Factory.
    IUniswapV3Factory public immutable UNISWAP_FACTORY;
    /// @notice Address of the Uniswap V3 Swap Router that can be swap token.
    IV3SwapRouter public immutable SWAP_ROUTER;
    /// @notice Address of the token used for purchasing portfolios.
    IERC20 public immutable PURCHASE_TOKEN;
    /// @notice Address of (WETH) token used for purchasing portfolios for ETH.
    IWETH public immutable WETH;

    /// @notice Contract that can manages portfolios available for purchase.
    PortfolioManager public portfolioManager;

    /// @notice Maximum basis points (100%).
    uint256 public constant MAX_BIPS = 100_00;
    /// @notice Multiplier for slippage calculation (95%).
    uint256 public constant SLIPPAGE_MULTIPLIER = MAX_BIPS - 5_00;
    /// @notice Default timeout for one swap in transactions (15 minutes).
    uint256 public constant DEFAULT_TRANSACTION_TIMEOUT = 15 minutes;
    /// @notice Default pool fee for Uniswap transactions (0.3%).
    uint24 public constant DEFAULT_POOL_FEE = 3_000;

    /// @notice Time interval in seconds to consider for price calculations (2 hours).
    uint32 public secondsAgo = 2 hours;
    /// @notice Service fee in basis points (1%).
    uint256 public serviceFee = 1_00;
    /// @notice ID for the next portfolio token to be minted.
    uint256 public nextTokenId;

    /// @notice Mapping from token ID to purchased portfolio details.
    mapping(uint256 => PurchasedPortfolio) public purchasedPortfolios;

    /// @dev Event emitted when the portfolio manager is updated.
    /// @param portfolioManager Address of the new portfolio manager.
    event PortfolioManagerUpdated(address indexed portfolioManager);
    /// @dev Event emitted when a portfolio is purchased.
    /// @param portfolioId ID of the purchased portfolio.
    /// @param buyer Address of the buyer.
    /// @param amountToken Amount of tokens spent.
    /// @param amountETH Amount of ETH spent.
    event PortfolioPurchased(uint256 indexed portfolioId, address indexed buyer, uint256 amountToken, uint256 amountETH);
    /// @dev Event emitted when a portfolio is sold.
    /// @param tokenId ID of the sold portfolio token.
    /// @param seller Address of the seller.
    event PortfolioSold(uint256 indexed tokenId, address indexed seller);

    /// @dev Event emitted when the secondsAgo parameter is updated.
    /// @param newSecondsAgo New value for secondsAgo.
    event SecondsAgoUpdated(uint32 newSecondsAgo);
    /// @dev Event emitted when the service fee is updated.
    /// @param serviceFee New value for the service fee.
    event ServiceFeeUpdated(uint256 serviceFee);

    /// @dev Constructor for the BiscuitV1 contract.
    /// @param _admin Address of the contract admin.
    /// @param _uniswapFactory Address of the Uniswap V3 Factory.
    /// @param _swapRouter Address of the Uniswap V3 Swap Router.
    /// @param _purchaseToken Address of the token used for purchasing portfolios.
    /// @param _weth Address of the (WETH) token used for purchasing portfolios.
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
        _checkIsContract(_weth);

        UNISWAP_FACTORY = IUniswapV3Factory(_uniswapFactory);
        SWAP_ROUTER = IV3SwapRouter(_swapRouter);
        PURCHASE_TOKEN = IERC20(_purchaseToken);
        WETH = IWETH(_weth);

        address pool = UNISWAP_FACTORY.getPool(_purchaseToken, _weth, DEFAULT_POOL_FEE);
        if (pool == address(0)) revert PoolDoesNotExist();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /// @notice Buy a portfolio using purchase token. Minting NFT to caller that identifies portfolio ownership.
    /// @notice Charges a service fee from the total amount token.
    /// @param _portfolioId The ID of the portfolio to purchase.
    /// @param _amountToken The amount of tokens to spend on the portfolio.
    /// @param _transactionTimeout The transaction timeout for each swap in seconds.
    /// @param _poolFee The pool fee for the Uniswap transaction.
    /// @dev Reverts if the token amount is zero, portfolio with this ID doesn't exist or disabled.
    /// @dev If `_poolFee` is 0, a default fee of 0.3% will be used
    ///     If `_transactionTimeout` is 0, a default transactionTimeout of 15 minutes will be used.
    function buyPortfolioERC20(
        uint256 _portfolioId,
        uint256 _amountToken,
        uint256 _transactionTimeout,
        uint24 _poolFee
    ) external {
        _buyPortfolio(address(PURCHASE_TOKEN), _portfolioId, _amountToken, _transactionTimeout, _poolFee);
    }

    /// @notice Buy a portfolio using ETH. Minting NFT to caller that identifies portfolio ownership.
    /// @notice Charges a service fee from the total amount ETH.
    /// @param _portfolioId The ID of the portfolio to purchase.
    /// @param _transactionTimeout The transaction timeout for each swap in seconds.
    /// @param _poolFee The pool fee for the Uniswap transaction.
    /// @dev Convert ETH to WETH before swap.
    /// @dev Reverts if the amount ETH is zero, portfolio with this ID doesn't exist or disabled.
    /// @dev If `_poolFee` is 0, a default fee of 0.3% will be used
    ///     If `_transactionTimeout` is 0, a default transactionTimeout of 15 minutes will be used.
    function buyPortfolioETH(
        uint256 _portfolioId,
        uint256 _transactionTimeout,
        uint24 _poolFee
    ) external payable {
        _buyPortfolio(address(WETH), _portfolioId, msg.value, _transactionTimeout, _poolFee);
    }

    /// @notice Sell a purchased portfolio. Burning NFT with this `_tokenId` that identifies portfolio ownership.
    /// @notice Sends the amount `_tokenOut` from sale of portfolio to the caller.
    /// @param _tokenOut The token to receive in exchange for the portfolio.
    /// @param _tokenId The ID of the portfolio token to sell.
    /// @param _transactionTimeout The transaction timeout in seconds.
    /// @param _poolFee The pool fee for the Uniswap transaction.
    /// @dev If `_tokenOut` is WETH, WETH will be converted to ETH before sending to user.
    /// @dev Reverts with `NotApprovedOrOwner` if the caller is not the approved or owner this NFT.
    /// @dev Reverts with `ETHTransferFailed` if the ETH transfer to user fails.
    /// @dev If `_poolFee` is 0, a default fee of 0.3% will be used
    ///     If `_transactionTimeout` is 0, a default transactionTimeout of 15 minutes will be used.
    function sellPortfolio(
        address _tokenOut,
        uint256 _tokenId,
        uint256 _transactionTimeout,
        uint24 _poolFee
    ) external {
        if (!_isAuthorized(ownerOf(_tokenId), msg.sender, _tokenId)) revert NotApprovedOrOwner();

        PurchasedPortfolio memory purchasedPortfolio = purchasedPortfolios[_tokenId];

        uint256 transactionTimeout = _transactionTimeout != 0 ? _transactionTimeout : DEFAULT_TRANSACTION_TIMEOUT;
        uint24 poolFee = _poolFee != 0 ? _poolFee : DEFAULT_POOL_FEE;

        uint256 totalAmountOut;
        for (uint256 i = 0; i < purchasedPortfolio.purchasedTokens.length; i++) {
            PurchasedToken memory purchasedToken = purchasedPortfolio.purchasedTokens[i];

            IERC20(purchasedToken.token).approve(address(SWAP_ROUTER), purchasedToken.amount);
            uint256 amountOut = SwapLibrary.swap(BiscuitV1(this), purchasedToken.token, _tokenOut, purchasedToken.amount, transactionTimeout, poolFee);

            totalAmountOut += amountOut;
        }

        // If user want to sell portolio for ETH, we have to convert totalAmountOut to ETH and send user
        // If user want to sell portolio for token, we have to just send totalAmountOut to the user
        if (_tokenOut == address(WETH)) {
            WETH.withdraw(totalAmountOut);
            (bool success, ) = msg.sender.call{value: totalAmountOut}("");
            if (!success) revert ETHTransferFailed();
        } else {
            IERC20(_tokenOut).safeTransfer(msg.sender, totalAmountOut);
        }

        _burn(_tokenId);
        delete purchasedPortfolios[_tokenId];
        emit PortfolioSold(_tokenId, msg.sender);
    }

    /// @notice Set the address of the portfolio manager.
    /// @param _portfolioManager The new portfolio manager address.
    /// @dev Reverts with `PortfolioManagerIsZeroAddrress` if the provided address is zero.
    /// @dev Reverts with `ValueUnchanged` if the new address is the same as the current one.
    function setPortfolioManager(address _portfolioManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_portfolioManager == address(0)) revert PortfolioManagerIsZeroAddrress();
        if (_portfolioManager == address(portfolioManager)) revert ValueUnchanged();

        portfolioManager = PortfolioManager(_portfolioManager);
        emit PortfolioManagerUpdated(_portfolioManager);
    }

    /// @notice Update the secondsAgo parameter.
    /// @param _newSecondsAgo The new secondsAgo value.
    /// @dev Reverts with `SecondsAgoTooSmall` if the new value is less than 1 minute.
    /// @dev Reverts with `ValueUnchanged` if the new value is the same as the current one.
    function updateSecondsAgo(uint32 _newSecondsAgo) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (1 minutes > _newSecondsAgo) revert SecondsAgoTooSmall();
        if (secondsAgo == _newSecondsAgo) revert ValueUnchanged();

        secondsAgo = _newSecondsAgo;
        emit SecondsAgoUpdated(_newSecondsAgo);
    }

    /// @notice Update the service fee.
    /// @param _newServiceFee The new service fee value.
    /// @dev Reverts with `ValueUnchanged` if the new value is the same as the current one.
    function updateServiceFee(uint256 _newServiceFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (serviceFee == _newServiceFee) revert ValueUnchanged();

        serviceFee = _newServiceFee;
        emit ServiceFeeUpdated(_newServiceFee);
    }

    /// @notice Withdraw specified amount of tokens to a receiver address.
    /// @param _token The token address to withdraw.
    /// @param _receiver The receiver address.
    /// @param _amount The amount to withdraw.
    function withdrawTokens(address _token, address _receiver, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(_token).safeTransfer(_receiver, _amount);
    }

    /// @notice Withdraw all tokens to the admin address.
    function withdrawAllTokens() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = PURCHASE_TOKEN.balanceOf(address(this));
        PURCHASE_TOKEN.safeTransfer(msg.sender, balance);
    }

    /// @notice Withdraw specified amount of ETH to a receiver address.
    /// @param _receiver The receiver address.
    /// @param _amount The amount to withdraw.
    function withdrawETH(address _receiver, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool success, ) = _receiver.call{value: _amount}(new bytes(0));
        if (!success) revert WithdrawFailed();
    }

    /// @notice Withdraw all ETH to the admin address.
    function withdrawAllETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}(new bytes(0));
        if (!success) revert WithdrawFailed();
    }

    /// @notice Get the purchased portfolio details for a given token ID.
    /// @param _tokenId The ID of the portfolio token.
    /// @return The purchased portfolio details.
    function getPurchasedPortfolio(uint256 _tokenId) public view returns (PurchasedPortfolio memory) {
        return purchasedPortfolios[_tokenId];
    }

    /// @notice Get the number of tokens in a purchased portfolio.
    /// @param _tokenId The ID of the portfolio token.
    /// @return The number of tokens in the purchased portfolio.
    function getPurchasedPortfolioTokenCount(uint256 _tokenId) public view returns (uint256) {
        return purchasedPortfolios[_tokenId].purchasedTokens.length;
    }

    /// @dev Internal function to purchase a portfolio and mints NFT to `msg.sender`.
    /// @param _tokenIn The address of the token to pay with.
    /// @param _portfolioId The ID of the portfolio to purchase.
    /// @param _amountPayment The amount of tokens/ETH to spend on the portfolio.
    /// @param _transactionTimeout The transaction timeout in seconds.
    /// @param _poolFee The pool fee for the Uniswap transaction.
    /// @dev Reverts with `PaymentAmountZero` if the payment amount is zero.
    /// @dev Reverts with `PortfolioDoesNotExist` if the portfolio does not exist.
    /// @dev Reverts with `PortfolioIsDisabled` if the portfolio is disabled.
    function _buyPortfolio(
        address _tokenIn,
        uint256 _portfolioId,
        uint256 _amountPayment,
        uint256 _transactionTimeout,
        uint24 _poolFee
    ) private {
        PortfolioManager.Portfolio memory portfolio = portfolioManager.getPortfolio(_portfolioId);

        if (_amountPayment == 0) revert PaymentAmountZero();
        if (portfolio.tokens.length == 0) revert PortfolioDoesNotExist();
        if (!portfolio.enabled) revert PortfolioIsDisabled();

        // Invested amount token or ETH that including service fee
        uint256 investedAmount = _amountPayment * (MAX_BIPS - serviceFee) / MAX_BIPS;

        // When buying with ETH, we have to convert investedAmount to WETH. Percentage of the service fee stays in ETH
        // When buying with a token, all tokens are transferred from user. The investedAmount is taken for the swap
        if (_tokenIn == address(WETH)) {
            WETH.deposit{value: investedAmount}();
        } else {
            IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountPayment);
        }

        nextTokenId++;
        _mint(msg.sender, nextTokenId);
        _purchasePortfolioTokens(_tokenIn, investedAmount, _transactionTimeout, _poolFee, portfolio);
        emit PortfolioPurchased(_portfolioId, msg.sender, _amountPayment, msg.value);
    }

    /// @dev Internal function to purchase tokens in a portfolio.
    /// @param _tokenIn The address of the token to pay with.
    /// @param _investedAmount The amount of tokens/ETH to invest.
    /// @param _transactionTimeout The transaction timeout in seconds.
    /// @param _poolFee The pool fee for the Uniswap transaction.
    /// @param portfolio The portfolio details.
    function _purchasePortfolioTokens(
        address _tokenIn,
        uint256 _investedAmount,
        uint256 _transactionTimeout,
        uint24 _poolFee,
        PortfolioManager.Portfolio memory portfolio
    ) private {
        uint256 transactionTimeout = _transactionTimeout != 0 ? _transactionTimeout : DEFAULT_TRANSACTION_TIMEOUT;
        uint24 poolFee = _poolFee != 0 ? _poolFee : DEFAULT_POOL_FEE;

        PortfolioManager.TokenShare[] memory portfolioTokens = portfolio.tokens;
        PurchasedToken[] memory purchasedTokens = new PurchasedToken[](portfolioTokens.length);

        IERC20(_tokenIn).approve(address(SWAP_ROUTER), _investedAmount);
        for (uint256 i = 0; i < portfolioTokens.length; i++) {
            PortfolioManager.TokenShare memory portfolioToken = portfolioTokens[i];

            uint256 tokenAmount = (_investedAmount * portfolioToken.share) / MAX_BIPS;
            uint256 amountOutToken = SwapLibrary.swap(BiscuitV1(this), _tokenIn, portfolioToken.token, tokenAmount, transactionTimeout, poolFee);

            purchasedTokens[i] = PurchasedToken({
                token: portfolioToken.token,
                amount: amountOutToken
            });
            purchasedPortfolios[nextTokenId].purchasedTokens.push(purchasedTokens[i]);
        }
        purchasedPortfolios[nextTokenId].purchasedWithETH = _tokenIn == address(WETH);
    }

    /// @dev Internal function to check if an address is a contract.
    /// @param _address The address to check.
    function _checkIsContract(address _address) private view {
        if (!(_address.code.length > 0)) {
            revert NotContract(_address);
        }
    }

    /// @notice Check if the contract supports a given interface.
    /// @param interfaceId The interface identifier.
    /// @return True if the contract supports the interface, false otherwise.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Receive function to accept ETH deposits.
    receive() external payable {}
}

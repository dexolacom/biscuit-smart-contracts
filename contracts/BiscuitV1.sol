// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {OracleLibrary} from "./libraries/OracleLibrary.sol";

error NotContract(address account);
error ValueUnchanged();
error TokenDoesNotExist(address token);
error PortfolioDoesNotExist(uint256 portfolioId);
error PoolDoesNotExist();
error IncorrectTotalShares(uint256 totalShares);
error NotApprovedOrOwner();
error AmountZero();

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

    IUniswapV3Factory public immutable UNISWAP_FACTORY;
    IV3SwapRouter public immutable SWAP_ROUTER;
    IERC20 public immutable TOKEN;

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
    // This mapping contains purchased portfolios
    mapping(uint256 => TokenAmount[]) public purchasedPortfolios;

    event PortfolioAdded(uint256 indexed portfolioId, TokenShare[] portfolioTokens);
    event PortfolioUpdated(uint256 indexed portfolioId, TokenShare[] portfolioTokens);
    event PortfolioRemoved(uint256 indexed portfolioId);
    event PortfolioPurchased(uint256 indexed portfolioId, address indexed buyer, uint256 amount);
    event PortfolioSold(uint256 indexed tokenId, address indexed seller);

    event SecondsAgoUpdated(uint32 newSecondsAgo);
    event ServiceFeeUpdated(uint256 serviceFee);

    constructor(
        address _admin,
        address _uniswapFactory,
        address _swapRouter,
        address _token
    ) ERC721("BiscuitV1", "BSC") {
        _checkIsContract(_uniswapFactory);
        _checkIsContract(_swapRouter);
        _checkIsContract(_token);

        UNISWAP_FACTORY = IUniswapV3Factory(_uniswapFactory);
        SWAP_ROUTER = IV3SwapRouter(_swapRouter);
        TOKEN = IERC20(_token);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function buyPortfolio(
        uint256 _portfolioId,
        uint256 _amount,
        uint256 _transactionTimeout,
        uint24 _poolFee
    ) public {
        _checkPortfolioExistence(_portfolioId);
        if (_amount == 0) revert AmountZero();

        uint256 transactionTimeout = _transactionTimeout != 0 ? _transactionTimeout : DEFAULT_TRANSACTION_TIMEOUT;
        uint24 poolFee = _poolFee != 0 ? _poolFee : DEFAULT_POOL_FEE;

        _buyPortfolio(_portfolioId, _amount, transactionTimeout, poolFee);
        emit PortfolioPurchased(_portfolioId, msg.sender, _amount);
    }

    function sellPortfolio(
        uint256 _tokenId,
        uint256 _transactionTimeout,
        uint24 _poolFee
    ) public {
        if (!_isAuthorized(ownerOf(_tokenId), msg.sender, _tokenId)) {
            revert NotApprovedOrOwner();
        }

        uint256 transactionTimeout = _transactionTimeout != 0 ? _transactionTimeout : DEFAULT_TRANSACTION_TIMEOUT;
        uint24 poolFee = _poolFee != 0 ? _poolFee : DEFAULT_POOL_FEE;

        _sellPortfolio(_tokenId, transactionTimeout, poolFee);
        emit PortfolioSold(_tokenId, msg.sender);
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

    function updateSecondsAgo(uint32 _newSecondsAgo) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (secondsAgo == _newSecondsAgo) revert ValueUnchanged();

        secondsAgo = _newSecondsAgo;
        emit SecondsAgoUpdated(_newSecondsAgo);
    }

    function updateServiceFee(uint32 _newServiceFee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (serviceFee == _newServiceFee) revert ValueUnchanged();

        serviceFee = _newServiceFee;
        emit ServiceFeeUpdated(_newServiceFee);
    }

    function withdrawTokens(address _token, address _receiver, uint256 _amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(_token).safeTransfer(_receiver, _amount);
    }

    function withdrawAllTokens() public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = TOKEN.balanceOf(address(this));
        TOKEN.safeTransfer(msg.sender, balance);
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
            address(TOKEN),
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

    
    function getPurchasedPortfolio(uint256 _tokenId) public view returns (TokenAmount[] memory) {
        return purchasedPortfolios[_tokenId];
    }

    function getPurchasedPortfolioTokenCount(uint256 _tokenId) public view returns (uint256) {
        return purchasedPortfolios[_tokenId].length;
    }


    function _addPortfolio(uint256 _portfolioId, TokenShare[] memory _portfolio) private {
        TokenShare[] storage newPortfolio = portfolios[_portfolioId];

        for (uint256 i = 0; i < _portfolio.length; i++) {
            newPortfolio.push(_portfolio[i]);
        }
    }

    function _buyPortfolio(
        uint256 _portfolioId,
        uint256 _amount,
        uint256 _transactionTimeout,
        uint24 _poolFee
    ) private {
        TOKEN.safeTransferFrom(msg.sender, address(this), _amount);
        TOKEN.approve(address(SWAP_ROUTER), _amount);

        TokenShare[] memory portfolio = portfolios[_portfolioId];
        TokenAmount[] memory purchasedPortfolio = new TokenAmount[](portfolio.length);

        // Invested amount token that including service fee
        uint256 investedAmount = _amount * BIPS - serviceFee / BIPS;

        for (uint256 i = 0; i < portfolio.length; i++) {
            TokenShare memory portfolioToken = portfolio[i];
            uint256 tokenAmount = (investedAmount * portfolioToken.share) / BIPS;
            uint256 amountOutMinimum = getExpectedMinAmountToken(
                address(TOKEN),
                portfolioToken.token,
                tokenAmount,
                _poolFee
            );

            IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
                .ExactInputSingleParams({
                    tokenIn: address(TOKEN),
                    tokenOut: portfolioToken.token,
                    fee: _poolFee,
                    recipient: address(this),
                    amountIn: tokenAmount,
                    amountOutMinimum: amountOutMinimum,
                    sqrtPriceLimitX96: 0
                });

            uint256 amountOut = SWAP_ROUTER.exactInputSingle(params);

            purchasedPortfolio[i] = TokenAmount({
                token: portfolioToken.token,
                amount: amountOut
            });
        }

        TokenAmount[] storage newPortfolio = purchasedPortfolios[tokenId];
        for (uint256 i = 0; i < purchasedPortfolio.length; i++) {
            newPortfolio.push(purchasedPortfolio[i]);
        }

        tokenId++;
        purchasedPortfolios[tokenId] = newPortfolio;
        _mint(msg.sender, tokenId);
    }

    function _sellPortfolio(
        uint256 _tokenId,
        uint256 _transactionTimeout,
        uint24 _fee
    ) private {
        TokenAmount[] memory purchasedPortfolio = purchasedPortfolios[_tokenId];

        for (uint256 i = 0; i < purchasedPortfolio.length; i++) {
            TokenAmount memory portfolioToken = purchasedPortfolio[i];

            uint256 amountOutMinimum = getExpectedMinAmountToken(
                portfolioToken.token,
                address(TOKEN),
                portfolioToken.amount,
                _fee
            );

            IERC20(portfolioToken.token).approve(address(SWAP_ROUTER), portfolioToken.amount);
            IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
                .ExactInputSingleParams({
                    tokenIn: portfolioToken.token,
                    tokenOut: address(TOKEN),
                    fee: _fee,
                    recipient: msg.sender,
                    amountIn: portfolioToken.amount,
                    amountOutMinimum: amountOutMinimum,
                    sqrtPriceLimitX96: 0
                });

            SWAP_ROUTER.exactInputSingle(params);
        }
        
        delete purchasedPortfolios[_tokenId];
        _burn(_tokenId);
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
}

// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.24;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";


error NotContract(address account);
error TokenDoesNotExist(address token);
error PortfolioDoesNotExist(uint256 portfolioId);
error IncorrectTotalShares(uint256 totalShares);
error AmountZero();

contract PortfolioMarket is AccessControl {
    using SafeERC20 for IERC20;

    IUniswapV3Factory public immutable UNISWAP_FACTORY; 
    IV3SwapRouter public immutable SWAP_ROUTER;
    IERC20 public immutable TOKEN;

    uint256 public constant DEFAULT_TRANSACTION_TIMEOUT = 1000;
    uint24 public constant DEFAULT_FEE = 3_000;
    uint256 public constant BIPS = 100_00;

    struct PortfolioToken {
        address token;
        uint256 share;
    }

    mapping(uint256 => PortfolioToken[]) public portfolios;
    uint256 public portfolioId;

    event PortfolioAdded(uint256 indexed portfolioId, PortfolioToken[] portfolioTokens);
    event PortfolioRemoved(uint256 indexed portfolioId);
    event PortfolioBought(uint256 indexed portfolioId, address indexed buyer, uint256 amount);

    constructor(address _admin, address _uniswapFactory, address _swapRouter, address _token)  {
        _checkIsContract(_uniswapFactory);
        _checkIsContract(_swapRouter);
        _checkIsContract(_token);

        UNISWAP_FACTORY = IUniswapV3Factory(_uniswapFactory);
        SWAP_ROUTER = IV3SwapRouter(_swapRouter);
        TOKEN = IERC20(_token);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function addPortfolios(PortfolioToken[][] memory _portfolios) public onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < _portfolios.length; i++) {
            addPortfolio(_portfolios[i]);
        }
    }

    function addPortfolio(PortfolioToken[] memory _portfolio) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 totalShares;
        for (uint256 i = 0; i < _portfolio.length; i++) {
            PortfolioToken memory portfolioToken = _portfolio[i];

            if (!tokenExists(portfolioToken.token)) {
                revert TokenDoesNotExist(portfolioToken.token);
            }

            totalShares += portfolioToken.share;
        }
        if (totalShares != BIPS) {
            revert IncorrectTotalShares(totalShares);
        } 

        _addPortfolio(_portfolio);
        emit PortfolioAdded(portfolioId, _portfolio);
    }

    function removePortfolios(uint256[] memory _portfolioIds) public onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < _portfolioIds.length; i++) {
            removePortfolio(_portfolioIds[i]);
        }
    }

    function removePortfolio(uint256 _portfolioId) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!portfolioExists(_portfolioId)) revert PortfolioDoesNotExist(_portfolioId);

        delete portfolios[_portfolioId];
        emit PortfolioRemoved(_portfolioId);
    }

    function buyPortfolio(uint256 _portfolioId, uint256 _amount, uint256 _transactionTimeout, uint24 _fee) public {
        if (!portfolioExists(_portfolioId)) revert PortfolioDoesNotExist(_portfolioId); 
        if (_amount == 0 ) revert AmountZero();

        uint256 transactionTimeout = _transactionTimeout != 0 ? _transactionTimeout : DEFAULT_TRANSACTION_TIMEOUT;
        uint24 fee = _fee != 0 ? _fee : DEFAULT_FEE;

        _buyPortfolio(_portfolioId, _amount, transactionTimeout, fee);
        emit PortfolioBought(_portfolioId, msg.sender, _amount);
    }

    function tokenExists(address _token) public view returns (bool) {
        address pair = UNISWAP_FACTORY.getPool(_token, address(TOKEN), DEFAULT_FEE); // need to fix later (DEFAULT_FEE)
        return pair != address(0);
    }

    function portfolioExists(uint256 _portfolioId) public view returns (bool) {
        return portfolios[_portfolioId].length > 0;
    }

    function _addPortfolio(PortfolioToken[] memory _portfolio) private {
        portfolioId++;
        PortfolioToken[] storage newPortfolio = portfolios[portfolioId];

        for (uint256 i = 0; i < _portfolio.length; i++) {
            newPortfolio.push(_portfolio[i]);
        }
    }

    function _buyPortfolio(uint256 _portfolioId, uint256 _amount, uint256 _transactionTimeout, uint24 _fee) private {
        TOKEN.safeTransferFrom(msg.sender, address(this), _amount);
        PortfolioToken[] memory portfolio = portfolios[_portfolioId];
        for (uint256 i = 0; i < portfolio.length; i++) {
            PortfolioToken memory tokenShare = portfolio[i];
            uint256 tokenAmount = (_amount * tokenShare.share) / BIPS;

            IV3SwapRouter.ExactInputSingleParams memory params =
                IV3SwapRouter.ExactInputSingleParams({
                    tokenIn: address(TOKEN),
                    tokenOut: tokenShare.token,
                    fee: _fee,
                    recipient: address(this),
                    amountIn: tokenAmount,
                    amountOutMinimum: 0, // need to fix later
                    sqrtPriceLimitX96: 0
                });

            SWAP_ROUTER.exactInputSingle(params);
        }
    }

    function _checkIsContract(address _address) private view {
        if (!(_address.code.length > 0)) {
            revert NotContract(_address);
        }
    }
}
// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.24;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {OracleLibrary} from "./libraries/OracleLibrary.sol";


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

    uint256 public constant BIPS = 100_00;
    uint256 public constant SLIPPAGE_MULTIPLIER = BIPS - 5_00;
    uint256 public constant DEFAULT_TRANSACTION_TIMEOUT = 1000;
    uint24 public constant DEFAULT_FEE = 3_000;

    uint32 public secondsAgo = 7200;
    uint256 public portfolioId;

    struct PortfolioToken {
        address token;
        uint256 share;
    }

    mapping(uint256 => PortfolioToken[]) public portfolios;

    event PortfolioAdded(uint256 indexed portfolioId, PortfolioToken[] portfolioTokens);
    event PortfolioRemoved(uint256 indexed portfolioId);
    event PortfolioBought(uint256 indexed portfolioId, address indexed buyer, uint256 amount);

    event SecondsAgoUpdated(uint32 newSecondsAgo);

    constructor(address _admin, address _uniswapFactory, address _swapRouter, address _token)  {
        _checkIsContract(_uniswapFactory);
        _checkIsContract(_swapRouter);
        _checkIsContract(_token);

        UNISWAP_FACTORY = IUniswapV3Factory(_uniswapFactory);
        SWAP_ROUTER = IV3SwapRouter(_swapRouter);
        TOKEN = IERC20(_token);

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function updateSecondsAgo(uint32 _newSecondsAgo) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if(secondsAgo == _newSecondsAgo) revert("New value must be different from the current value");
        secondsAgo = _newSecondsAgo;
        emit SecondsAgoUpdated(_newSecondsAgo);
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
        _checkPortfolioExistence(_portfolioId);

        delete portfolios[_portfolioId];
        emit PortfolioRemoved(_portfolioId);
    }

    function buyPortfolio(uint256 _portfolioId, uint256 _amount, uint256 _transactionTimeout, uint24 _fee) public {
        _checkPortfolioExistence(_portfolioId);
        if (_amount == 0 ) revert AmountZero();

        uint256 transactionTimeout = _transactionTimeout != 0 ? _transactionTimeout : DEFAULT_TRANSACTION_TIMEOUT;
        uint24 fee = _fee != 0 ? _fee : DEFAULT_FEE;

        _buyPortfolio(_portfolioId, _amount, transactionTimeout, fee);
        emit PortfolioBought(_portfolioId, msg.sender, _amount);
    }

    function getExpectedMinAmountToken(
        address _token,
        uint256 _amountIn,
        uint24 _fee
    ) public view returns (uint256 amountOutMinimum) {
        uint24 fee = _fee != 0 ? _fee : DEFAULT_FEE;

        address pool = UNISWAP_FACTORY.getPool(address(TOKEN), _token, fee);
        if (pool == address(0)) revert();

        (int24 tick, ) = OracleLibrary.consult(pool, secondsAgo);
        uint256 amountOut = OracleLibrary.getQuoteAtTick(tick, uint128(_amountIn), address(TOKEN), _token);

        amountOutMinimum = amountOut * SLIPPAGE_MULTIPLIER / BIPS;
    }

    function tokenExists(address _token) public view returns (bool) {
        address pair = UNISWAP_FACTORY.getPool(_token, address(TOKEN), DEFAULT_FEE); // need to fix later (DEFAULT_FEE)
        return pair != address(0);
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
        TOKEN.approve(address(SWAP_ROUTER), _amount);

        PortfolioToken[] memory portfolio = portfolios[_portfolioId];
        for (uint256 i = 0; i < portfolio.length; i++) {
            PortfolioToken memory portfolioToken = portfolio[i];
            uint256 tokenAmount = (_amount * portfolioToken.share) / BIPS;
            uint256 amountOutMinimum = getExpectedMinAmountToken(portfolioToken.token, _amount, _fee);

            IV3SwapRouter.ExactInputSingleParams memory params =
                IV3SwapRouter.ExactInputSingleParams({
                    tokenIn: address(TOKEN),
                    tokenOut: portfolioToken.token,
                    fee: _fee,
                    recipient: address(this),
                    amountIn: tokenAmount,
                    amountOutMinimum: amountOutMinimum,
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

    function _checkPortfolioExistence(uint256 _portfolioId) private view {
        if (portfolios[_portfolioId].length > 0) {
            revert PortfolioDoesNotExist(_portfolioId);
        }
    }
}
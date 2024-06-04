// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.24;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";


contract PortfolioMarket is AccessControl {
    using SafeERC20 for IERC20;

    IUniswapV3Factory public immutable UNISWAP_FACTORY; 
    IV3SwapRouter public immutable SWAP_ROUTER;
    IERC20 public immutable TOKEN;

    uint256 public constant DEFAULT_TRANSACTION_TIMEOUT = 1000;
    uint24 public constant DEFAULT_FEE = 3_000;
    uint256 public constant BIPS = 100_00;

    struct TokenShare {
        address token;
        uint256 share;
    }

    mapping(uint256 => TokenShare[]) public portfolios;
    uint256 public portfolioCount;

    constructor(address _admin, address _token, address _swapRouter, address _uniswapFactory)  {
        grantRole(DEFAULT_ADMIN_ROLE, _admin);

        UNISWAP_FACTORY = IUniswapV3Factory(_uniswapFactory);
        SWAP_ROUTER = IV3SwapRouter(_swapRouter);
        TOKEN = IERC20(_token);
    }

    function addPortfolio(TokenShare[] memory _portfolio) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 totalShares;
        for (uint256 i = 0; i < _portfolio.length; i++) {
            TokenShare memory tokenShare = _portfolio[i];

            if (!tokenExistsOnUniswap(tokenShare.token)) {
                revert("Token doesn't exist");
            }

            totalShares += tokenShare.share;
        }
        if (totalShares != BIPS) {
            revert("Total shares sum must be 100%");
        } 

        portfolios[portfolioCount] = _portfolio;
        portfolioCount++;
    }

    function buyPortfolio(uint256 _portfolioId, uint256 _amount, uint24 _fee) public {
        if (_amount == 0 ) revert("Amount should be greater than zero");
        if (_portfolioId > portfolioCount) revert("Portfolio does not exist"); 

        TOKEN.safeTransferFrom(msg.sender, address(this), _amount);
        TokenShare[] memory portfolio = portfolios[_portfolioId];
        uint24 fee = _fee != 0 ? _fee : DEFAULT_FEE;

        for (uint256 i = 0; i < portfolio.length; i++) {
            TokenShare memory tokenShare = portfolio[i];
            uint256 tokenAmount = (_amount * tokenShare.share) / BIPS;

            IV3SwapRouter.ExactInputSingleParams memory params =
                IV3SwapRouter.ExactInputSingleParams({
                    tokenIn: address(TOKEN),
                    tokenOut: tokenShare.token,
                    fee: fee,
                    recipient: address(this),
                    amountIn: tokenAmount,
                    amountOutMinimum: 0, // need to fix later
                    sqrtPriceLimitX96: 0
                });

            SWAP_ROUTER.exactInputSingle(params);
        }
    }

    function tokenExistsOnUniswap(address _token) public view returns (bool) {
        address pair = UNISWAP_FACTORY.getPool(_token, address(TOKEN), DEFAULT_FEE); // need to fix later (DEFAULT_FEE)
        return pair != address(0);
    }
}
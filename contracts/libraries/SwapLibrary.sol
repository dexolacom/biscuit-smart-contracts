// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import {OracleLibrary} from "./OracleLibrary.sol";
import {BiscuitV1} from "../BiscuitV1.sol";

error PoolDoesNotExist();

library SwapLibrary {
    function swap(
        BiscuitV1 _biscuit,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint24 _poolFee
    ) external returns (uint256 amountOut) {
        // uint256 amountOutMinimum = _getExpectedMinAmountToken(
        //     _biscuit,
        //     _tokenIn,
        //     _tokenOut,
        //     _amountIn,
        //     _poolFee
        // );

        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: _poolFee,
                recipient: address(this),
                amountIn: _amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        IV3SwapRouter swapRouter = _biscuit.SWAP_ROUTER();
        amountOut = swapRouter.exactInputSingle(params);
    }

    function _getExpectedMinAmountToken(
        BiscuitV1 _biscuit,
        address _baseToken,
        address _quoteToken,
        uint256 _amountIn,
        uint24 _poolFee
    ) private view returns (uint256 amountOutMinimum) {
        IUniswapV3Factory uniswapFactory = _biscuit.UNISWAP_FACTORY();
        uint256 SLIPPAGE_MULTIPLIER = _biscuit.SLIPPAGE_MULTIPLIER();
        uint256 MAX_BIPS = _biscuit.MAX_BIPS();
        uint256 _serviceFee = _biscuit.serviceFee();
        uint32 secondsAgo = _biscuit.secondsAgo();

        address pool = IUniswapV3Factory(uniswapFactory).getPool(
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

        amountOutMinimum = (amountOut * (SLIPPAGE_MULTIPLIER - _serviceFee)) / MAX_BIPS;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import {OracleLibrary} from "./OracleLibrary.sol";
import {BiscuitV1} from "../BiscuitV1.sol";

error PoolDoesNotExist();

/// @title SwapLibrary
/// @notice Provides functionality for token swaps using Uniswap V3 within the BiscuitV1 contract.
library SwapLibrary {
    /// @notice Performs a token swap from `_tokenIn` to `_tokenOut` using Uniswap V3.
    /// @param _biscuit The instance of the BiscuitV1 contract.
    /// @param _tokenIn The address of the input token.
    /// @param _tokenOut The address of the output token.
    /// @param _amountIn The amount of input tokens to swap.
    /// @param _transactionTimeout The transaction timeout in seconds.
    /// @param _poolFee The pool fee for the Uniswap transaction.
    /// @return amountOut The amount of output tokens received from the swap.
    /// @dev Uses multiswap if pool with `_tokenIn` to `_tokenOut` does not exist.
    function swap(
        BiscuitV1 _biscuit,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _transactionTimeout,
        uint24 _poolFee
    ) external returns (uint256 amountOut) {
        IUniswapV3Factory uniswapFactory = _biscuit.UNISWAP_FACTORY();
        address pool = uniswapFactory.getPool(_tokenIn, _tokenOut, _poolFee);

        if (pool != address(0)) {
            // TODO: Currently we do not calculate amountOutMinimum as this calculation may not be correct in the Sepolia network.
            // TODO: We do not use `_transactionTimeout` since the existing router in Sepolia network does not accept this parameter.
            // TODO: !The above-mentioned things must be changed if the contact should be deployed in the Mainnet network.
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
                    recipient: address(_biscuit),
                    amountIn: _amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });

            IV3SwapRouter swapRouter = _biscuit.SWAP_ROUTER();
            amountOut = swapRouter.exactInputSingle(params);
        } else {
            address purchaseToken = address(_biscuit.PURCHASE_TOKEN());
            bytes memory path = abi.encodePacked(_tokenIn, _poolFee, purchaseToken, _poolFee, _tokenOut);

            // uint256 amountOutMinimum = _getExpectedMinAmountToken(
            //     _biscuit,
            //     purchaseToken,
            //     _tokenOut,
            //     _amountIn,
            //     _poolFee
            // );

            IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter
                .ExactInputParams({
                    path: path,
                    recipient: address(_biscuit),
                    amountIn: _amountIn,
                    amountOutMinimum: 0
                });

            IV3SwapRouter swapRouter = _biscuit.SWAP_ROUTER();
            amountOut = swapRouter.exactInput(params);
        }
    }

    /// @notice Calculates the expected minimum amount of output tokens from a swap, considering slippage and service fees.
    /// @param _biscuit The instance of the BiscuitV1 contract.
    /// @param _baseToken The address of the base token in the swap.
    /// @param _quoteToken The address of the quote token in the swap.
    /// @param _amountIn The amount of input tokens.
    /// @param _poolFee The pool fee for the Uniswap transaction.
    /// @return amountOutMinimum The minimum amount of output tokens expected from the swap.
    /// @dev Reverts with `PoolDoesNotExist` if the Uniswap pool does not exist.
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

        address pool = uniswapFactory.getPool(
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

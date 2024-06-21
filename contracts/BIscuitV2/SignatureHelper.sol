// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {INonfungiblePositionManager} from '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";

/// @title SignatureHelper
/// @notice Provides functions to generate signatures and calldata for various Uniswap V3 operations.
contract SignatureHelper {
    
    /// @notice Generates the signature and calldata for an exact input single swap.
    /// @param tokenIn The address of the input token.
    /// @param tokenOut The address of the output token.
    /// @param fee The pool fee.
    /// @param recipient The address to receive the output tokens.
    /// @param amountIn The amount of input tokens.
    /// @param amountOutMinimum The minimum amount of output tokens.
    /// @param sqrtPriceLimitX96 The price limit for the swap.
    /// @return signature The function signature.
    /// @return callData The encoded function calldata.
    function getSwapSignature(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96
    ) external pure returns (string memory signature, bytes memory callData) {
        signature = "exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))";
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: recipient,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        callData = abi.encode(params);
    }

    /// @notice Generates the signature and calldata for a multi-hop swap.
    /// @param path The encoded swap path.
    /// @param recipient The address to receive the output tokens.
    /// @param amountIn The amount of input tokens.
    /// @param amountOutMinimum The minimum amount of output tokens.
    /// @return signature The function signature.
    /// @return callData The encoded function calldata.
    function getMultiSwapSignature(
        bytes memory path,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external pure returns (string memory signature, bytes memory callData) {
        signature = "exactInput((bytes,address,uint256,uint256))";
        IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
            path: path,
            recipient: recipient,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum
        });
        callData = abi.encode(params);
    }

    /// @notice Generates the signature and calldata for adding liquidity to a position.
    /// @param tokenId The ID of the token representing the position.
    /// @param amount0Desired The desired amount of token0 to be spent.
    /// @param amount1Desired The desired amount of token0 to be spent.
    /// @param amount0Min The minimum amount of token0.
    /// @param amount1Min The minimum amount of token1.
    /// @param deadline The deadline for the transaction.
    /// @return signature The function signature.
    /// @return callData The encoded function calldata.
    function getAddLiquiditySignature(
        uint256 tokenId,
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external pure returns (string memory signature, bytes memory callData) {
        signature = "increaseLiquidity(uint256,uint128,uint256,uint256,uint256)";
        INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager.IncreaseLiquidityParams({
            tokenId: tokenId,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            deadline: deadline
        });
        callData = abi.encode(params);
    }

    /// @notice Generates the signature and calldata for removing liquidity from a position.
    /// @param tokenId The ID of the token representing the position.
    /// @param liquidity The amount of liquidity to remove.
    /// @param amount0Min The minimum amount of token0.
    /// @param amount1Min The minimum amount of token1.
    /// @param deadline The deadline for the transaction.
    /// @return signature The function signature.
    /// @return callData The encoded function calldata.
    function getRemoveLiquiditySignature(
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external pure returns (string memory signature, bytes memory callData) {
        signature = "decreaseLiquidity(uint256,uint128,uint256,uint256,uint256)";
        INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager.DecreaseLiquidityParams({
            tokenId: tokenId,
            liquidity: liquidity,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            deadline: deadline
        });
        callData = abi.encode(params);
    }

    /// @notice Generates the signature and calldata for approving a spender.
    /// @param spender The address of the spender.
    /// @param amount The amount to approve.
    /// @return signature The function signature.
    /// @return callData The encoded function calldata.
    function getApproveSignature(
        address spender,
        uint256 amount
    ) external pure returns (string memory signature, bytes memory callData) {
        signature = "approve(address,uint256)";
        callData = abi.encode(spender, amount);
    }

    /// @notice Generates the signature and calldata for transferring tokens from one address to another.
    /// @param from The address to transfer from.
    /// @param to The address to transfer to.
    /// @param amount The amount to transfer.
    /// @return signature The function signature.
    /// @return callData The encoded function calldata.
    function getTransferFromSignature(
        address from,
        address to,
        uint256 amount
    ) external pure returns (string memory signature, bytes memory callData) {
        signature = "transferFrom(address,address,uint256)";
        callData = abi.encode(from, to, amount);
    }
}

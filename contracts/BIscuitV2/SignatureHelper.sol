// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {INonfungiblePositionManager} from '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import {IV3SwapRouter} from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";

contract SignatureHelper {    
    function generateSwapSignature(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        uint160 sqrtPriceLimitX96
    ) external pure returns (string memory signature, bytes memory callData) {
        signature = "exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))";
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
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

    function generateMultiSwapSignature(
        bytes memory path,
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external pure returns (string memory signature, bytes memory callData) {
        signature = "exactInput((bytes,address,uint256,uint256))";
        IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter
            .ExactInputParams({
                path: path,
                recipient: recipient,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum
            });
        callData = abi.encode(params);
    }


    function generateAddLiquiditySignature(
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external pure returns (string memory signature, bytes memory callData) {
        signature = "increaseLiquidity(uint256,uint128,uint256,uint256,uint256)";
        INonfungiblePositionManager.IncreaseLiquidityParams memory params =
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: deadline
            });
        callData = abi.encode(params);
    }

    function generateRemoveLiquiditySignature(
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        uint256 deadline
    ) external pure returns (string memory signature, bytes memory callData) {
        signature = "decreaseLiquidity(uint256,uint128,uint256,uint256,uint256)";
        INonfungiblePositionManager.DecreaseLiquidityParams memory params =
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: amount0Min,
                amount1Min: amount1Min,
                deadline: deadline
            });
        callData = abi.encode(params);
    }

    function generateApproveSignature(
        address spender,
        uint256 amount
    ) external pure returns (string memory signature, bytes memory callData) {
        signature = "approve(address,uint256)";
        callData = abi.encode(spender, amount);
    }

    function generateTransferFromSignature(
        address from,
        address to,
        uint256 amount
    ) external pure returns (string memory signature, bytes memory callData) {
        signature = "transferFrom(address,address,uint256)";
        callData = abi.encode(from, to, amount);
    }
}

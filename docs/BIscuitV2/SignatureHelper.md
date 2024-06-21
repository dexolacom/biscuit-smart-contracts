# Solidity API

## SignatureHelper

Provides functions to generate signatures and calldata for various Uniswap V3 operations.

### getSwapSignature

```solidity
function getSwapSignature(address tokenIn, address tokenOut, uint24 fee, address recipient, uint256 amountIn, uint256 amountOutMinimum, uint160 sqrtPriceLimitX96) external pure returns (string signature, bytes callData)
```

Generates the signature and calldata for an exact input single swap.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenIn | address | The address of the input token. |
| tokenOut | address | The address of the output token. |
| fee | uint24 | The pool fee. |
| recipient | address | The address to receive the output tokens. |
| amountIn | uint256 | The amount of input tokens. |
| amountOutMinimum | uint256 | The minimum amount of output tokens. |
| sqrtPriceLimitX96 | uint160 | The price limit for the swap. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| signature | string | The function signature. |
| callData | bytes | The encoded function calldata. |

### getMultiSwapSignature

```solidity
function getMultiSwapSignature(bytes path, address recipient, uint256 amountIn, uint256 amountOutMinimum) external pure returns (string signature, bytes callData)
```

Generates the signature and calldata for a multi-hop swap.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| path | bytes | The encoded swap path. |
| recipient | address | The address to receive the output tokens. |
| amountIn | uint256 | The amount of input tokens. |
| amountOutMinimum | uint256 | The minimum amount of output tokens. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| signature | string | The function signature. |
| callData | bytes | The encoded function calldata. |

### getAddLiquiditySignature

```solidity
function getAddLiquiditySignature(uint256 tokenId, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, uint256 deadline) external pure returns (string signature, bytes callData)
```

Generates the signature and calldata for adding liquidity to a position.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | The ID of the token representing the position. |
| amount0Desired | uint256 | The desired amount of token0 to be spent. |
| amount1Desired | uint256 | The desired amount of token1 to be spent. |
| amount0Min | uint256 | The minimum amount of token0 to spend, which serves as a slippage check. |
| amount1Min | uint256 | The minimum amount of token1 to spend, which serves as a slippage check. |
| deadline | uint256 | The deadline for the transaction. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| signature | string | The function signature. |
| callData | bytes | The encoded function calldata. |

### getRemoveLiquiditySignature

```solidity
function getRemoveLiquiditySignature(uint256 tokenId, uint128 liquidity, uint256 amount0Min, uint256 amount1Min, uint256 deadline) external pure returns (string signature, bytes callData)
```

Generates the signature and calldata for removing liquidity from a position.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| tokenId | uint256 | The ID of the token representing the position. |
| liquidity | uint128 | The amount of liquidity to remove. |
| amount0Min | uint256 | The minimum amount of token0. |
| amount1Min | uint256 | The minimum amount of token1. |
| deadline | uint256 | The deadline for the transaction. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| signature | string | The function signature. |
| callData | bytes | The encoded function calldata. |

### getApproveSignature

```solidity
function getApproveSignature(address spender, uint256 amount) external pure returns (string signature, bytes callData)
```

Generates the signature and calldata for approving a spender.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| spender | address | The address of the spender. |
| amount | uint256 | The amount to approve. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| signature | string | The function signature. |
| callData | bytes | The encoded function calldata. |

### getTransferFromSignature

```solidity
function getTransferFromSignature(address from, address to, uint256 amount) external pure returns (string signature, bytes callData)
```

Generates the signature and calldata for transferring tokens from one address to another.

#### Parameters

| Name | Type | Description |
| ---- | ---- | ----------- |
| from | address | The address to transfer from. |
| to | address | The address to transfer to. |
| amount | uint256 | The amount to transfer. |

#### Return Values

| Name | Type | Description |
| ---- | ---- | ----------- |
| signature | string | The function signature. |
| callData | bytes | The encoded function calldata. |


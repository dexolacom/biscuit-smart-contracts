# Solidity API

## PoolDoesNotExist

```solidity
error PoolDoesNotExist()
```

Thrown when a pool does not exist.

## SwapLibrary

Provides functionality for token swaps using Uniswap V3 within the BiscuitV1 contract.

### swap

```solidity
function swap(contract BiscuitV1 _biscuit, address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _transactionTimeout, uint24 _poolFee) external returns (uint256 amountOut)
```

Performs a token swap from `_tokenIn` to `_tokenOut` using Uniswap V3.

_Uses multiswap if pool with `_tokenIn` to `_tokenOut` does not exist._

#### Parameters

| Name                 | Type               | Description                               |
| -------------------- | ------------------ | ----------------------------------------- |
| \_biscuit            | contract BiscuitV1 | The instance of the BiscuitV1 contract.   |
| \_tokenIn            | address            | The address of the input token.           |
| \_tokenOut           | address            | The address of the output token.          |
| \_amountIn           | uint256            | The amount of input tokens to swap.       |
| \_transactionTimeout | uint256            | The transaction timeout in seconds.       |
| \_poolFee            | uint24             | The pool fee for the Uniswap transaction. |

#### Return Values

| Name      | Type    | Description                                         |
| --------- | ------- | --------------------------------------------------- |
| amountOut | uint256 | The amount of output tokens received from the swap. |

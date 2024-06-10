# Solidity API

## ArrayMismatch

```solidity
error ArrayMismatch()
```

Error indicating that the provided arrays have mismatched lengths.

## MustProvideActions

```solidity
error MustProvideActions()
```

Error indicating that no actions were provided.

## TooManyOperations

```solidity
error TooManyOperations()
```

Error indicating that too many operations were provided.

## TransactionExecutionReverted

```solidity
error TransactionExecutionReverted()
```

Error indicating that a transaction execution reverted.

## NotApprovedOrOwner

```solidity
error NotApprovedOrOwner()
```

Error indicating that the caller is not approved or the owner.

## Biscuit

This contract allows minting and burning of NFTs with custom actions on mint and burn.

_Inherits from OpenZeppelin's ERC721 implementation._

### MintParams

Parameters required for minting a new token.

#### Parameters

| Name       | Type      | Description                                                                           |
| ---------- | --------- | ------------------------------------------------------------------------------------- |
| to         | address   | The address that will receive the minted token.                                       |
| targets    | address[] | The array of target addresses for executing transactions during minting.              |
| values     | uint256[] | The array of values (ETH) to send with each transaction during minting.               |
| signatures | string[]  | The array of function signatures for the transactions during minting.                 |
| calldatas  | bytes[]   | The array of calldata for the transactions during minting (parameters for functions). |

```solidity
struct MintParams {
  address to;
  address[] targets;
  uint256[] values;
  string[] signatures;
  bytes[] calldatas;
}
```

### BurnParams

Parameters required for burning a token.

#### Parameters

| Name       | Type      | Description                                                                           |
| ---------- | --------- | ------------------------------------------------------------------------------------- |
| targets    | address[] | The array of target addresses for executing transactions during burning.              |
| values     | uint256[] | The array of values (ETH) to send with each transaction during burning.               |
| signatures | string[]  | The array of function signatures for the transactions during burning.                 |
| calldatas  | bytes[]   | The array of calldata for the transactions during burning (parameters for functions). |

```solidity
struct BurnParams {
  address[] targets;
  uint256[] values;
  string[] signatures;
  bytes[] calldatas;
}
```

### MAX_OPERATIONS

```solidity
uint256 MAX_OPERATIONS
```

Maximum number of operations allowed in a single transaction - 12.

### tokenId

```solidity
uint256 tokenId
```

The current token ID to be minted next.

### burnParamsByTokenId

```solidity
mapping(uint256 => struct Biscuit.BurnParams) burnParamsByTokenId
```

Mapping from token ID to burn parameters.

### constructor

```solidity
constructor() public
```

Initializes the contract with a name and a symbol.

### mint

```solidity
function mint(struct Biscuit.MintParams mintParams, struct Biscuit.BurnParams burnParams) external payable returns (bytes[])
```

Mints a new token, executes specified actions, and sets up future burn actions.
Actions can include operations such as staking, swapping, or interacting with other contracts.

_This function increments the tokenId, mints a new ERC721 token to the specified address, stores the burn parameters, and executes a series of transactions._

#### Parameters

| Name       | Type                      | Description                                                                           |
| ---------- | ------------------------- | ------------------------------------------------------------------------------------- |
| mintParams | struct Biscuit.MintParams | Parameters for minting a new token (see `MintParams` struct for details).             |
| burnParams | struct Biscuit.BurnParams | Parameters for burning the token in the future (see `BurnParams` struct for details). |

#### Return Values

| Name | Type    | Description                                                         |
| ---- | ------- | ------------------------------------------------------------------- |
| data | bytes[] | Array of return data from the executed transactions during minting. |

### burn

```solidity
function burn(uint256 _tokenId) external payable returns (bytes[])
```

Burns an existing token and executes specified actions.
Actions can include operations such as unstaking, swapping, or interacting with other contracts.

_This function checks if the caller is authorized, burns the token, and executes a series of transactions stored in the burn parameters._

#### Parameters

| Name      | Type    | Description                       |
| --------- | ------- | --------------------------------- |
| \_tokenId | uint256 | The ID of the token to be burned. |

#### Return Values

| Name | Type    | Description                                                         |
| ---- | ------- | ------------------------------------------------------------------- |
| data | bytes[] | Array of return data from the executed transactions during burning. |

### updateBurnParams

```solidity
function updateBurnParams(uint256 _tokenId, struct Biscuit.BurnParams newBurnParams) external
```

Updates the burn parameters for a specific token.
This allows the owner or an approved operator to change the actions that will be executed when the token is burned.

_This function checks if the caller is authorized, then updates the burn parameters stored for the specified token._

#### Parameters

| Name          | Type                      | Description                                                    |
| ------------- | ------------------------- | -------------------------------------------------------------- |
| \_tokenId     | uint256                   | The ID of the token whose burn parameters are being updated.   |
| newBurnParams | struct Biscuit.BurnParams | The new burn parameters (see `BurnParams` struct for details). |

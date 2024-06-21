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

## ERC721

### Transfer

```solidity
event Transfer(address from, address to, uint256 tokenId)
```

_Emitted when `tokenId` token is transferred from `from` to `to`._

### Approval

```solidity
event Approval(address owner, address approved, uint256 tokenId)
```

_Emitted when `owner` enables `approved` to manage the `tokenId` token._

### ApprovalForAll

```solidity
event ApprovalForAll(address owner, address operator, bool approved)
```

_Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets._

### balanceOf

```solidity
function balanceOf(address owner) external view returns (uint256 balance)
```

_Returns the number of tokens in `owner`'s account._

### ownerOf

```solidity
function ownerOf(uint256 tokenId) external view returns (address owner)
```

\_Returns the owner of the `tokenId` token.

Requirements:

-   `tokenId` must exist.\_

### safeTransferFrom

```solidity
function safeTransferFrom(address from, address to, uint256 tokenId, bytes data) external
```

\_Safely transfers `tokenId` token from `from` to `to`.

Requirements:

-   `from` cannot be the zero address.
-   `to` cannot be the zero address.
-   `tokenId` token must exist and be owned by `from`.
-   If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
-   If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
    a safe transfer.

Emits a {Transfer} event.\_

### safeTransferFrom

```solidity
function safeTransferFrom(address from, address to, uint256 tokenId) external
```

\_Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
are aware of the ERC721 protocol to prevent tokens from being forever locked.

Requirements:

-   `from` cannot be the zero address.
-   `to` cannot be the zero address.
-   `tokenId` token must exist and be owned by `from`.
-   If the caller is not `from`, it must have been allowed to move this token by either {approve} or
    {setApprovalForAll}.
-   If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
    a safe transfer.

Emits a {Transfer} event.\_

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 tokenId) external
```

\_Transfers `tokenId` token from `from` to `to`.

WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
understand this adds an external call which potentially creates a reentrancy vulnerability.

Requirements:

-   `from` cannot be the zero address.
-   `to` cannot be the zero address.
-   `tokenId` token must be owned by `from`.
-   If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.

Emits a {Transfer} event.\_

### approve

```solidity
function approve(address to, uint256 tokenId) external
```

\_Gives permission to `to` to transfer `tokenId` token to another account.
The approval is cleared when the token is transferred.

Only a single account can be approved at a time, so approving the zero address clears previous approvals.

Requirements:

-   The caller must own the token or be an approved operator.
-   `tokenId` must exist.

Emits an {Approval} event.\_

### setApprovalForAll

```solidity
function setApprovalForAll(address operator, bool approved) external
```

\_Approve or remove `operator` as an operator for the caller.
Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.

Requirements:

-   The `operator` cannot be the address zero.

Emits an {ApprovalForAll} event.\_

### getApproved

```solidity
function getApproved(uint256 tokenId) external view returns (address operator)
```

\_Returns the account approved for `tokenId` token.

Requirements:

-   `tokenId` must exist.\_

### isApprovedForAll

```solidity
function isApprovedForAll(address owner, address operator) external view returns (bool)
```

\_Returns if the `operator` is allowed to manage all of the assets of `owner`.

See {setApprovalForAll}\_

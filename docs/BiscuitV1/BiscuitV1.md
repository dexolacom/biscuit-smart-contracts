# Solidity API

## NotContract

```solidity
error NotContract(address account)
```

_Thrown when the provided address is not a contract._

### Parameters

| Name    | Type    | Description                         |
| ------- | ------- | ----------------------------------- |
| account | address | The address that is not a contract. |

## PortfolioDoesNotExist

```solidity
error PortfolioDoesNotExist()
```

_Thrown when the specified portfolio does not exist._

## PortfolioManagerIsZeroAddrress

```solidity
error PortfolioManagerIsZeroAddrress()
```

_Thrown when the portfolio manager address is zero._

## PortfolioManagerNotSet

```solidity
error PortfolioManagerNotSet()
```

_Thrown when the portfolio manager is already set to the provided address._

## PortfolioIsDisabled

```solidity
error PortfolioIsDisabled()
```

_Thrown when the specified portfolio is disabled._

## ValueUnchanged

```solidity
error ValueUnchanged()
```

_Thrown when there is no change in value._

## PoolDoesNotExist

```solidity
error PoolDoesNotExist()
```

_Thrown when the Uniswap pool does not exist._

## NotApprovedOrOwner

```solidity
error NotApprovedOrOwner()
```

_Thrown when the caller is not the approved or owner._

## MixedPaymentNotAllowed

```solidity
error MixedPaymentNotAllowed()
```

_Thrown when mixed payment (ETH and token) is not allowed._

## SecondsAgoTooSmall

```solidity
error SecondsAgoTooSmall()
```

_Thrown when the specified time interval is too small._

## PaymentAmountZero

```solidity
error PaymentAmountZero()
```

_Thrown when the payment amount is zero._

## WithdrawFailed

```solidity
error WithdrawFailed()
```

_Thrown when token withdrawal fails._

## ETHTransferFailed

```solidity
error ETHTransferFailed()
```

_Thrown when ETH transfer fails._

## BiscuitV1

This contract allows users to buy and sell portfolios of tokens via Uniswap V3.

_Inherits ERC721 for NFT representation of portfolios and AccessControl for role-based access control._

### PurchasedToken

_Structure to store purchased token details._

```solidity
struct PurchasedToken {
  address token;
  uint256 amount;
}
```

### PurchasedPortfolio

_Structure to store purchased portfolio details._

```solidity
struct PurchasedPortfolio {
  bool purchasedWithETH;
  struct BiscuitV1.PurchasedToken[] purchasedTokens;
}
```

### UNISWAP_FACTORY

```solidity
contract IUniswapV3Factory UNISWAP_FACTORY
```

Address of the Uniswap V3 Factory.

### SWAP_ROUTER

```solidity
contract IV3SwapRouter SWAP_ROUTER
```

Address of the Uniswap V3 Swap Router that can be swap token.

### PURCHASE_TOKEN

```solidity
contract IERC20 PURCHASE_TOKEN
```

Address of the token used for purchasing portfolios.

### WETH

```solidity
contract IWETH WETH
```

Address of (WETH) token used for purchasing portfolios for ETH.

### portfolioManager

```solidity
contract PortfolioManager portfolioManager
```

Contract that can manages portfolios available for purchase.

### MAX_BIPS

```solidity
uint256 MAX_BIPS
```

Maximum basis points (100%).

### SLIPPAGE_MULTIPLIER

```solidity
uint256 SLIPPAGE_MULTIPLIER
```

Multiplier for slippage calculation (95%).

### DEFAULT_TRANSACTION_TIMEOUT

```solidity
uint256 DEFAULT_TRANSACTION_TIMEOUT
```

Default timeout for one swap in transactions (15 minutes).

### DEFAULT_POOL_FEE

```solidity
uint24 DEFAULT_POOL_FEE
```

Default pool fee for Uniswap transactions (0.3%).

### secondsAgo

```solidity
uint32 secondsAgo
```

Time interval in seconds to consider for price calculations (2 hours).

### serviceFee

```solidity
uint256 serviceFee
```

Service fee in basis points (1%).

### nextTokenId

```solidity
uint256 nextTokenId
```

ID for the next portfolio token to be minted.

### purchasedPortfolios

```solidity
mapping(uint256 => struct BiscuitV1.PurchasedPortfolio) purchasedPortfolios
```

Mapping from token ID to purchased portfolio details.

### PortfolioManagerUpdated

```solidity
event PortfolioManagerUpdated(address portfolioManager)
```

_Event emitted when the portfolio manager is updated._

#### Parameters

| Name             | Type    | Description                           |
| ---------------- | ------- | ------------------------------------- |
| portfolioManager | address | Address of the new portfolio manager. |

### PortfolioPurchased

```solidity
event PortfolioPurchased(uint256 portfolioId, address buyer, uint256 amountToken, uint256 amountETH)
```

_Event emitted when a portfolio is purchased._

#### Parameters

| Name        | Type    | Description                    |
| ----------- | ------- | ------------------------------ |
| portfolioId | uint256 | ID of the purchased portfolio. |
| buyer       | address | Address of the buyer.          |
| amountToken | uint256 | Amount of tokens spent.        |
| amountETH   | uint256 | Amount of ETH spent.           |

### PortfolioSold

```solidity
event PortfolioSold(uint256 tokenId, address seller)
```

_Event emitted when a portfolio is sold._

#### Parameters

| Name    | Type    | Description                     |
| ------- | ------- | ------------------------------- |
| tokenId | uint256 | ID of the sold portfolio token. |
| seller  | address | Address of the seller.          |

### SecondsAgoUpdated

```solidity
event SecondsAgoUpdated(uint32 newSecondsAgo)
```

_Event emitted when the secondsAgo parameter is updated._

#### Parameters

| Name          | Type   | Description               |
| ------------- | ------ | ------------------------- |
| newSecondsAgo | uint32 | New value for secondsAgo. |

### ServiceFeeUpdated

```solidity
event ServiceFeeUpdated(uint256 serviceFee)
```

_Event emitted when the service fee is updated._

#### Parameters

| Name       | Type    | Description                    |
| ---------- | ------- | ------------------------------ |
| serviceFee | uint256 | New value for the service fee. |

### constructor

```solidity
constructor(address _admin, address _uniswapFactory, address _swapRouter, address _purchaseToken, address _weth) public
```

_Constructor for the BiscuitV1 contract._

#### Parameters

| Name             | Type    | Description                                                 |
| ---------------- | ------- | ----------------------------------------------------------- |
| \_admin          | address | Address of the contract admin.                              |
| \_uniswapFactory | address | Address of the Uniswap V3 Factory.                          |
| \_swapRouter     | address | Address of the Uniswap V3 Swap Router.                      |
| \_purchaseToken  | address | Address of the token used for purchasing portfolios.        |
| \_weth           | address | Address of the (WETH) token used for purchasing portfolios. |

### buyPortfolioERC20

```solidity
function buyPortfolioERC20(uint256 _portfolioId, uint256 _amountToken, uint256 _transactionTimeout, uint24 _poolFee) external
```

Buy a portfolio using purchase token. Minting NFT to caller that identifies portfolio ownership.
Charges a service fee from the total amount token.

_Reverts if the token amount is zero, portfolio with this ID doesn't exist or disabled.
If `_poolFee` is 0, a default fee of 0.3% will be used
If `_transactionTimeout` is 0, a default transactionTimeout of 15 minutes will be used._

#### Parameters

| Name                 | Type    | Description                                       |
| -------------------- | ------- | ------------------------------------------------- |
| \_portfolioId        | uint256 | The ID of the portfolio to purchase.              |
| \_amountToken        | uint256 | The amount of tokens to spend on the portfolio.   |
| \_transactionTimeout | uint256 | The transaction timeout for each swap in seconds. |
| \_poolFee            | uint24  | The pool fee for the Uniswap transaction.         |

### buyPortfolioETH

```solidity
function buyPortfolioETH(uint256 _portfolioId, uint256 _transactionTimeout, uint24 _poolFee) external payable
```

Buy a portfolio using ETH. Minting NFT to caller that identifies portfolio ownership.
Charges a service fee from the total amount ETH.

_Convert ETH to WETH before swap.
Reverts if the amount ETH is zero, portfolio with this ID doesn't exist or disabled.
If `_poolFee` is 0, a default fee of 0.3% will be used
If `_transactionTimeout` is 0, a default transactionTimeout of 15 minutes will be used._

#### Parameters

| Name                 | Type    | Description                                       |
| -------------------- | ------- | ------------------------------------------------- |
| \_portfolioId        | uint256 | The ID of the portfolio to purchase.              |
| \_transactionTimeout | uint256 | The transaction timeout for each swap in seconds. |
| \_poolFee            | uint24  | The pool fee for the Uniswap transaction.         |

### sellPortfolio

```solidity
function sellPortfolio(address _tokenOut, uint256 _tokenId, uint256 _transactionTimeout, uint24 _poolFee) external
```

Sell a purchased portfolio. Burning NFT with this `_tokenId` that identifies portfolio ownership.
Sends the amount `_tokenOut` from sale of portfolio to the caller.

_If `_tokenOut` is WETH, WETH will be converted to ETH before sending to user.
Reverts with `NotApprovedOrOwner` if the caller is not the approved or owner this NFT.
Reverts with `ETHTransferFailed` if the ETH transfer to user fails.
If `_poolFee` is 0, a default fee of 0.3% will be used
If `_transactionTimeout` is 0, a default transactionTimeout of 15 minutes will be used._

#### Parameters

| Name                 | Type    | Description                                         |
| -------------------- | ------- | --------------------------------------------------- |
| \_tokenOut           | address | The token to receive in exchange for the portfolio. |
| \_tokenId            | uint256 | The ID of the portfolio token to sell.              |
| \_transactionTimeout | uint256 | The transaction timeout in seconds.                 |
| \_poolFee            | uint24  | The pool fee for the Uniswap transaction.           |

### setPortfolioManager

```solidity
function setPortfolioManager(address _portfolioManager) external
```

Set the address of the portfolio manager.

_Reverts with `PortfolioManagerIsZeroAddrress` if the provided address is zero.
Reverts with `ValueUnchanged` if the new address is the same as the current one._

#### Parameters

| Name               | Type    | Description                        |
| ------------------ | ------- | ---------------------------------- |
| \_portfolioManager | address | The new portfolio manager address. |

### updateSecondsAgo

```solidity
function updateSecondsAgo(uint32 _newSecondsAgo) external
```

Update the secondsAgo parameter.

_Reverts with `SecondsAgoTooSmall` if the new value is less than 1 minute.
Reverts with `ValueUnchanged` if the new value is the same as the current one._

#### Parameters

| Name            | Type   | Description               |
| --------------- | ------ | ------------------------- |
| \_newSecondsAgo | uint32 | The new secondsAgo value. |

### updateServiceFee

```solidity
function updateServiceFee(uint256 _newServiceFee) external
```

Update the service fee.

_Reverts with `ValueUnchanged` if the new value is the same as the current one._

#### Parameters

| Name            | Type    | Description                |
| --------------- | ------- | -------------------------- |
| \_newServiceFee | uint256 | The new service fee value. |

### withdrawTokens

```solidity
function withdrawTokens(address _token, address _receiver, uint256 _amount) external
```

Withdraw specified amount of tokens to a receiver address.

#### Parameters

| Name       | Type    | Description                    |
| ---------- | ------- | ------------------------------ |
| \_token    | address | The token address to withdraw. |
| \_receiver | address | The receiver address.          |
| \_amount   | uint256 | The amount to withdraw.        |

### withdrawAllTokens

```solidity
function withdrawAllTokens() external
```

Withdraw all tokens to the admin address.

### withdrawETH

```solidity
function withdrawETH(address _receiver, uint256 _amount) external
```

Withdraw specified amount of ETH to a receiver address.

#### Parameters

| Name       | Type    | Description             |
| ---------- | ------- | ----------------------- |
| \_receiver | address | The receiver address.   |
| \_amount   | uint256 | The amount to withdraw. |

### withdrawAllETH

```solidity
function withdrawAllETH() external
```

Withdraw all ETH to the admin address.

### getPurchasedPortfolio

```solidity
function getPurchasedPortfolio(uint256 _tokenId) public view returns (struct BiscuitV1.PurchasedPortfolio)
```

Get the purchased portfolio details for a given token ID.

#### Parameters

| Name      | Type    | Description                    |
| --------- | ------- | ------------------------------ |
| \_tokenId | uint256 | The ID of the portfolio token. |

#### Return Values

| Name | Type                                | Description                      |
| ---- | ----------------------------------- | -------------------------------- |
| [0]  | struct BiscuitV1.PurchasedPortfolio | The purchased portfolio details. |

### getPurchasedPortfolioTokenCount

```solidity
function getPurchasedPortfolioTokenCount(uint256 _tokenId) public view returns (uint256)
```

Get the number of tokens in a purchased portfolio.

#### Parameters

| Name      | Type    | Description                    |
| --------- | ------- | ------------------------------ |
| \_tokenId | uint256 | The ID of the portfolio token. |

#### Return Values

| Name | Type    | Description                                      |
| ---- | ------- | ------------------------------------------------ |
| [0]  | uint256 | The number of tokens in the purchased portfolio. |

#### Return Values

| Name | Type | Description                                                   |
| ---- | ---- | ------------------------------------------------------------- |
| [0]  | bool | True if the contract supports the interface, false otherwise. |

### receive

```solidity
receive() external payable
```

Receive function to accept ETH deposits.

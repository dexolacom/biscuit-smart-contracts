# Solidity API

## NotContract

```solidity
error NotContract(address account)
```

Thrown when a provided address is not a contract.

### Parameters

| Name    | Type    | Description                         |
| ------- | ------- | ----------------------------------- |
| account | address | The address that is not a contract. |

## TokenDoesNotExist

```solidity
error TokenDoesNotExist(address token)
```

Thrown when a token does not exist.

### Parameters

| Name  | Type    | Description                            |
| ----- | ------- | -------------------------------------- |
| token | address | The address of the non-existent token. |

## IncorrectTotalShares

```solidity
error IncorrectTotalShares(uint256 totalShares)
```

Thrown when the total shares do not sum to the required amount.

### Parameters

| Name        | Type    | Description                  |
| ----------- | ------- | ---------------------------- |
| totalShares | uint256 | The total shares calculated. |

## PortfolioDoesNotExist

```solidity
error PortfolioDoesNotExist()
```

Thrown when attempting to interact with a non-existent portfolio.

## PortfolioAlreadyEnabled

```solidity
error PortfolioAlreadyEnabled()
```

Thrown when attempting to enable an already enabled portfolio.

## PortfolioAlreadyDisabled

```solidity
error PortfolioAlreadyDisabled()
```

Thrown when attempting to disable an already disabled portfolio.

## PortfolioManager

Manages portfolios consisting of various tokens.

_Utilizes AccessControl for role-based access management._

### PORTFOLIO_MANAGER_ROLE

```solidity
bytes32 PORTFOLIO_MANAGER_ROLE
```

The constant that consist PORTFOLIO_MANAGER role. Owner of this role can mnages portfolios.

### BISCUIT

```solidity
contract BiscuitV1 BISCUIT
```

Reference to the BiscuitV1 contract.

### nextPortfolioId

```solidity
uint256 nextPortfolioId
```

Counter for the next portfolio ID.

### TokenShare

Structure to store token and its share in the portfolio.


```solidity
struct TokenShare {
  address token;
  uint256 share;
}
```

### Portfolio

Structure to store portfolio details.

```solidity
struct Portfolio {
  bool enabled;
  struct PortfolioManager.TokenShare[] tokens;
}
```

### portfolios

```solidity
mapping(uint256 => struct PortfolioManager.Portfolio) portfolios
```

Mapping from portfolio ID to Portfolio structure.

### PortfolioAdded

```solidity
event PortfolioAdded(uint256 portfolioId, struct PortfolioManager.TokenShare[] portfolioTokens)
```

Emitted when a new portfolio is added.

#### Parameters

| Name            | Type                                 | Description                           |
| --------------- | ------------------------------------ | ------------------------------------- |
| portfolioId     | uint256                              | The ID of the newly added portfolio.  |
| portfolioTokens | struct PortfolioManager.TokenShare[] | The tokens included in the portfolio. |

### PortfolioUpdated

```solidity
event PortfolioUpdated(uint256 portfolioId, struct PortfolioManager.TokenShare[] portfolioTokens)
```

Emitted when an existing portfolio is updated.

#### Parameters

| Name            | Type                                 | Description                          |
| --------------- | ------------------------------------ | ------------------------------------ |
| portfolioId     | uint256                              | The ID of the updated portfolio.     |
| portfolioTokens | struct PortfolioManager.TokenShare[] | The updated tokens in the portfolio. |

### PortfolioRemoved

```solidity
event PortfolioRemoved(uint256 portfolioId)
```

Emitted when a portfolio is removed.

#### Parameters

| Name        | Type    | Description                      |
| ----------- | ------- | -------------------------------- |
| portfolioId | uint256 | The ID of the removed portfolio. |

### PortfolioEnabled

```solidity
event PortfolioEnabled(uint256 portfolioId)
```

Emitted when a portfolio is enabled.

#### Parameters

| Name        | Type    | Description                      |
| ----------- | ------- | -------------------------------- |
| portfolioId | uint256 | The ID of the enabled portfolio. |

### PortfolioDisabled

```solidity
event PortfolioDisabled(uint256 portfolioId)
```

Emitted when a portfolio is disabled.

#### Parameters

| Name        | Type    | Description                       |
| ----------- | ------- | --------------------------------- |
| portfolioId | uint256 | The ID of the disabled portfolio. |

### constructor

```solidity
constructor(address _admin, address _biscuit) public
```

Constructor for the PortfolioManager contract.

#### Parameters

| Name      | Type    | Description                            |
| --------- | ------- | -------------------------------------- |
| \_admin   | address | The address of the admin.              |
| \_biscuit | address | The address of the BiscuitV1 contract. |

### addPortfolios

```solidity
function addPortfolios(struct PortfolioManager.TokenShare[][] _portfolios) external
```

Adds multiple portfolios.

#### Parameters

| Name         | Type                                   | Description                    |
| ------------ | -------------------------------------- | ------------------------------ |
| \_portfolios | struct PortfolioManager.TokenShare[][] | The list of portfolios to add. |

### addPortfolio

```solidity
function addPortfolio(struct PortfolioManager.TokenShare[] _portfolio) public
```

Adds a single portfolio.

_Revert if total share tokens is not equal to MAX_BIPS.
Revert if at least one token does not have a pool on uniswap._

#### Parameters

| Name        | Type                                 | Description           |
| ----------- | ------------------------------------ | --------------------- |
| \_portfolio | struct PortfolioManager.TokenShare[] | The portfolio to add. |

### removePortfolios

```solidity
function removePortfolios(uint256[] _portfolioIds) external
```

Removes multiple portfolios.

#### Parameters

| Name           | Type      | Description                          |
| -------------- | --------- | ------------------------------------ |
| \_portfolioIds | uint256[] | The list of portfolio IDs to remove. |

### removePortfolio

```solidity
function removePortfolio(uint256 _portfolioId) public
```

Removes a single portfolio.

_Revert if the ID portfolio does not exist._

#### Parameters

| Name          | Type    | Description                        |
| ------------- | ------- | ---------------------------------- |
| \_portfolioId | uint256 | The ID of the portfolio to remove. |

### enablePortfolio

```solidity
function enablePortfolio(uint256 _portfolioId) external
```

Enables a portfolio.

_Revert if the ID portfolio already enable or does not exist._

#### Parameters

| Name          | Type    | Description                        |
| ------------- | ------- | ---------------------------------- |
| \_portfolioId | uint256 | The ID of the portfolio to enable. |

### disablePortfolio

```solidity
function disablePortfolio(uint256 _portfolioId) external
```

Disables a portfolio.

_Revert if the ID portfolio already disable or does not exist._

#### Parameters

| Name          | Type    | Description                         |
| ------------- | ------- | ----------------------------------- |
| \_portfolioId | uint256 | The ID of the portfolio to disable. |

### checkPoolsToTokenExist

```solidity
function checkPoolsToTokenExist(address _token) public view returns (bool)
```

Checks if a pool exists for a given token.

#### Parameters

| Name    | Type    | Description                        |
| ------- | ------- | ---------------------------------- |
| \_token | address | The address of the token to check. |

#### Return Values

| Name | Type | Description                              |
| ---- | ---- | ---------------------------------------- |
| [0]  | bool | bool indicating whether the pool exists. |

### getPortfolio

```solidity
function getPortfolio(uint256 _portfolioId) external view returns (struct PortfolioManager.Portfolio)
```

Gets the details of a portfolio.

#### Parameters

| Name          | Type    | Description                          |
| ------------- | ------- | ------------------------------------ |
| \_portfolioId | uint256 | The ID of the portfolio to retrieve. |

#### Return Values

| Name | Type                              | Description                                           |
| ---- | --------------------------------- | ----------------------------------------------------- |
| [0]  | struct PortfolioManager.Portfolio | Portfolio structure containing the portfolio details. |

### getPortfolioTokenCount

```solidity
function getPortfolioTokenCount(uint256 _portfolioId) external view returns (uint256)
```

Gets the number of tokens in a portfolio.

#### Parameters

| Name          | Type    | Description              |
| ------------- | ------- | ------------------------ |
| \_portfolioId | uint256 | The ID of the portfolio. |

#### Return Values

| Name | Type    | Description                                               |
| ---- | ------- | --------------------------------------------------------- |
| [0]  | uint256 | uint256 indicating the number of tokens in the portfolio. |

# Biscuit Contracts

## BiscuitV1

## Overview

The BiscuitV1 contract enables the buying and selling of digital portfolios using blockchain technology and NFTs. It uses the Uniswap V3 protocol for asset swaps and handles transactions using specific tokens or ETH. Each portfolio purchase results in the minting of an NFT, which identifies ownership and can be transferred to others, it means transferring the ownership of the portfolio.

The PortfolioManager contract, as an extension of BiscuitV1, allows for the creation and management of these portfolios, ensuring their composition and enabling/disabling them as necessary.

### Portfolio Purchase Process

To purchase a portfolio, a specific token using a contract or ETH can be used. The buyer specifies the portfolio ID which wants to buy, the amount to spend, and optional transaction settings like timeout and fees. The service fee is deducted from the total invested amount. After successful purchase, a Non-Fungible Token (NFT) is minted, identifies ownership of the portfolio. This NFT serves as a digital certificate of ownership for the specified portfolio. The purchased portfolio can be tracked by token (NFT) ID.

### Portfolio Sale Process

To sell a previously purchased portfolio, this requires NFT ownership. The seller specifies the token to receive in exchange it can be ETH or a token that uses a contract (usually a stablecoin), the NFT's ID, and optional transaction settings. The system then performs the necessary swaps to convert the portfolio assets into the selected token. Once the process is complete, the NFT is burned, and the seller receives the token total amount from the sale.

### Portfolio Manager

The PortfolioManager contract allows authorized users to create, update, and manage portfolios. It includes functions to add, remove, enable, and disable portfolios, ensuring they comply with the rules.

### How to Buy and Sell Portfolio?

To buy a portfolio, use the following functions:

- `buyPortfolioERC20`: This function allows you to purchase a portfolio using ERC20 tokens. You need to specify the portfolio ID, the amount of tokens, the transaction timeout, and the pool fee.
- `buyPortfolioETH`: This function allows you to purchase a portfolio using ETH. You need to specify the portfolio ID, the transaction timeout, and the pool fee.

To sell a portfolio, use the following function:

- `sellPortfolio`: This function allows you to sell a portfolio you own. You need to specify the token to receive in exchange (ETH or a token using a contract), the NFT ID, and optional transaction settings.

For example, we offer a ready-made portfolio called MEME, which portfolio includes the following assets:

- SHIB
- PEPE
- FLOKI
- MEME

1. Please use the pool with 3000 (0.3%) fee, since the test portfolio is made with this fee. You can also use fee 0, in this case the default fee 3000 will be used.
2. You can also use 0 for the transaction time, in this case the default transaction time 15 minutes will be used.
3. MEME Portfolio ID is 1.
4. You can mint test USDT for purchase [here](https://sepolia.etherscan.io/address/0x04d0CaebCA219DAFBC394cD6e62b3181be29d1B3#writeContract).
5. Please buy with a small amount of payment. $100 to $300 if ETH is around 0.1. This is necessary for the test pools to work correctly.

*[BiscuitV1 contract](https://sepolia.etherscan.io/address/0xCaC5486c25014B457c5f938f329BCD1BffB36c71#writeContract)*.

*[PortfolioManager contract](https://sepolia.etherscan.io/address/0x65db7A467E030d25e723F393BFcEb55D77B3f780#writeContract)*.

## Biscuit V2

### Overview

The Biscuit NFT Contract is designed to be flexible, allowing users to create and destroy NFTs with custom actions.

### Minting NFTs

Minting an NFT ensures creating a new token to a specific address. During this process, the contract can execute a series of actions such as sending ETH or token, staking or swapping, interacting with other smart contracts and etc.. These actions can be configured and specified during mint.

### Burning NFTs

Burning an NFT ensures destroying an existing token. Similar to the minting process, burning a token can also trigger a series of actions, such as sending ETH or token, unstaking or swapping, interacting with other smart contracts and etc.. These actions are specified when the token is created and can be updated later by the owner.

## How It Works

1. **Minting a Token:**

    - A user specifies the recipient address and a set of actions to be executed during minting.
    - The contract creates a new token and to the specified address.
    - The contract executes the specified actions, such as swapping, staking, transfer tokens or calling functions on other contracts.

2. **Burning a Token:**

    - The token owner or an approved user can burn token.
    - The contract verifies that the caller is authorized to burn the token.
    - The contract destroys the token and executes the actions associated with burning.

3. **Updating Burn Actions:**

    - The token owner or an approved operator can update the actions to be executed when a token is burned.
    - This allows for flexibility in defining what happens when a token is burned.


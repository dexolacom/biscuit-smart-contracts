# Biscuit Contracts

## BiscuitV1

## Overview

The BiscuitV1 contract enables the buying and selling of digital portfolios using blockchain technology and NFTs. It uses the Uniswap V3 protocol for asset swaps and handles transactions using specific tokens or ETH. Each portfolio purchase results in the minting of an NFT, which identifies ownership and can be transferred to others, so transferring the ownership of the portfolio.

The PortfolioManager contract, as an extension of BiscuitV1, allows for the creation and management of these portfolios, ensuring their composition and enabling/disabling them as necessary.

### Portfolio Purchase Process

To purchase a portfolio, a specific token that uses a contract or ETH can be used. The buyer specifies the portfolio ID which wants to buy, the amount to spend, and optional transaction settings like timeout and fees. The service fee is deducted from the total invested amount. After successful purchase, a Non-Fungible Token (NFT) is minted, identifies ownership of the portfolio. This NFT serves as a digital certificate of ownership for the specified portfolio. The purchased portfolio can be tracked by token (NFT) ID.

### Portfolio Sale Process

To sell a previously purchased portfolio, this requires NFT ownership. The seller specifies the token to receive in exchange it can be ETH or a token that uses a contract (usually a stablecoin), the NFT's ID, and optional transaction settings. The system then performs the necessary swaps to convert the portfolio assets into the selected token. Once the process is complete, the NFT is burned, and the seller receives the token total amount from the sale.

### Portfolio Manager

The PortfolioManager contract allows authorized users to create, update, and manage portfolios. It includes functions to add, remove, enable, and disable portfolios, ensuring they comply with the rules.

### How to Buy and Sell Portfolio?


































# Biscuit NFT

## Overview

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


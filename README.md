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

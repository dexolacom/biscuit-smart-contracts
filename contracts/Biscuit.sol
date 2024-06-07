// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Biscuit is ERC721 {
    uint256 public tokenId;

    constructor() ERC721("Biscuit", "BSC") {}

    function mint(address to) external {
        tokenId++;
        _safeMint(to, tokenId);
    }

    function burn(uint256 _tokenId) external {
        _burn(_tokenId);
    }
}

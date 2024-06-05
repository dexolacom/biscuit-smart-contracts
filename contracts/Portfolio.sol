// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {PortfolioMarket} from "./PortfolioMarket.sol";

contract Portfolio is ERC721, AccessControl {
    bytes32 public constant MARKET_ROLE = keccak256("MARKET");

    uint256 public tokenId;

    struct PortfolioAsset {
        address token;
        uint256 amount;
    }

    mapping(uint256 => PortfolioAsset[]) public portfolios;

    constructor(address _admin, address _portfolioMarket) ERC721("PortfolioNFT", "PNFT") {
        _grantRole(MARKET_ROLE, _portfolioMarket);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function mint(address _to, PortfolioAsset[] memory _portfolio) public onlyRole(MARKET_ROLE) {
        tokenId++;
        _safeMint(_to, tokenId);

        PortfolioAsset[] storage newPortfolio = portfolios[tokenId];
        for (uint256 i = 0; i < _portfolio.length; i++) {
            newPortfolio.push(_portfolio[i]);
        }
    }

    function burn(uint256 _tokenId) public onlyRole(MARKET_ROLE) {
        _burn(_tokenId);
        delete portfolios[_tokenId];
    }

    function ownerOf(uint256 _tokenId) public view override returns(address) {
        return _ownerOf(_tokenId);
    }

    function getPortfolio(uint256 _tokenId) public view returns (PortfolioAsset[] memory) {
        return portfolios[_tokenId];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}


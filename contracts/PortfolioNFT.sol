// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {PortfolioMarket} from "./PortfolioMarket.sol";

error NotContract(address account);

contract PortfolioNFT is ERC721, AccessControl {
    bytes32 public constant MARKET_ROLE = keccak256("MARKET");

    uint256 public tokenId;

    struct TokenAmount {
        address token;
        uint256 amount;
    }

    mapping(uint256 => TokenAmount[]) public purchasedPortfolios;

    constructor(address _admin, address _portfolioMarket) ERC721("PortfolioNFT", "PNFT") {
        _checkIsContract(_portfolioMarket);

        _grantRole(MARKET_ROLE, _portfolioMarket); // expected PortfolioMarket contract
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function mint(address _to, TokenAmount[] memory _portfolio) public onlyRole(MARKET_ROLE) {
        tokenId++;
        _mint(_to, tokenId);

        TokenAmount[] storage newPortfolio = purchasedPortfolios[tokenId];
        for (uint256 i = 0; i < _portfolio.length; i++) {
            newPortfolio.push(_portfolio[i]);
        }
    }

    function burn(uint256 _tokenId) public onlyRole(MARKET_ROLE) {
        _burn(_tokenId);
        delete purchasedPortfolios[_tokenId];
    }

    function getPurchasedPortfolio(uint256 _tokenId) public view returns (TokenAmount[] memory) {
        return purchasedPortfolios[_tokenId];
    }

    function getPurchasedPortfolioTokenCount(uint256 _tokenId) public view returns (uint256) {
        return purchasedPortfolios[_tokenId].length;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _checkIsContract(address _address) private view {
        if (!(_address.code.length > 0)) {
            revert NotContract(_address);
        }
    }
}


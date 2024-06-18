// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {BiscuitV1} from "./BiscuitV1.sol";

error NotContract(address account);
error TokenDoesNotExist(address token);
error IncorrectTotalShares(uint256 totalShares);
error PortfolioDoesNotExist();
error PortfolioAlreadyEnabled();
error PortfolioAlreadyDisabled();

contract PortfolioManager is AccessControl {
    bytes32 public constant PORTFOLIO_MANAGER_ROLE = keccak256("PORTFOLIO_MANAGER");

    BiscuitV1 public immutable BISCUIT;

    uint256 public constant BIPS = 100_00;
    uint256 public portfolioId;

    struct TokenShare {
        address token;
        uint256 share;
    }

    struct Portfolio {
        bool enabled;
        TokenShare[] tokens;
    }

    mapping(uint256 => Portfolio) public portfolios;

    event PortfolioAdded(uint256 indexed portfolioId, TokenShare[] portfolioTokens);
    event PortfolioUpdated(uint256 indexed portfolioId, TokenShare[] portfolioTokens);
    event PortfolioRemoved(uint256 indexed portfolioId);
    event PortfolioEnabled(uint256 indexed portfolioId);
    event PortfolioDisabled(uint256 indexed portfolioId);

    constructor(address _admin, address _biscuit) {
        _checkIsContract(_biscuit);
        BISCUIT = BiscuitV1(payable(_biscuit));

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PORTFOLIO_MANAGER_ROLE, _admin);
    }

    function addPortfolios(TokenShare[][] memory _portfolios) external onlyRole(PORTFOLIO_MANAGER_ROLE) {
        for (uint256 i = 0; i < _portfolios.length; i++) {
            addPortfolio(_portfolios[i]);
        }
    }

    function addPortfolio(TokenShare[] memory _portfolio) public onlyRole(PORTFOLIO_MANAGER_ROLE) {
        portfolioId++;
        _checkPortfolioTokens(_portfolio);
        _addPortfolio(portfolioId, _portfolio);
        emit PortfolioAdded(portfolioId, _portfolio);
    }

    function removePortfolios(uint256[] memory _portfolioIds) external onlyRole(PORTFOLIO_MANAGER_ROLE) {
        for (uint256 i = 0; i < _portfolioIds.length; i++) {
            removePortfolio(_portfolioIds[i]);
        }
    }

    function removePortfolio(uint256 _portfolioId) public onlyRole(PORTFOLIO_MANAGER_ROLE) {
        if (portfolios[_portfolioId].tokens.length == 0) revert PortfolioDoesNotExist();

        delete portfolios[_portfolioId];
        emit PortfolioRemoved(_portfolioId);
    }

    function enablePortfolio(uint256 _portfolioId) external onlyRole(PORTFOLIO_MANAGER_ROLE) {
        if (portfolios[_portfolioId].tokens.length == 0) revert PortfolioDoesNotExist();
        if (portfolios[_portfolioId].enabled) revert PortfolioAlreadyEnabled();

        portfolios[_portfolioId].enabled = true;
        emit PortfolioEnabled(_portfolioId);
    }

    function disablePortfolio(uint256 _portfolioId) external onlyRole(PORTFOLIO_MANAGER_ROLE) {
        if (portfolios[_portfolioId].tokens.length == 0) revert PortfolioDoesNotExist();
        if (!portfolios[_portfolioId].enabled) revert PortfolioAlreadyDisabled();

        portfolios[_portfolioId].enabled = false;
        emit PortfolioDisabled(_portfolioId);
    }


    function getTokenExists(address _token) public view returns (bool) {
        IUniswapV3Factory factory = BISCUIT.UNISWAP_FACTORY(); 
        address token = address(BISCUIT.TOKEN());
        address weth = address(BISCUIT.WETH());
        uint24 poolFee = BISCUIT.DEFAULT_POOL_FEE();

        address pairToToken = factory.getPool(token, _token, poolFee); 
        address pairToWETH = factory.getPool(weth, _token, poolFee); 
        return pairToToken != address(0) || pairToWETH != address(0);
    }

    function getPortfolio(uint256 _portfolioId) external view returns (Portfolio memory) {
        return portfolios[_portfolioId];
    }

    function getPortfolioTokenCount(uint256 _portfolioId) external view returns (uint256) {
        return portfolios[_portfolioId].tokens.length;
    }

    function _addPortfolio(uint256 _portfolioId, TokenShare[] memory _portfolio) private {
        portfolios[_portfolioId].enabled = true;
        for (uint256 i = 0; i < _portfolio.length; i++) {
            portfolios[_portfolioId].tokens.push(_portfolio[i]);
        }
    }

    function _checkPortfolioTokens(TokenShare[] memory _tokens) private view {
        uint256 totalShares = 0;
        for (uint256 i = 0; i < _tokens.length; i++) {
            TokenShare memory portfolioToken = _tokens[i];
            if (!getTokenExists(portfolioToken.token)) {
                revert TokenDoesNotExist(portfolioToken.token);
            }
            totalShares += portfolioToken.share;
        }
        if (totalShares != BIPS) {
            revert IncorrectTotalShares(totalShares);
        }
    }

    function _checkIsContract(address _address) private view {
        if (!(_address.code.length > 0)) {
            revert NotContract(_address);
        }
    }
}

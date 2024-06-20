// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {BiscuitV1} from "./BiscuitV1.sol";


/// @notice Thrown when a provided address is not a contract.
/// @param account The address that is not a contract.
error NotContract(address account);
/// @notice Thrown when a token does not exist.
/// @param token The address of the non-existent token.
error TokenDoesNotExist(address token);
/// @notice Thrown when the total shares do not sum to the required amount.
/// @param totalShares The total shares calculated.
error IncorrectTotalShares(uint256 totalShares);
/// @notice Thrown when attempting to interact with a non-existent portfolio.
error PortfolioDoesNotExist();
/// @notice Thrown when attempting to enable an already enabled portfolio.
error PortfolioAlreadyEnabled();
/// @notice Thrown when attempting to disable an already disabled portfolio.
error PortfolioAlreadyDisabled();

/// @title Portfolio Manager
/// @notice Manages portfolios consisting of various tokens.
/// @dev Utilizes AccessControl for role-based access management.
contract PortfolioManager is AccessControl {
    /// @notice The constant that consist PORTFOLIO_MANAGER role. Owner of this role can mnages portfolios.
    bytes32 public constant PORTFOLIO_MANAGER_ROLE = keccak256("PORTFOLIO_MANAGER");

    /// @notice Reference to the BiscuitV1 contract.
    BiscuitV1 public immutable BISCUIT;

    /// @notice Counter for the next portfolio ID.
    uint256 public nextPortfolioId;

    /// @notice Structure to store token and its share in the portfolio.
    /// @param token Address of the token.
    /// @param share Percentage share of the token in the portfolio.
    struct TokenShare {
        address token;
        uint256 share;
    }

    /// @notice Structure to store portfolio details.
    /// @param enabled Indicates if the portfolio is enabled.
    /// @param tokens List of tokens and their shares in the portfolio.
    struct Portfolio {
        bool enabled;
        TokenShare[] tokens;
    }

    /// @notice Mapping from portfolio ID to Portfolio structure.
    mapping(uint256 => Portfolio) public portfolios;

    /// @notice Emitted when a new portfolio is added.
    /// @param portfolioId The ID of the newly added portfolio.
    /// @param portfolioTokens The tokens included in the portfolio.
    event PortfolioAdded(uint256 indexed portfolioId, TokenShare[] portfolioTokens);

    /// @notice Emitted when an existing portfolio is updated.
    /// @param portfolioId The ID of the updated portfolio.
    /// @param portfolioTokens The updated tokens in the portfolio.
    event PortfolioUpdated(uint256 indexed portfolioId, TokenShare[] portfolioTokens);

    /// @notice Emitted when a portfolio is removed.
    /// @param portfolioId The ID of the removed portfolio.
    event PortfolioRemoved(uint256 indexed portfolioId);

    /// @notice Emitted when a portfolio is enabled.
    /// @param portfolioId The ID of the enabled portfolio.
    event PortfolioEnabled(uint256 indexed portfolioId);

    /// @notice Emitted when a portfolio is disabled.
    /// @param portfolioId The ID of the disabled portfolio.
    event PortfolioDisabled(uint256 indexed portfolioId);

    /// @notice Constructor for the PortfolioManager contract.
    /// @param _admin The address of the admin.
    /// @param _biscuit The address of the BiscuitV1 contract.
    constructor(address _admin, address _biscuit) {
        _checkIsContract(_biscuit);
        BISCUIT = BiscuitV1(payable(_biscuit));

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PORTFOLIO_MANAGER_ROLE, _admin);
    }

    /// @notice Adds multiple portfolios.
    /// @param _portfolios The list of portfolios to add.
    function addPortfolios(TokenShare[][] memory _portfolios) external onlyRole(PORTFOLIO_MANAGER_ROLE) {
        for (uint256 i = 0; i < _portfolios.length; i++) {
            addPortfolio(_portfolios[i]);
        }
    }

    /// @notice Adds a single portfolio.
    /// @dev Revert if total share tokens is not equal to MAX_BIPS.
    /// @dev Revert if at least one token does not have a pool on uniswap.
    /// @param _portfolio The portfolio to add.
    function addPortfolio(TokenShare[] memory _portfolio) public onlyRole(PORTFOLIO_MANAGER_ROLE) {
        nextPortfolioId++;
        _checkPortfolioTokens(_portfolio);
        _addPortfolio(nextPortfolioId, _portfolio);
        emit PortfolioAdded(nextPortfolioId, _portfolio);
    }

    /// @notice Removes multiple portfolios.
    /// @param _portfolioIds The list of portfolio IDs to remove.
    function removePortfolios(uint256[] memory _portfolioIds) external onlyRole(PORTFOLIO_MANAGER_ROLE) {
        for (uint256 i = 0; i < _portfolioIds.length; i++) {
            removePortfolio(_portfolioIds[i]);
        }
    }

    /// @notice Removes a single portfolio.
    /// @dev Revert if the ID portfolio does not exist.
    /// @param _portfolioId The ID of the portfolio to remove.
    function removePortfolio(uint256 _portfolioId) public onlyRole(PORTFOLIO_MANAGER_ROLE) {
        if (portfolios[_portfolioId].tokens.length == 0) revert PortfolioDoesNotExist();

        delete portfolios[_portfolioId];
        emit PortfolioRemoved(_portfolioId);
    }

    /// @notice Enables a portfolio.
    /// @dev Revert if the ID portfolio already enable or does not exist.
    /// @param _portfolioId The ID of the portfolio to enable.
    function enablePortfolio(uint256 _portfolioId) external onlyRole(PORTFOLIO_MANAGER_ROLE) {
        if (portfolios[_portfolioId].tokens.length == 0) revert PortfolioDoesNotExist();
        if (portfolios[_portfolioId].enabled) revert PortfolioAlreadyEnabled();

        portfolios[_portfolioId].enabled = true;
        emit PortfolioEnabled(_portfolioId);
    }

    /// @notice Disables a portfolio.
    /// @dev Revert if the ID portfolio already disable or does not exist.
    /// @param _portfolioId The ID of the portfolio to disable.
    function disablePortfolio(uint256 _portfolioId) external onlyRole(PORTFOLIO_MANAGER_ROLE) {
        if (portfolios[_portfolioId].tokens.length == 0) revert PortfolioDoesNotExist();
        if (!portfolios[_portfolioId].enabled) revert PortfolioAlreadyDisabled();

        portfolios[_portfolioId].enabled = false;
        emit PortfolioDisabled(_portfolioId);
    }

    /// @notice Checks if a pool exists for a given token.
    /// @param _token The address of the token to check.
    /// @return bool indicating whether the pool exists.
    function checkPoolsToTokenExist(address _token) public view returns (bool) {
        IUniswapV3Factory factory = BISCUIT.UNISWAP_FACTORY();
        address token = address(BISCUIT.PURCHASE_TOKEN());
        uint24 poolFee = BISCUIT.DEFAULT_POOL_FEE();

        address pool = factory.getPool(token, _token, poolFee);
        return pool != address(0);
    }

    /// @notice Gets the details of a portfolio.
    /// @param _portfolioId The ID of the portfolio to retrieve.
    /// @return Portfolio structure containing the portfolio details.
    function getPortfolio(uint256 _portfolioId) external view returns (Portfolio memory) {
        return portfolios[_portfolioId];
    }

    /// @notice Gets the number of tokens in a portfolio.
    /// @param _portfolioId The ID of the portfolio.
    /// @return uint256 indicating the number of tokens in the portfolio.
    function getPortfolioTokenCount(uint256 _portfolioId) external view returns (uint256) {
        return portfolios[_portfolioId].tokens.length;
    }

    /// @notice Adds a portfolio to the mapping.
    /// @param _portfolioId The ID of the portfolio to add.
    /// @param _portfolio The portfolio to add.
    function _addPortfolio(uint256 _portfolioId, TokenShare[] memory _portfolio) private {
        portfolios[_portfolioId].enabled = true;
        for (uint256 i = 0; i < _portfolio.length; i++) {
            portfolios[_portfolioId].tokens.push(_portfolio[i]);
        }
    }

    /// @notice Checks the validity of portfolio tokens.
    /// @param _tokens The tokens to check.
    function _checkPortfolioTokens(TokenShare[] memory _tokens) private view {
        uint256 MAX_BIPS = BISCUIT.MAX_BIPS();

        uint256 totalShares = 0;
        for (uint256 i = 0; i < _tokens.length; i++) {
            TokenShare memory portfolioToken = _tokens[i];
            if (!checkPoolsToTokenExist(portfolioToken.token)) {
                revert TokenDoesNotExist(portfolioToken.token);
            }
            totalShares += portfolioToken.share;
        }
        if (totalShares != MAX_BIPS) {
            revert IncorrectTotalShares(totalShares);
        }
    }

    /// @notice Checks if an address is a contract.
    /// @param _address The address to check.
    function _checkIsContract(address _address) private view {
        if (!(_address.code.length > 0)) {
            revert NotContract(_address);
        }
    }
}

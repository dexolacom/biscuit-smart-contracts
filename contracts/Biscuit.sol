// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @notice Error indicating that the provided arrays have mismatched lengths.
error ArrayMismatch();
/// @notice Error indicating that no actions were provided.
error MustProvideActions();
/// @notice Error indicating that too many operations were provided.
error TooManyOperations();
/// @notice Error indicating that a transaction execution reverted.
error TransactionExecutionReverted();
/// @notice Error indicating that the caller is not approved or the owner.
error NotApprovedOrOwner();

/// @title Biscuit NFT Contract
/// @notice This contract allows minting and burning of NFTs with custom actions on mint and burn.
/// @dev Inherits from OpenZeppelin's ERC721 implementation.
contract Biscuit is ERC721 {
    /// @notice Parameters required for minting a new token.
    /// @param to The address that will receive the minted token.
    /// @param targets The array of target addresses for executing transactions during minting.
    /// @param values The array of values (ETH) to send with each transaction during minting.
    /// @param signatures The array of function signatures for the transactions during minting. It can be swap and unstaking.
    /// @param calldatas The array of calldata for the transactions during minting (parameters for functions).
    struct MintParams {
        address to;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
    }

    /// @notice Parameters required for burning a token.
    /// @param targets The array of target addresses for executing transactions during burning.
    /// @param values The array of values (ETH) to send with each transaction during burning.
    /// @param signatures The array of function signatures for the transactions during burning. It can be swap and unstaking.
    /// @param calldatas The array of calldata for the transactions during burning (parameters for functions).
    struct BurnParams {
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
    }

    /// @notice Maximum number of operations allowed in a single transaction.
    uint256 public constant MAX_OPERATIONS = 12;
    /// @notice The current token ID to be minted next.
    uint256 public tokenId;

    /// @notice Mapping from token ID to burn parameters.
    mapping(uint256 => BurnParams) burnParamsByTokenId;

    /// @notice Initializes the contract with a name and a symbol.
    constructor() ERC721("Biscuit", "BSC") {}

    /// @notice Mints a new token, executes specified actions, and sets up future burn actions.
    /// @notice Actions can include operations such as staking, swapping, or interacting with other contracts.
    /// @dev This function increments the tokenId, mints a new ERC721 token to the specified address, stores the burn parameters, and executes a series of transactions.
    /// @param mintParams Parameters for minting a new token (see `MintParams` struct for details).
    /// @param burnParams Parameters for burning the token in the future (see `BurnParams` struct for details).
    /// @return data Array of return data from the executed transactions during minting.
    function mint(
        MintParams memory mintParams,
        BurnParams memory burnParams
    ) external payable returns (bytes[] memory) {
        tokenId++;
        _safeMint(mintParams.to, tokenId);

        burnParamsByTokenId[tokenId] = burnParams;
        bytes[] memory data = _execute(
            mintParams.targets,
            mintParams.values,
            mintParams.signatures,
            mintParams.calldatas
        );

        return data;
    }

    /// @notice Burns an existing token and executes specified actions.
    /// @notice Actions can include operations such as unstaking, swapping, or interacting with other contracts.
    /// @dev This function checks if the caller is authorized, burns the token, and executes a series of transactions stored in the burn parameters.
    /// @param _tokenId The ID of the token to be burned.
    /// @return data Array of return data from the executed transactions during burning.
    function burn(uint256 _tokenId) external payable returns (bytes[] memory) {
        if (!_isAuthorized(_ownerOf(_tokenId), msg.sender, _tokenId)) {
            revert NotApprovedOrOwner();
        }
        _burn(_tokenId);

        BurnParams memory burnParams = burnParamsByTokenId[_tokenId];
        bytes[] memory data = _execute(
            burnParams.targets,
            burnParams.values,
            burnParams.signatures,
            burnParams.calldatas
        );

        return data;
    }

    /// @notice Updates the burn parameters for a specific token.
    /// @notice This allows the owner or an approved operator to change the actions that will be executed when the token is burned.
    /// @dev This function checks if the caller is authorized, then updates the burn parameters stored for the specified token.
    /// @param _tokenId The ID of the token whose burn parameters are being updated.
    /// @param newBurnParams The new burn parameters (see `BurnParams` struct for details).
    function updateBurnParams(
        uint256 _tokenId,
        BurnParams memory newBurnParams
    ) external {
        if (!_isAuthorized(ownerOf(_tokenId), msg.sender, _tokenId)) {
            revert NotApprovedOrOwner();
        }
        burnParamsByTokenId[_tokenId] = newBurnParams;
    }

    /// @notice Executes a series of transactions.
    /// @dev This private function performs the specified transactions, and returns the resulting data.
    /// @param targets array of target addresses for executing transactions.
    /// @param values array of ETH values to send with each transaction.
    /// @param signatures array of function signatures for the transactions.
    /// @param calldatas array of calldatas for the transactions.
    /// @return returnDataArray Array of return data from the executed transactions.
    function _execute(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) private returns (bytes[] memory) {
        if (
            targets.length != values.length ||
            targets.length != signatures.length ||
            targets.length != calldatas.length
        ) {
            revert ArrayMismatch();
        }
        if (targets.length == 0) {
            revert MustProvideActions();
        }
        if (targets.length > MAX_OPERATIONS) {
            revert TooManyOperations();
        }

        bytes[] memory returnDataArray = new bytes[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            returnDataArray[i] = _executeTransaction(
                targets[i],
                values[i],
                signatures[i],
                calldatas[i]
            );
        }

        return returnDataArray;
    }

    /// @notice Executes a transaction with the specified target, value, function signature, and calldata.
    /// @dev This private function encodes the function call data, executes the transaction, and returns the resulting data.
    /// @param _target The address of the contract to call.
    /// @param _value The amount of ETH to send with the transaction.
    /// @param _signature The function signature of the method to call (if empty, direct call with provided calldata).
    /// @param _calldata The calldata containing the function parameters.
    /// @return returnData The return data from the executed transaction.
    function _executeTransaction(
        address _target,
        uint256 _value,
        string memory _signature,
        bytes memory _calldata
    ) private returns (bytes memory) {
        bytes memory callData;
        if (bytes(_signature).length == 0) {
            callData = _calldata;
        } else {
            callData = abi.encodePacked(
                bytes4(keccak256(bytes(_signature))),
                _calldata
            );
        }

        (bool success, bytes memory returnData) = _target.call{value: _value}(
            callData
        );
        if (!success) revert TransactionExecutionReverted();

        return returnData;
    }
}

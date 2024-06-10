// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

error ArrayMismatch();
error MustProvideActions();
error TooManyOperations();
error TransactionExecutionReverted();
error ActionNotAllowed();
error NotApprovedOrOwner();

contract Biscuit is ERC721 {
    struct MintParams {
        address to;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
    }

    struct BurnParams {
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
    }

    uint256 public constant MAX_OPERATIONS = 12;
    uint256 public tokenId;

    mapping(uint256 => BurnParams) burnParamsByTokenId;

    constructor() ERC721("Biscuit", "BSC") {}

    function mint(MintParams memory mintParams, BurnParams memory burnParams) external payable returns (bytes[] memory) {
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

    function updateBurnParams(uint256 _tokenId, BurnParams memory newBurnParams) external {
        if (!_isAuthorized(ownerOf(_tokenId), msg.sender, _tokenId)) {
            revert NotApprovedOrOwner();
        }
        burnParamsByTokenId[_tokenId] = newBurnParams;
    }

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

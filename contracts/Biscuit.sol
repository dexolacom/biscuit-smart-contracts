// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

error ArrayMismatch();
error MustProvideActions();
error TooManyActions();
error TransactionExecutionReverted();
error ActionNotAllowed();
error NotApprovedOrOwner();

contract Biscuit is ERC721, AccessControl {
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR");

    uint256 public tokenId;

    struct MintParams {
        address to;
        address[] targets;
        uint[] values;
        string[] signatures;
        bytes[] calldatas;
    }

    struct BurnParams {
        uint256 tokenId;
        address[] targets;
        uint[] values;
        string[] signatures;
        bytes[] calldatas;
    }

    constructor(address _admin, address _executor) ERC721("Biscuit", "BSC") {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(EXECUTOR_ROLE, _executor);
    }

    function mint(MintParams memory mintParams) external {
        tokenId++;
        _safeMint(mintParams.to, tokenId);
        execute(
            mintParams.targets,
            mintParams.values,
            mintParams.signatures,
            mintParams.calldatas
        );
    }

    function burn(BurnParams memory burnParams) external {
        if (!_isAuthorized(_ownerOf(burnParams.tokenId), msg.sender, burnParams.tokenId)) {
            revert NotApprovedOrOwner();
        }

        _burn(burnParams.tokenId);
        execute(
            burnParams.targets,
            burnParams.values,
            burnParams.signatures,
            burnParams.calldatas
        );
    }

    function execute(
        address[] memory targets,
        uint[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) public payable returns (bytes[] memory) {
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
        if (targets.length > proposalMaxOperations()) {
            revert TooManyActions();
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

    function proposalMaxOperations() public pure returns (uint256) {
        return 10;
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

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

error ArrayMismatch();
error MustProvideActions();
error TooManyActions();
error ProposalAlreadyExecuted();
error TransactionExecutionReverted();
error ActionNotAllowed();

contract Biscuit is ERC721, AccessControl {
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR");

    uint256 public tokenId;
    uint256 public proposalId;
    bool public swapExecuted;

    struct Proposal {
        uint id;
        address proposer;
        address[] targets;
        uint[] values;
        string[] signatures;
        bytes[] calldatas;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;

    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas
    );
    event ProposalExecuted(uint256 id);

    modifier onlyDuringExecutionAndSwap() {
        if (msg.sender != address(this) || !swapExecuted) {
            revert ActionNotAllowed();
        }
        _;
    }

    constructor(address _admin, address _executor) ERC721("Biscuit", "BSC") {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(EXECUTOR_ROLE, _executor);
    }

    function mint(address _to) external onlyDuringExecutionAndSwap {
        tokenId++;
        _safeMint(_to, tokenId);
    }

    function burn(uint256 _tokenId) external onlyDuringExecutionAndSwap {
        _burn(_tokenId);
    }

    function propose(
        address[] memory targets,
        uint[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) public onlyRole(EXECUTOR_ROLE) returns (uint256) {
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

        Proposal memory newProposal = Proposal({
            id: proposalId,
            proposer: msg.sender,
            targets: targets,
            values: values,
            signatures: signatures,
            calldatas: calldatas,
            executed: false
        });

        proposalId++;
        proposals[proposalId] = newProposal;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas
        );
        return proposalId;
    }

    function execute(
        uint256 _proposalId
    ) public payable onlyRole(EXECUTOR_ROLE) returns (bytes[] memory) {
        Proposal storage proposal = proposals[_proposalId];
        if (proposal.executed) revert ProposalAlreadyExecuted();

        swapExecuted = false;
        proposal.executed = true;
        bytes[] memory returnDataArray = new bytes[](proposal.targets.length);
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            returnDataArray[i] = _executeTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i]
            );
        }

        emit ProposalExecuted(_proposalId);
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

        // example discovered swap function
        if (keccak256(bytes(_signature)) == keccak256("swap()")) {
            swapExecuted = true;
        }

        return returnData;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

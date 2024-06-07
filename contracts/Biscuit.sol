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

    modifier onlyDuringExecution() {
        if (msg.sender != address(this)) revert ActionNotAllowed();
        _;
    }

    constructor(address _admin, address _executor) ERC721("Biscuit", "BSC") {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(EXECUTOR_ROLE, _executor);
    }

    function mint(address _to) external onlyDuringExecution {
        tokenId++;
        _safeMint(_to, tokenId);
    }

    function burn(uint256 _tokenId) external onlyDuringExecution {
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

        proposal.executed = true;
        bytes[] memory returnDataArray = new bytes[](proposal.targets.length);
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            bytes memory callData;
            if (bytes(proposal.signatures[i]).length == 0) {
                callData = proposal.calldatas[i];
            } else {
                callData = abi.encodePacked(
                    bytes4(keccak256(bytes(proposal.signatures[i]))),
                    proposal.calldatas[i]
                );
            }

            (bool success, bytes memory returnData) = proposal.targets[i].call{
                value: proposal.values[i]
            }(callData);
            if (!success) revert TransactionExecutionReverted();

            returnDataArray[i] = returnData;
        }

        emit ProposalExecuted(_proposalId);
        return returnDataArray;
    }

    function proposalMaxOperations() public pure returns (uint256) {
        return 10;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

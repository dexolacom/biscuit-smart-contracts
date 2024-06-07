// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

error ArrayMismatch();
error MustProvideActions();
error TooManyActions();

contract Biscuit is ERC721 {
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

    constructor() ERC721("Biscuit", "BSC") {}

    function mint(address to) external {
        tokenId++;
        _safeMint(to, tokenId);
    }

    function burn(uint256 _tokenId) external {
        _burn(_tokenId);
    }

    function propose(
        address[] memory targets,
        uint[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas
    ) public returns (uint256) {
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

    function proposalMaxOperations() public pure returns (uint256) {
        return 10;
    }
}

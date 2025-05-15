// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./AgroChainGovernance.sol";

/// @title ConcreteAgroChainGovernance
/// @dev Implementação concreta do sistema de governança AgroChain
contract ConcreteAgroChainGovernance is AgroChainGovernance {
    // Mapping interno que registra se um address já votou em uma proposta
    mapping(uint256 => mapping(address => bool)) private _hasVoted;

    /// @notice Retorna se `voter` já votou na proposta `proposalId`
    function hasVoted(uint256 proposalId, address voter)
        external
        view
        override
        returns (bool)
    {
        return _hasVoted[proposalId][voter];
    }

    /**
     * @dev Exemplo de hook interno: quando alguém votar, registre no mapping.
     *     Você deve chamar isso de dentro do seu castVote original em AgroChainGovernance.
     */
    function _recordVote(uint256 proposalId, address voter) internal {
        _hasVoted[proposalId][voter] = true;
    }

    // Se o seu AgroChainGovernance original dispara algum evento ou chama um hook,
    // você pode sobrescrever castVote para chamar `_recordVote`:
    //
    // function castVote(uint256 proposalId, bool support) public override {
    //     super.castVote(proposalId, support);
    //     _recordVote(proposalId, msg.sender);
    // }

    /// @notice Verifica se uma proposta está pronta para execução
    function isProposalReadyForExecution(uint256 proposalId)
        external
        view
        returns (bool isReady)
    {
        (
            , , , , uint256 votingEndsAt, bool executed, bool canceled, , , string memory status
        ) = this.getProposalDetails(proposalId);

        return (
            !executed &&
            !canceled &&
            block.timestamp > votingEndsAt &&
            keccak256(bytes(status)) == keccak256(bytes("Ready for execution"))
        );
    }

    /// @notice Estatísticas de governança
    function getGovernanceStats()
        external
        view
        returns (
            uint256 totalProposals,
            uint256 activeProposals,
            uint256 executedProposals
        )
    {
        totalProposals = this.getProposalCount();
        uint256 active;
        uint256 executed;

        for (uint256 i = 1; i <= totalProposals; i++) {
            if (this.isProposalActive(i)) {
                active++;
            }
            (, , , , , bool isExecuted, , , , ) = this.getProposalDetails(i);
            if (isExecuted) {
                executed++;
            }
        }

        return (totalProposals, active, executed);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAgroChainGovernance
 * @dev Interface for the governance system
 */
interface IAgroChainGovernance {
    // Proposal structure
    struct Proposal {
        uint256 id;                         // Unique proposal ID
        address proposer;                   // Address that created the proposal
        string title;                       // Short title
        string description;                 // Detailed description
        bytes callData;                     // Call data for execution
        address targetContract;             // Contract to execute call on
        uint256 value;                      // ETH value for call
        uint256 createdAt;                  // Creation timestamp
        uint256 votingEndsAt;               // End of voting period
        uint256 executionDelay;             // Delay between approval and execution
        bool executed;                      // Whether proposal was executed
        bool canceled;                      // Whether proposal was canceled
        uint256 forVotes;                   // Votes in favor
        uint256 againstVotes;               // Votes against
        mapping(address => bool) hasVoted;  // Track who has voted
    }
    
    // Events
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event VotingParametersUpdated(uint256 votingPeriod, uint256 executionDelay, uint256 quorum);
    
    /**
     * @dev Create a new governance proposal
     * @param title Short title of the proposal
     * @param description Detailed description
     * @param targetContract Address of contract to call
     * @param value ETH value to send with call
     * @param callData Encoded function call 
     * @return proposalId ID of the created proposal
     */
    function createProposal(
        string calldata title,
        string calldata description,
        address targetContract,
        uint256 value,
        bytes calldata callData
    ) external returns (uint256 proposalId);
    
    /**
     * @dev Cast vote on a proposal
     * @param proposalId ID of the proposal
     * @param support Whether to support the proposal
     */
    function castVote(uint256 proposalId, bool support) external;
    
    /**
     * @dev Execute an approved proposal
     * @param proposalId ID of the proposal
     */
    function executeProposal(uint256 proposalId) external returns (bool success);
    
    /**
     * @dev Cancel a proposal
     * @param proposalId ID of the proposal
     */
    function cancelProposal(uint256 proposalId) external;
    
    /**
     * @dev Get proposal details
     * @param proposalId ID of the proposal
     * @return title Title of the proposal
     * @return description Description of the proposal
     * @return proposer Address that created the proposal
     * @return createdAt Creation timestamp
     * @return votingEndsAt End of voting period
     * @return executed Whether proposal was executed
     * @return canceled Whether proposal was canceled
     * @return forVotes Number of votes in favor
     * @return againstVotes Number of votes against
     * @return status Current status of the proposal
     */
    function getProposalDetails(uint256 proposalId) external view returns (
        string memory title,
        string memory description,
        address proposer,
        uint256 createdAt,
        uint256 votingEndsAt,
        bool executed,
        bool canceled,
        uint256 forVotes,
        uint256 againstVotes,
        string memory status
    );
    
    /**
     * @dev Check if a proposal is active
     * @param proposalId ID of the proposal
     * @return active Whether the proposal is active
     */
    function isProposalActive(uint256 proposalId) external view returns (bool active);
    
    /**
     * @dev Check if a user has already voted on a proposal
     * @param proposalId ID of the proposal
     * @param voter Address of the voter
     * @return hasVoted Whether the user has voted
     */
    function hasVoted(uint256 proposalId, address voter) external view returns (bool hasVoted);
}
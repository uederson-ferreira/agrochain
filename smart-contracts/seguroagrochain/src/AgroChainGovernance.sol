// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IAgroChainGovernance.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @title AgroChainGovernance
 * @dev Implementation of the governance system
 * @notice Allows stakeholders to create proposals and vote on system changes
 */
abstract contract AgroChainGovernance is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable,
    IAgroChainGovernance 
{
    // Custom errors
    error ProposalNotFound();
    error ProposalAlreadyExecuted();
    error ProposalIsCanceled();
    error VotingPeriodNotEnded();
    error VotingPeriodEnded();
    error AlreadyVoted();
    error NotEnoughVotingPower();
    error QuorumNotReached();
    error ProposalRejected();
    error ExecutionFailed();
    error NotProposer();
    error InvalidProposalParameters();
    error TimelockNotElapsed();
    error ExecutionNotAllowed();
    
    // Version tracking
    string private _version;
    
    // Governance token (for vote weighting)
    IERC20Upgradeable private _governanceToken;
    
    // Proposal counter
    uint256 private _proposalCount;
    
    // Governance parameters
    uint256 private _votingPeriod;        // Duration of voting in seconds
    uint256 private _executionDelay;      // Timelock between approval and execution
    uint256 private _quorumThreshold;     // Minimum votes for proposal to pass (basis points of total supply)
    uint256 private _proposalThreshold;   // Min tokens required to create proposal
    
    // Mapping from proposal ID to proposal
    mapping(uint256 => Proposal) private _proposals;
    
    // Addresses allowed to execute proposals (multisig security option)
    mapping(address => bool) private _executors;
    
    /**
     * @dev Modifier to check if proposal exists
     */
    modifier proposalExists(uint256 proposalId) {
        if (proposalId == 0 || proposalId > _proposalCount) revert ProposalNotFound();
        _;
    }
    
    /**
     * @dev Modifier to check if caller is allowed to execute proposals
     */
    modifier onlyExecutor() {
        require(msg.sender == owner() || _executors[msg.sender], "Not authorized to execute");
        _;
    }
    
    /**
     * @dev Initialize function
     */
    function initialize(
        address governanceToken,
        uint256 votingPeriod,
        uint256 executionDelay,
        uint256 quorumThreshold,
        uint256 proposalThreshold
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        
        _version = "1.0.0";
        
        // Set governance token
        _governanceToken = IERC20Upgradeable(governanceToken);
        
        // Set governance parameters with validation
        require(votingPeriod > 0, "Voting period must be positive");
        require(quorumThreshold > 0 && quorumThreshold <= 10000, "Invalid quorum threshold");
        require(proposalThreshold > 0, "Proposal threshold must be positive");
        
        _votingPeriod = votingPeriod;
        _executionDelay = executionDelay;
        _quorumThreshold = quorumThreshold;
        _proposalThreshold = proposalThreshold;
        
        // Set deployer as initial executor
        _executors[msg.sender] = true;
    }
    
    /**
     * @dev Create a new governance proposal
     */
    function createProposal(
        string calldata title,
        string calldata description,
        address targetContract,
        uint256 value,
        bytes calldata callData
    ) 
        external 
        override 
        whenNotPaused 
        nonReentrant 
        returns (uint256 proposalId) 
    {
        // Check proposal parameters
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(targetContract != address(0), "Invalid target contract");
        require(callData.length > 0, "Call data cannot be empty");
        
        // Check proposer has enough tokens
        uint256 proposerBalance = _governanceToken.balanceOf(msg.sender);
        if (proposerBalance < _proposalThreshold) revert NotEnoughVotingPower();
        
        // Create new proposal ID
        proposalId = ++_proposalCount;
        
        // Create proposal
        Proposal storage proposal = _proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.title = title;
        proposal.description = description;
        proposal.callData = callData;
        proposal.targetContract = targetContract;
        proposal.value = value;
        proposal.createdAt = block.timestamp;
        proposal.votingEndsAt = block.timestamp + _votingPeriod;
        proposal.executionDelay = _executionDelay;
        proposal.executed = false;
        proposal.canceled = false;
        proposal.forVotes = 0;
        proposal.againstVotes = 0;
        
        emit ProposalCreated(proposalId, msg.sender, title);
        
        return proposalId;
    }
    
    /**
     * @dev Cast vote on a proposal
     */
    function castVote(uint256 proposalId, bool support) 
        external 
        whenNotPaused 
        proposalExists(proposalId) 
        nonReentrant 
    {
        Proposal storage proposal = _proposals[proposalId];
        
        // Check proposal is active
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.canceled) revert ProposalIsCanceled();
        if (block.timestamp > proposal.votingEndsAt) revert VotingPeriodEnded();
        
        // Check voter hasn't already voted
        if (proposal.hasVoted[msg.sender]) revert AlreadyVoted();
        
        // Calculate voting weight (token balance)
        uint256 votes = _governanceToken.balanceOf(msg.sender);
        if (votes == 0) revert NotEnoughVotingPower();
        
        // Record vote
        proposal.hasVoted[msg.sender] = true;
        
        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }
        
        emit VoteCast(proposalId, msg.sender, support, votes);
    }
    
    /**
     * @dev Execute an approved proposal
     */
    function executeProposal(uint256 proposalId) 
        external 
        override 
        whenNotPaused 
        proposalExists(proposalId) 
        onlyExecutor 
        nonReentrant 
        returns (bool success) 
    {
        Proposal storage proposal = _proposals[proposalId];
        
        // Check proposal can be executed
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.canceled) revert ProposalIsCanceled();
        if (block.timestamp <= proposal.votingEndsAt) revert VotingPeriodNotEnded();
        
        // Check proposal passed
        if (!_hasProposalPassed(proposalId)) revert ProposalRejected();
        
        // Check timelock has elapsed
        if (block.timestamp < proposal.votingEndsAt + proposal.executionDelay) revert TimelockNotElapsed();
        
        // Mark as executed
        proposal.executed = true;
        
        // Execute proposal
        (bool result, ) = proposal.targetContract.call{value: proposal.value}(proposal.callData);
        if (!result) revert ExecutionFailed();
        
        emit ProposalExecuted(proposalId);
        
        return true;
    }
    
    /**
     * @dev Cancel a proposal
     */
    function cancelProposal(uint256 proposalId) 
        external 
        whenNotPaused 
        proposalExists(proposalId) 
        nonReentrant 
    {
        Proposal storage proposal = _proposals[proposalId];
        
        // Check proposal can be canceled
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.canceled) revert ProposalIsCanceled();
        
        // Only proposer or admin can cancel
        if (msg.sender != proposal.proposer && msg.sender != owner()) revert NotProposer();
        
        // If not admin, check proposer still has enough tokens
        if (msg.sender == proposal.proposer) {
            uint256 proposerBalance = _governanceToken.balanceOf(msg.sender);
            if (proposerBalance < _proposalThreshold) revert NotEnoughVotingPower();
        }
        
        // Mark as canceled
        proposal.canceled = true;
        
        emit ProposalCanceled(proposalId);
    }
    
    /**
     * @dev Get proposal details
     */
    function getProposalDetails(uint256 proposalId) 
        external 
        view 
        override 
        proposalExists(proposalId) 
        returns (
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
        ) 
    {
        Proposal storage proposal = _proposals[proposalId];
        
        // Determine current status
        string memory proposalStatus;
        if (proposal.executed) {
            proposalStatus = "Executed";
        } else if (proposal.canceled) {
            proposalStatus = "Canceled";
        } else if (block.timestamp <= proposal.votingEndsAt) {
            proposalStatus = "Active";
        } else if (_hasProposalPassed(proposalId)) {
            if (block.timestamp < proposal.votingEndsAt + proposal.executionDelay) {
                proposalStatus = "Approved (in timelock)";
            } else {
                proposalStatus = "Ready for execution";
            }
        } else {
            proposalStatus = "Rejected";
        }
        
        return (
            proposal.title,
            proposal.description,
            proposal.proposer,
            proposal.createdAt,
            proposal.votingEndsAt,
            proposal.executed,
            proposal.canceled,
            proposal.forVotes,
            proposal.againstVotes,
            proposalStatus
        );
    }
    
    /**
     * @dev Check if a proposal is active
     */
    function isProposalActive(uint256 proposalId) 
        external 
        view 
        override 
        proposalExists(proposalId) 
        returns (bool active) 
    {
        Proposal storage proposal = _proposals[proposalId];
        
        return (
            !proposal.executed &&
            !proposal.canceled &&
            block.timestamp <= proposal.votingEndsAt
        );
    }
    
    /**
     * @dev Check if a user has already voted on a proposal
     */
    function hasUserVoted(uint256 proposalId, address voter) 
        external 
        view 
        proposalExists(proposalId) 
        returns (bool hasVoted) 
    {
        return _proposals[proposalId].hasVoted[voter];
    }
    
    /**
     * @dev Check if a proposal has passed
     */
    function _hasProposalPassed(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = _proposals[proposalId];
        
        // Calculate total votes cast
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        
        // Check quorum
        uint256 totalSupply = _governanceToken.totalSupply();
        uint256 minVotesRequired = (totalSupply * _quorumThreshold) / 10000;
        
        if (totalVotes < minVotesRequired) {
            return false; // Quorum not reached
        }
        
        // Check majority
        return proposal.forVotes > proposal.againstVotes;
    }
    
    /**
     * @dev Get governance parameters
     */
    function getGovernanceParameters() external view returns (
        uint256 votingPeriod,
        uint256 executionDelay,
        uint256 quorumThreshold,
        uint256 proposalThreshold,
        address governanceToken
    ) {
        return (
            _votingPeriod,
            _executionDelay,
            _quorumThreshold,
            _proposalThreshold,
            address(_governanceToken)
        );
    }
    
    /**
     * @dev Get total proposals count
     */
    function getProposalCount() external view returns (uint256) {
        return _proposalCount;
    }
    
    /**
     * @dev Check if an address is allowed to execute proposals
     */
    function isExecutor(address account) external view returns (bool) {
        return _executors[account];
    }
    
    // ======== Admin Functions ========
    
    /**
     * @dev Update governance parameters
     */
    function updateGovernanceParameters(
        uint256 votingPeriod,
        uint256 executionDelay,
        uint256 quorumThreshold,
        uint256 proposalThreshold
    ) external onlyOwner {
        require(votingPeriod > 0, "Voting period must be positive");
        require(quorumThreshold > 0 && quorumThreshold <= 10000, "Invalid quorum threshold");
        require(proposalThreshold > 0, "Proposal threshold must be positive");
        
        _votingPeriod = votingPeriod;
        _executionDelay = executionDelay;
        _quorumThreshold = quorumThreshold;
        _proposalThreshold = proposalThreshold;
        
        emit VotingParametersUpdated(votingPeriod, executionDelay, quorumThreshold);
    }
    
    /**
     * @dev Update governance token
     */
    function updateGovernanceToken(address newToken) external onlyOwner {
        require(newToken != address(0), "Invalid token address");
        _governanceToken = IERC20Upgradeable(newToken);
    }
    
    /**
     * @dev Add executor
     */
    function addExecutor(address executor) external onlyOwner {
        require(executor != address(0), "Invalid executor address");
        _executors[executor] = true;
    }
    
    /**
     * @dev Remove executor
     */
    function removeExecutor(address executor) external onlyOwner {
        _executors[executor] = false;
    }
    
    /**
     * @dev Pause contract in emergency
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Get contract version
     */
    function getVersion() external view returns (string memory) {
        return _version;
    }
    
    /**
     * @dev Function to receive ETH (required for executing proposals with value)
     */
    receive() external payable {}
}
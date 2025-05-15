// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAgroChainOracle
 * @dev Interface for climate data oracle integration
 */
interface IAgroChainOracle {
    /**
     * @dev Structure for oracle request details
     */
    struct OracleRequest {
        uint256 policyId;           // ID of the policy
        string parameterType;        // Type of climate parameter
        string region;               // Geographic region
        uint256 timestamp;           // Request timestamp
        address requester;           // Address that made the request
        address[] dataProviders;     // Addresses of data providers
        bool fulfilled;              // Whether request has been fulfilled
        mapping(address => bool) validations; // Track which providers have responded
        uint256 responseCount;       // Number of responses received
        uint256 aggregatedValue;     // Final aggregated value
    }
    
    // Events
    event DataRequested(bytes32 indexed requestId, uint256 indexed policyId, string parameterType);
    event DataProviderResponse(bytes32 indexed requestId, address provider, uint256 value);
    event DataFulfilled(bytes32 indexed requestId, uint256 value);
    
    /**
     * @dev Request climate data from oracles
     * @param policyId ID of the insurance policy
     * @param parameterType Type of climate parameter requested
     * @param region Geographic region for the data
     * @param dataProviders List of oracle addresses to request data from
     * @return requestId Unique ID for tracking the oracle request
     */
    function requestClimateData(
        uint256 policyId,
        string calldata parameterType,
        string calldata region,
        address[] memory dataProviders
    ) external returns (bytes32 requestId);
    
    /**
     * @dev Submit data from a provider oracle
     * @param requestId ID of the request
     * @param value Climate data value
     */
    function submitOracleData(bytes32 requestId, uint256 value) external;
    
    /**
     * @dev Get the status of an oracle request
     * @param requestId ID of the request
     * @return fulfilled Whether the request has been fulfilled
     * @return value Aggregated value (if fulfilled)
     * @return responseCount Number of responses received
     */
    function getRequestStatus(bytes32 requestId) external view returns (
        bool fulfilled,
        uint256 value,
        uint256 responseCount
    );
}
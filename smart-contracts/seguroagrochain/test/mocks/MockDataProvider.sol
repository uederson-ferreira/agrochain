// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MockDataProvider
 * @dev Mock contract for testing AgroChainOracle
 */
contract MockDataProvider {
    // Track requests and responses
    mapping(bytes32 => uint256) public responses;
    mapping(bytes32 => bool) public hasResponded;
    
    // Last submitted data
    bytes32 public lastRequestId;
    uint256 public lastSubmittedValue;
    
    // Owner of the mock provider
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Submit data to the oracle
     * @param requestId The ID of the request
     * @param value The value to submit
     */
    function submitData(bytes32 requestId, uint256 value) external {
        require(msg.sender == owner, "Only owner can submit data");
        
        responses[requestId] = value;
        hasResponded[requestId] = true;
        
        lastRequestId = requestId;
        lastSubmittedValue = value;
    }
    
    /**
     * @dev Check if provider has responded to a request
     * @param requestId The request ID to check
     * @return True if responded, false otherwise
     */
    function hasRespondedToRequest(bytes32 requestId) external view returns (bool) {
        return hasResponded[requestId];
    }
    
    /**
     * @dev Get response for a request
     * @param requestId The request ID to get response for
     * @return The submitted value
     */
    function getResponse(bytes32 requestId) external view returns (uint256) {
        require(hasResponded[requestId], "No response for this request");
        return responses[requestId];
    }
    
    /**
     * @dev Transfer ownership of the mock provider
     * @param newOwner The new owner address
     */
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner, "Only owner can transfer ownership");
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}
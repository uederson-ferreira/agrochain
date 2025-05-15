// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MockOracle
 * @dev Mock contract for testing AgroChainInsurance
 */
contract MockOracle {
    uint256 public lastPolicyId;
    string public lastParameterType;
    string public lastRegion;
    address[] public lastProviders;
    
    function requestClimateData(
        uint256 policyId,
        string calldata parameterType,
        string calldata region,
        address[] memory dataProviders
    ) external returns (bytes32) {
        lastPolicyId = policyId;
        lastParameterType = parameterType;
        lastRegion = region;
        
        // Copy data providers
        delete lastProviders;
        for (uint256 i = 0; i < dataProviders.length; i++) {
            lastProviders.push(dataProviders[i]);
        }
        
        // Generate a deterministic request ID for testing
        return keccak256(abi.encodePacked(policyId, parameterType, region));
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interface for the AgroChainInsurance contract
interface IAgroChainInsurance {
    // Structs used in the interface
    struct Policy {
        uint256 id;
        address payable farmer;
        uint256 coverageAmount;
        uint256 premium;
        uint256 startDate;
        uint256 endDate;
        bool active;
        bool claimed;
        uint256 claimPaid;
        uint256 lastClaimDate;
        bytes32 policyDataHash;
        string region;
        string cropType;
    }

    struct ClimateParameter {
        string parameterType;
        uint256 thresholdValue;
        uint256 periodInDays;
        bool triggerAbove;
        uint256 payoutPercentage;
    }

      struct ClimateData {
        bytes32 requestId;          // ID da solicitação
        string parameterType;       // Tipo de parâmetro
        uint256 measuredValue;      // Valor medido
        uint256 timestamp;          // Momento da medição
        string dataSource;          // Fonte dos dados
        bytes signature;            // Assinatura para verificação
    }

    // Events emitted by the contract
    event PolicyCreated(uint256 indexed policyId, address indexed farmer, uint256 coverageAmount, string cropType);
    event PolicyActivated(uint256 indexed policyId, uint256 premium);
    event ClimateDataRequested(uint256 indexed policyId, bytes32 requestId, string parameterType);
    event ClaimTriggered(uint256 indexed policyId, address indexed farmer, uint256 payoutAmount);
    event PolicyExpired(uint256 indexed policyId);
    event PolicyCancelled(uint256 indexed policyId, uint256 refundAmount);

    // External functions that must be implemented
    function createPolicy(
        address payable _farmer,
        uint256 _coverageAmount,
        uint256 _startDate,
        uint256 _endDate,
        string calldata _region,
        string calldata _cropType,
        ClimateParameter[] calldata _parameters,
        string calldata zkProofHash
    ) external returns (uint256 policyId);

    function activatePolicy(uint256 _policyId) external payable;

    function requestClimateData(uint256 _policyId, string calldata _parameterType) external returns (bytes32);

    function processClaim(uint256 _policyId, ClimateData calldata _climateData) external returns (bool success, uint256 amount);

    function cancelPolicy(uint256 _policyId) external returns (uint256 refundAmount);

    function getPolicyDetails(uint256 _policyId) external view returns (Policy memory, ClimateParameter[] memory);

    function getPolicyStatus(uint256 _policyId) external view returns (
        bool active,
        bool claimed,
        uint256 claimPaid,
        uint256 remainingCoverage,
        uint256 timeRemaining
    );
}
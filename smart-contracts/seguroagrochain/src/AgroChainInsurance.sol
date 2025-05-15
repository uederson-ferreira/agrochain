// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IAgroChainInsurance.sol";
import "./IAgroChainGovernance.sol";
import "./IAgroChainOracle.sol";
import "./IAgroChainTreasury.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
 * @title AgroChainInsurance
 * @dev Implementation of the parametric insurance contract
 * @author AgroChain Team
 */
contract AgroChainInsurance is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable,
    IAgroChainInsurance 
{
    // Upgradeable storage must be careful about layout
    
    // Version tracking
    string private _version;
    
    // Core storage
    mapping(uint256 => Policy) private _policies;
    mapping(uint256 => ClimateParameter[]) private _policyParameters;
    mapping(bytes32 => uint256) private _requestIdToPolicyId;
    
    // Counters
    uint256 private _policyCounter;
    uint256 private _totalPremiumsCollected;
    uint256 private _totalClaimsPaid;
    
    // Connected contracts
    IAgroChainOracle private _oracle;
    IAgroChainTreasury private _treasury;
    IAgroChainGovernance private _governance;
    
    // System parameters
    uint256 private _minimumPremiumPercentage; // basis points (100 = 1%)
    uint256 private _cancellationFeePercentage; // basis points
    uint256 private _maxCoverageAmount;
    uint256 private _minCoverageAmount;
    
    // Whitelist for regions and crops
    mapping(string => bool) private _supportedRegions;
    mapping(string => bool) private _supportedCrops;
    
    // Weather station mapping
    mapping(string => address[]) private _regionalOracles;
    
    // Risk modeling
    mapping(string => mapping(string => uint256)) private _baseRiskScores; // region -> crop -> score
    
    /**
     * @dev Initialize function (replaces constructor for upgradeable contracts)
     */
    function initialize(
        address oracleAddress,
        address treasuryAddress,
        address governanceAddress
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        
        _version = "1.0.0";
        
        // Set default parameters
        _minimumPremiumPercentage = 500; // 5%
        _cancellationFeePercentage = 2000; // 20%
        _maxCoverageAmount = 1000000 ether; // 1 million ETH equivalent
        _minCoverageAmount = 0.1 ether;
        
        // Connect to other contracts
        _oracle = IAgroChainOracle(oracleAddress);
        _treasury = IAgroChainTreasury(treasuryAddress);
        _governance = IAgroChainGovernance(governanceAddress);
    }
    
    /**
     * @dev Modifier to check if policy exists
     */
    modifier policyExists(uint256 _policyId) {
        require(_policies[_policyId].id == _policyId, "Policy does not exist");
        _;
    }
    
    /**
     * @dev Modifier to check if caller is policy owner
     */
    modifier onlyPolicyOwner(uint256 _policyId) {
        require(_policies[_policyId].farmer == msg.sender, "Caller is not policy owner");
        _;
    }
    
    /**
     * @dev Modifier to check if caller is oracle
     */
    modifier onlyOracle() {
        require(msg.sender == address(_oracle), "Caller is not oracle");
        _;
    }
    
    /**
     * @dev Create a new policy
     */
    function createPolicy(
        address payable _farmer,
        uint256 _coverageAmount,
        uint256 _startDate,
        uint256 _endDate,
        string calldata _region,
        string calldata _cropType,
        ClimateParameter[] calldata _parameters
    ) 
        external 
        override 
        whenNotPaused 
        returns (uint256 policyId) 
    {
        // Input validation
        require(_farmer != address(0), "Invalid farmer address");
        require(_coverageAmount >= _minCoverageAmount, "Coverage amount too low");
        require(_coverageAmount <= _maxCoverageAmount, "Coverage amount too high");
        require(_startDate > block.timestamp, "Start date must be in future");
        require(_endDate > _startDate, "End date must be after start date");
        require(_parameters.length > 0, "Must have at least one parameter");
        require(_supportedRegions[_region], "Region not supported");
        require(_supportedCrops[_cropType], "Crop type not supported");
        
        // Validate parameters
        for(uint256 i = 0; i < _parameters.length; i++) {
            require(_parameters[i].thresholdValue > 0, "Invalid threshold value");
            require(_parameters[i].periodInDays > 0, "Invalid period");
            require(_parameters[i].payoutPercentage > 0 && _parameters[i].payoutPercentage <= 10000, "Invalid payout percentage");
            
            // Ensure the parameter type is valid (e.g., rainfall, temperature)
            require(
                _isValidParameterType(_parameters[i].parameterType),
                "Invalid parameter type"
            );
        }
        
        // Calculate premium based on risk model
        uint256 premium = _calculatePremium(_coverageAmount, _region, _cropType, _parameters);
        
        // Create policy ID
        policyId = ++_policyCounter;
        
        // Calculate policy data hash for verification
        bytes32 policyDataHash = keccak256(
            abi.encodePacked(
                policyId,
                _farmer,
                _coverageAmount,
                premium,
                _startDate,
                _endDate,
                _region,
                _cropType,
                abi.encode(_parameters)
            )
        );
        
        // Create the policy
        _policies[policyId] = Policy({
            id: policyId,
            farmer: _farmer,
            coverageAmount: _coverageAmount,
            premium: premium,
            startDate: _startDate,
            endDate: _endDate,
            active: false,
            claimed: false,
            claimPaid: 0,
            lastClaimDate: 0,
            policyDataHash: policyDataHash,
            region: _region,
            cropType: _cropType
        });
        
        // Store climate parameters
        for(uint256 i = 0; i < _parameters.length; i++) {
            _policyParameters[policyId].push(_parameters[i]);
        }
        
        // Emit event
        emit PolicyCreated(policyId, _farmer, _coverageAmount, _cropType);
        
        return policyId;
    }
    
    /**
     * @dev Activate policy by paying premium
     */
    function activatePolicy(uint256 _policyId) 
        external 
        payable 
        override 
        whenNotPaused 
        policyExists(_policyId) 
        nonReentrant 
    {
        Policy storage policy = _policies[_policyId];
        
        // Check policy status
        require(!policy.active, "Policy already active");
        require(block.timestamp < policy.startDate, "Policy start date has passed");
        require(msg.value >= policy.premium, "Insufficient premium payment");
        
        // Activate the policy
        policy.active = true;
        
        // Transfer premium to treasury
        _treasury.depositPremium{value: policy.premium}(_policyId);
        
        // Keep track of premiums collected
        _totalPremiumsCollected += policy.premium;
        
        // Refund excess if any
        uint256 excess = msg.value - policy.premium;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
        
        // Emit event
        emit PolicyActivated(_policyId, policy.premium);
    }
    
    /**
     * @dev Request climate data from oracle
     */
    function requestClimateData(uint256 _policyId, string calldata _parameterType) 
        external 
        override 
        whenNotPaused 
        policyExists(_policyId) 
        returns (bytes32) 
    {
        Policy storage policy = _policies[_policyId];
        
        // Check policy status
        require(policy.active, "Policy not active");
        require(block.timestamp >= policy.startDate, "Policy not started yet");
        require(block.timestamp <= policy.endDate, "Policy has expired");
        require(!policy.claimed || policy.claimPaid < policy.coverageAmount, "Policy fully claimed");
        
        // Verify the parameter type is valid for this policy
        bool validParameter = false;
        for(uint256 i = 0; i < _policyParameters[_policyId].length; i++) {
            if (keccak256(abi.encodePacked(_policyParameters[_policyId][i].parameterType)) == 
                keccak256(abi.encodePacked(_parameterType))) {
                validParameter = true;
                break;
            }
        }
        require(validParameter, "Parameter type not in policy");
        
        // Get regional oracles
        address[] memory oracleAddresses = _regionalOracles[policy.region];
        require(oracleAddresses.length > 0, "No oracles for region");
        
        // Request data from oracle
        bytes32 requestId = _oracle.requestClimateData(
            _policyId,
            _parameterType,
            policy.region,
            oracleAddresses
        );
        
        // Store request ID mapping
        _requestIdToPolicyId[requestId] = _policyId;
        
        // Emit event
        emit ClimateDataRequested(_policyId, requestId, _parameterType);
        
        return requestId;
    }
    
    /**
     * @dev Process claim with oracle data
     */
    function processClaim(uint256 _policyId, ClimateData calldata _climateData) 
        external 
        override 
        whenNotPaused 
        onlyOracle 
        nonReentrant 
        returns (bool success, uint256 amount) 
    {
        // Verify the climate data came from the right request
        require(_requestIdToPolicyId[_climateData.requestId] == _policyId, "Request ID mismatch");
        
        Policy storage policy = _policies[_policyId];
        
        // Check policy status
        require(policy.active, "Policy not active");
        require(block.timestamp >= policy.startDate, "Policy not started yet");
        require(block.timestamp <= policy.endDate, "Policy has expired");
        require(!policy.claimed || policy.claimPaid < policy.coverageAmount, "Policy fully claimed");
        
        // Find matching parameter
        ClimateParameter memory matchingParam;
        bool foundParam = false;
        
        for(uint256 i = 0; i < _policyParameters[_policyId].length; i++) {
            if (keccak256(abi.encodePacked(_policyParameters[_policyId][i].parameterType)) == 
                keccak256(abi.encodePacked(_climateData.parameterType))) {
                matchingParam = _policyParameters[_policyId][i];
                foundParam = true;
                break;
            }
        }
        
        require(foundParam, "Parameter type not found in policy");
        
        // Check if trigger condition is met
        bool triggered;
        if (matchingParam.triggerAbove) {
            triggered = _climateData.measuredValue > matchingParam.thresholdValue;
        } else {
            triggered = _climateData.measuredValue < matchingParam.thresholdValue;
        }
        
        // If trigger not met, return
        if (!triggered) {
            return (false, 0);
        }
        
        // Calculate payout amount
        uint256 totalCoverage = policy.coverageAmount;
        uint256 alreadyPaid = policy.claimPaid;
        uint256 remainingCoverage = totalCoverage - alreadyPaid;
        
        // Calculate payout percentage
        uint256 payoutPercentage = matchingParam.payoutPercentage;
        
        // Calculate amount to pay
        amount = (totalCoverage * payoutPercentage) / 10000;
        
        // Ensure we don't pay more than remaining coverage
        if (amount > remainingCoverage) {
            amount = remainingCoverage;
        }
        
        // If no amount to pay, return
        if (amount == 0) {
            return (false, 0);
        }
        
        // Update policy
        policy.claimed = true;
        policy.claimPaid += amount;
        policy.lastClaimDate = block.timestamp;
        
        // Update totals
        _totalClaimsPaid += amount;
        
        // Request payment from treasury
        bool paymentSuccess = _treasury.processClaim(_policyId, policy.farmer, amount);
        
        // If payment failed, revert
        require(paymentSuccess, "Treasury payment failed");
        
        // Emit event
        emit ClaimTriggered(_policyId, policy.farmer, amount);
        
        return (true, amount);
    }
    
    /**
     * @dev Cancel policy and refund premium if eligible
     */
    function cancelPolicy(uint256 _policyId) 
        external 
        override 
        policyExists(_policyId) 
        onlyPolicyOwner(_policyId) 
        nonReentrant 
        returns (uint256 refundAmount) 
    {
        Policy storage policy = _policies[_policyId];
        
        // Policy must be active and not started
        require(policy.active, "Policy not active");
        require(block.timestamp < policy.startDate, "Policy already started");
        require(!policy.claimed, "Policy already claimed");
        
        // Calculate refund amount (premium minus cancellation fee)
        uint256 cancellationFee = (policy.premium * _cancellationFeePercentage) / 10000;
        refundAmount = policy.premium - cancellationFee;
        
        // Mark policy as inactive
        policy.active = false;
        
        // Process refund from treasury
        bool refundSuccess = _treasury.processRefund(_policyId, policy.farmer, refundAmount);
        require(refundSuccess, "Treasury refund failed");
        
        // Emit event
        emit PolicyCancelled(_policyId, refundAmount);
        
        return refundAmount;
    }
    
    /**
     * @dev Get policy details
     */
    function getPolicyDetails(uint256 _policyId) 
        external 
        view 
        override 
        policyExists(_policyId) 
        returns (Policy memory, ClimateParameter[] memory) 
    {
        return (_policies[_policyId], _policyParameters[_policyId]);
    }
    
    /**
     * @dev Get policy status
     */
    function getPolicyStatus(uint256 _policyId) 
        external 
        view 
        override 
        policyExists(_policyId) 
        returns (
            bool active,
            bool claimed,
            uint256 claimPaid,
            uint256 remainingCoverage,
            uint256 timeRemaining
        ) 
    {
        Policy memory policy = _policies[_policyId];
        
        active = policy.active;
        claimed = policy.claimed;
        claimPaid = policy.claimPaid;
        remainingCoverage = policy.coverageAmount - policy.claimPaid;
        
        if (block.timestamp < policy.endDate) {
            timeRemaining = policy.endDate - block.timestamp;
        } else {
            timeRemaining = 0;
        }
    }
    
    /**
     * @dev Calculate premium based on risk model
     * @notice This is a simplified risk model that would be much more complex in production
     */
    function _calculatePremium(
        uint256 _coverageAmount,
        string memory _region,
        string memory _cropType,
        ClimateParameter[] memory _parameters
    ) 
        internal 
        view 
        returns (uint256) 
    {
        // Get base risk score for region and crop
        uint256 baseRisk = _baseRiskScores[_region][_cropType];
        if (baseRisk == 0) {
            baseRisk = 500; // Default 5% if no specific risk score
        }
        
        // Adjust risk based on parameters
        uint256 parameterRisk = 0;
        for(uint256 i = 0; i < _parameters.length; i++) {
            // Add risk based on payout percentage
            parameterRisk += _parameters[i].payoutPercentage / 100;
            
            // Add risk based on threshold (simplified)
            if (_parameters[i].triggerAbove) {
                // For "above threshold" triggers, higher thresholds are less risky
                parameterRisk += 100 / (_parameters[i].thresholdValue / 100 + 1);
            } else {
                // For "below threshold" triggers, lower thresholds are less risky
                parameterRisk += _parameters[i].thresholdValue / 10;
            }
            
            // Risk increases with longer periods
            parameterRisk += _parameters[i].periodInDays / 10;
        }
        
        // Adjust for number of parameters
        parameterRisk = parameterRisk * 100 / _parameters.length;
        
        // Calculate total risk (base + parameters)
        uint256 totalRisk = baseRisk + parameterRisk;
        
        // Ensure minimum premium percentage
        if (totalRisk < _minimumPremiumPercentage) {
            totalRisk = _minimumPremiumPercentage;
        }
        
        // Calculate premium
        return (_coverageAmount * totalRisk) / 10000;
    }
    
    /**
     * @dev Check if climate parameter type is valid
     */
    function _isValidParameterType(string memory _parameterType) internal pure returns (bool) {
        bytes32 paramHash = keccak256(abi.encodePacked(_parameterType));
        
        return (
            paramHash == keccak256(abi.encodePacked("rainfall")) ||
            paramHash == keccak256(abi.encodePacked("temperature")) ||
            paramHash == keccak256(abi.encodePacked("humidity")) ||
            paramHash == keccak256(abi.encodePacked("wind_speed")) ||
            paramHash == keccak256(abi.encodePacked("drought_days")) ||
            paramHash == keccak256(abi.encodePacked("frost_days"))
        );
    }
    
    // ======== Admin Functions ========
    
    /**
     * @dev Add supported region
     */
    function addSupportedRegion(string calldata _region) external onlyOwner {
        _supportedRegions[_region] = true;
    }
    
    /**
     * @dev Remove supported region
     */
    function removeSupportedRegion(string calldata _region) external onlyOwner {
        _supportedRegions[_region] = false;
    }
    
    /**
     * @dev Add supported crop
     */
    function addSupportedCrop(string calldata _cropType) external onlyOwner {
        _supportedCrops[_cropType] = true;
    }
    
    /**
     * @dev Remove supported crop
     */
    function removeSupportedCrop(string calldata _cropType) external onlyOwner {
        _supportedCrops[_cropType] = false;
    }
    
    /**
     * @dev Set regional oracles
     */
    function setRegionalOracles(string calldata _region, address[] calldata _oracles) external onlyOwner {
        _regionalOracles[_region] = _oracles;
    }
    
    /**
     * @dev Set base risk score for region and crop
     */
    function setBaseRiskScore(
        string calldata _region,
        string calldata _cropType,
        uint256 _riskScore
    ) 
        external 
        onlyOwner 
    {
        require(_riskScore > 0 && _riskScore <= 10000, "Invalid risk score");
        _baseRiskScores[_region][_cropType] = _riskScore;
    }
    
    /**
     * @dev Set minimum premium percentage (in basis points)
     */
    function setMinimumPremiumPercentage(uint256 _percentage) external onlyOwner {
        require(_percentage > 0 && _percentage <= 5000, "Invalid percentage");
        _minimumPremiumPercentage = _percentage;
    }
    
    /**
     * @dev Set cancellation fee percentage (in basis points)
     */
    function setCancellationFeePercentage(uint256 _percentage) external onlyOwner {
        require(_percentage <= 5000, "Invalid percentage");
        _cancellationFeePercentage = _percentage;
    }
    
    /**
     * @dev Set coverage limits
     */
    function setCoverageLimits(uint256 _min, uint256 _max) external onlyOwner {
        require(_min > 0 && _max > _min, "Invalid limits");
        _minCoverageAmount = _min;
        _maxCoverageAmount = _max;
    }
    
    /**
     * @dev Update oracle contract
     */
    function setOracleContract(address _oracleAddress) external onlyOwner {
        require(_oracleAddress != address(0), "Invalid oracle address");
        _oracle = IAgroChainOracle(_oracleAddress);
    }
    
    /**
     * @dev Update treasury contract
     */
    function setTreasuryContract(address _treasuryAddress) external onlyOwner {
        require(_treasuryAddress != address(0), "Invalid treasury address");
        _treasury = IAgroChainTreasury(_treasuryAddress);
    }
    
    /**
     * @dev Update governance contract
     */
    function setGovernanceContract(address _governanceAddress) external onlyOwner {
        require(_governanceAddress != address(0), "Invalid governance address");
        _governance = IAgroChainGovernance(_governanceAddress);
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
     * @dev Get system statistics
     */
    function getSystemStats() external view returns (
        uint256 totalPolicies,
        uint256 totalPremiums,
        uint256 totalClaims
    ) {
        return (
            _policyCounter,
            _totalPremiumsCollected,
            _totalClaimsPaid
        );
    }
}
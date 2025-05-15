// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IAgroChainOracle.sol";
import "./IAgroChainInsurance.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

/**
 * @title AgroChainOracle
 * @dev Implementation of the oracle system for climate data
 * @notice Integrates with Chainlink nodes for reliable climate data delivery
 */
contract AgroChainOracle is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable,
    IAgroChainOracle 
{
    // Custom errors
    error UnauthorizedDataProvider();
    error RequestNotFound();
    error RequestAlreadyFulfilled();
    error InvalidRequestParameters();
    error InsufficientResponses();
    error CallbackFailed();
    
    // Version tracking
    string private _version;
    
    // Main insurance contract
    address private _insuranceContract;
    
    // Registered data providers
    mapping(address => bool) private _registeredProviders;
    
    // Threshold of responses required for consensus (in percentage)
    uint256 private _consensusThreshold;
    
    // Minimum number of responses required
    uint256 private _minResponses;
    
    // Maximum number of responses to wait for
    uint256 private _maxResponses;
    
    // Timeout for requests (in seconds)
    uint256 private _requestTimeout;
    
    // Storage for oracle requests
    mapping(bytes32 => OracleRequest) private _requests;
    
    // Historical data storage
    mapping(string => mapping(string => mapping(uint256 => uint256))) private _historicalData;
    // region => parameterType => timestamp => value
    
    // Deviation threshold for outlier detection (percentage, e.g. 2000 = 20%)
    uint256 private _deviationThreshold;
    
    // Chainlink integration
    address private _chainlinkToken;
    address private _chainlinkOracle;
    bytes32 private _jobId;
    uint256 private _chainlinkFee;
    
    /**
     * @dev Modifier to check if caller is authorized
     */
    modifier onlyInsurance() {
        require(msg.sender == _insuranceContract, "Caller is not insurance contract");
        _;
    }
    
    /**
     * @dev Modifier to check if caller is a registered data provider
     */
    modifier onlyProvider() {
        if (!_registeredProviders[msg.sender]) revert UnauthorizedDataProvider();
        _;
    }
    
    /**
     * @dev Initialize function
     */
    function initialize(
        address insuranceContract,
        address chainlinkToken,
        address chainlinkOracle,
        bytes32 jobId,
        uint256 chainlinkFee
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        
        _version = "1.0.0";
        _insuranceContract = insuranceContract;
        
        // Set default parameters
        _consensusThreshold = 6600; // 66%
        _minResponses = 3;
        _maxResponses = 10;
        _requestTimeout = 1 days;
        _deviationThreshold = 2000; // 20%
        
        // Chainlink setup
        _chainlinkToken = chainlinkToken;
        _chainlinkOracle = chainlinkOracle;
        _jobId = jobId;
        _chainlinkFee = chainlinkFee;
    }
    
    /**
     * @dev Request climate data from oracles
     */
    function requestClimateData(
        uint256 policyId,
        string calldata parameterType,
        string calldata region,
        address[] memory dataProviders
    ) 
        external 
        override 
        onlyInsurance 
        whenNotPaused 
        returns (bytes32 requestId) 
    {
        // Validate inputs
        require(policyId > 0, "Invalid policy ID");
        require(bytes(parameterType).length > 0, "Invalid parameter type");
        require(bytes(region).length > 0, "Invalid region");
        require(dataProviders.length >= _minResponses, "Insufficient data providers");
        
        // Validate data providers
        uint256 validProviders = 0;
        for(uint256 i = 0; i < dataProviders.length; i++) {
            if (_registeredProviders[dataProviders[i]]) {
                validProviders++;
            }
        }
        require(validProviders >= _minResponses, "Insufficient valid providers");
        
        // Generate unique request ID
        requestId = keccak256(abi.encodePacked(
            policyId,
            parameterType,
            region,
            block.timestamp,
            block.prevrandao
        ));
        
        // Create new request
        OracleRequest storage request = _requests[requestId];
        request.policyId = policyId;
        request.parameterType = parameterType;
        request.region = region;
        request.timestamp = block.timestamp;
        request.requester = msg.sender;
        request.dataProviders = dataProviders;
        request.fulfilled = false;
        request.responseCount = 0;
        request.aggregatedValue = 0;
        
        // If we have Chainlink, also make a Chainlink request
        if (_chainlinkToken != address(0) && _chainlinkOracle != address(0)) {
            _requestChainlinkData(requestId, parameterType, region);
        }
        
        // Emit event
        emit DataRequested(requestId, policyId, parameterType);
        
        return requestId;
    }
    
    /**
     * @dev Submit data from a provider oracle
     */
    function submitOracleData(bytes32 requestId, uint256 value) 
        external 
        override 
        onlyProvider 
        whenNotPaused 
        nonReentrant 
    {
        // Validate request exists
        OracleRequest storage request = _requests[requestId];
        if (request.timestamp == 0) revert RequestNotFound();
        if (request.fulfilled) revert RequestAlreadyFulfilled();
        
        // Check if provider is authorized for this request
        bool isAuthorized = false;
        for(uint256 i = 0; i < request.dataProviders.length; i++) {
            if (request.dataProviders[i] == msg.sender) {
                isAuthorized = true;
                break;
            }
        }
        
        if (!isAuthorized) revert UnauthorizedDataProvider();
        
        // Check if provider already submitted data
        if (request.validations[msg.sender]) {
            return; // Already submitted, just ignore
        }
        
        // Record provider response
        request.validations[msg.sender] = true;
        request.responseCount++;
        
        // Check for outliers if we already have responses
        if (request.responseCount > 1) {
            // Get current average
            uint256 currentAvg = request.aggregatedValue / (request.responseCount - 1);
            
            // Calculate deviation from average
            uint256 deviation;
            if (value > currentAvg) {
                deviation = ((value - currentAvg) * 10000) / currentAvg;
            } else {
                deviation = ((currentAvg - value) * 10000) / currentAvg;
            }
            
            // If deviation is within threshold, add to aggregation
            if (deviation <= _deviationThreshold) {
                request.aggregatedValue += value;
                emit DataProviderResponse(requestId, msg.sender, value);
            }
            // Otherwise, don't count this value but still mark as responded
        } else {
            // First response, just add it
            request.aggregatedValue = value;
            emit DataProviderResponse(requestId, msg.sender, value);
        }
        
        // Check if we have reached consensus
        _checkConsensusAndFulfill(requestId);
    }
    
    /**
     * @dev Get status of an oracle request
     */
    function getRequestStatus(bytes32 requestId) 
        external 
        view 
        override 
        returns (bool fulfilled, uint256 value, uint256 responseCount) 
    {
        OracleRequest storage request = _requests[requestId];
        if (request.timestamp == 0) revert RequestNotFound();
        
        return (
            request.fulfilled,
            request.aggregatedValue / (request.responseCount > 0 ? request.responseCount : 1),
            request.responseCount
        );
    }
    
    /**
     * @dev Check if consensus has been reached and fulfill the request
     */
    function _checkConsensusAndFulfill(bytes32 requestId) internal {
        OracleRequest storage request = _requests[requestId];
        
        // Check if we already have enough responses
        bool consensusReached = request.responseCount >= _minResponses;
        
        // Check if we've reached max responses or consensus threshold
        bool maxResponsesReached = request.responseCount >= _maxResponses;
        bool thresholdPercentReached = (request.responseCount * 10000) / request.dataProviders.length >= _consensusThreshold;
        
        // Check if request has timed out
        bool timedOut = block.timestamp > request.timestamp + _requestTimeout;
        
        // If we have consensus or reached max/timeout
        if (consensusReached && (maxResponsesReached || thresholdPercentReached || timedOut)) {
            // Calculate final value (average of responses)
            uint256 finalValue = request.aggregatedValue / request.responseCount;
            
            // Store in historical data
            _historicalData[request.region][request.parameterType][request.timestamp] = finalValue;
            
            // Mark as fulfilled
            request.fulfilled = true;
            
            // Emit event
            emit DataFulfilled(requestId, finalValue);
            
            // Create climate data structure
            IAgroChainInsurance.ClimateData memory climateData = IAgroChainInsurance.ClimateData({
                requestId: requestId,
                parameterType: request.parameterType,
                measuredValue: finalValue,
                timestamp: block.timestamp,
                dataSource: "AgroChain Oracle Network",
                signature: abi.encodePacked(requestId, finalValue)
            });
            
            // Call back to insurance contract
            IAgroChainInsurance insurance = IAgroChainInsurance(_insuranceContract);
            (bool success, ) = address(insurance).call(
                abi.encodeWithSelector(
                    insurance.processClaim.selector,
                    request.policyId,
                    climateData
                )
            );
            
            if (!success) {
                // Log error but don't revert - data is still saved
                emit FailedCallback(requestId, request.policyId);
            }
        }
    }
    
    /**
     * @dev Request data from Chainlink
     */
    function _requestChainlinkData(
        bytes32 requestId,
        string memory parameterType,
        string memory region
    ) internal {
        // In a real implementation, this would make a call to the Chainlink network
        // to request validated weather data for the specified parameter and region
        
        // For this example, we're not implementing the full Chainlink integration,
        // but in production this would use the ChainlinkClient contract
    }
    
    /**
     * @dev Receive data from Chainlink (callback function)
     */
    function fulfillChainlinkRequest(
        bytes32 requestId,
        uint256 value
    ) external {
        // In production, this would verify the request came from Chainlink
        // and then process the data similar to submitOracleData
        
        // For now, we'll use a simplified approach where we trust the Chainlink node
        OracleRequest storage request = _requests[requestId];
        if (request.timestamp == 0) revert RequestNotFound();
        if (request.fulfilled) revert RequestAlreadyFulfilled();
        
        // Record Chainlink as a special provider
        request.responseCount++;
        request.aggregatedValue += value;
        
        // Check for consensus
        _checkConsensusAndFulfill(requestId);
    }
    
    /**
     * @dev Get historical climate data
     */
    function getHistoricalData(
        string calldata region,
        string calldata parameterType,
        uint256 timestamp
    ) external view returns (uint256) {
        return _historicalData[region][parameterType][timestamp];
    }
    
    /**
     * @dev Get average historical data for a time period
     */
function getAverageHistoricalData(
    string calldata region,
    string calldata parameterType,
    uint256 startTime,
    uint256 endTime
) external view returns (uint256) {
    require(endTime > startTime, "Invalid time range");
    require(endTime <= block.timestamp, "Future time not available");
    
    uint256 total = 0;
    uint256 count = 0;
    
    // Usar um incremento maior para evitar loops muito grandes
    uint256 intervalStep = 1 days;
    
    // Ajustar o loop para garantir que ele não execute indefinidamente
    uint256 maxIterations = 30; // Limite razoável de iterações
    uint256 iterations = 0;
    
    for (uint256 i = startTime; i <= endTime && iterations < maxIterations; i += intervalStep) {
        // Acessar diretamente a estrutura de dados em vez de chamar getHistoricalData
        uint256 value = _historicalData[region][parameterType][i];
        if (value > 0) {
            total += value;
            count++;
        }
        iterations++;
    }
    
    // Se não encontramos dados com o intervalo regular, tente alguns pontos específicos
    if (count == 0) {
        // Verificar no início, meio e fim do intervalo
        uint256 midTime = startTime + ((endTime - startTime) / 2);
        
        uint256 valueStart = _historicalData[region][parameterType][startTime];
        uint256 valueMid = _historicalData[region][parameterType][midTime];
        uint256 valueEnd = _historicalData[region][parameterType][endTime];
        
        if (valueStart > 0) { total += valueStart; count++; }
        if (valueMid > 0) { total += valueMid; count++; }
        if (valueEnd > 0) { total += valueEnd; count++; }
    }
    
    if (count == 0) return 0;
    return total / count;
}
    
    // ======== Admin Functions ========
    
    /**
     * @dev Register a data provider
     */
    function registerProvider(address provider) external onlyOwner {
        _registeredProviders[provider] = true;
    }
    
    /**
     * @dev Remove a data provider
     */
    function removeProvider(address provider) external onlyOwner {
        _registeredProviders[provider] = false;
    }
    
    /**
     * @dev Set consensus parameters
     */
    function setConsensusParameters(
        uint256 threshold,
        uint256 minResponses,
        uint256 maxResponses
    ) external onlyOwner {
        require(threshold > 0 && threshold <= 10000, "Invalid threshold");
        require(minResponses > 0, "Invalid min responses");
        require(maxResponses >= minResponses, "Max must be >= min");
        
        _consensusThreshold = threshold;
        _minResponses = minResponses;
        _maxResponses = maxResponses;
    }
    
    /**
     * @dev Set request timeout
     */
    function setRequestTimeout(uint256 timeout) external onlyOwner {
        require(timeout > 0, "Invalid timeout");
        _requestTimeout = timeout;
    }
    
    /**
     * @dev Set deviation threshold for outlier detection
     */
    function setDeviationThreshold(uint256 threshold) external onlyOwner {
        require(threshold > 0, "Invalid threshold");
        _deviationThreshold = threshold;
    }
    
    /**
     * @dev Update insurance contract
     */
    function setInsuranceContract(address insuranceContract) external onlyOwner {
        require(insuranceContract != address(0), "Invalid insurance address");
        _insuranceContract = insuranceContract;
    }
    
    /**
     * @dev Update Chainlink settings
     */
    function setChainlinkParams(
        address token,
        address oracle,
        bytes32 jobId,
        uint256 fee
    ) external onlyOwner {
        _chainlinkToken = token;
        _chainlinkOracle = oracle;
        _jobId = jobId;
        _chainlinkFee = fee;
    }
    
    /**
     * @dev Manually add historical data (for initial seeding or corrections)
     */
    function addHistoricalData(
        string calldata region,
        string calldata parameterType,
        uint256 timestamp,
        uint256 value
    ) external onlyOwner {
        require(timestamp < block.timestamp, "Cannot set future data");
        _historicalData[region][parameterType][timestamp] = value;
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
     * @dev Check if an address is a registered provider
     */
    function isRegisteredProvider(address provider) external view returns (bool) {
        return _registeredProviders[provider];
    }
    
    /**
     * @dev Event for failed callbacks
     */
    event FailedCallback(bytes32 indexed requestId, uint256 indexed policyId);
}
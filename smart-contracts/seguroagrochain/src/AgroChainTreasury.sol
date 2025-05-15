// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IAgroChainTreasury.sol";
import "./IAgroChainInsurance.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AgroChainTreasury
 * @dev Implementation of the treasury management system
 * @notice Handles premium collection, claim payments, and capital management
 */
contract AgroChainTreasury is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable,
    IAgroChainTreasury 
{
    // Custom errors
    error UnauthorizedCaller();
    error InsufficientFunds();
    error TransferFailed();
    error InvalidParameters();
    error ExceedsWithdrawalLimit();
    error YieldStrategyError();
    
    // Version tracking
    string private _version;
    
    // Authorized contracts
    address private _insuranceContract;
    
    // Pool balances
    uint256 private _premiumPool;
    uint256 private _claimPool;
    uint256 private _yieldPool;
    
    // Stats
    uint256 private _totalPremiumsCollected;
    uint256 private _totalClaimsPaid;
    uint256 private _totalCapitalAdded;
    uint256 private _totalYieldGenerated;
    uint256 private _policyCount;
    
    // Financial model parameters
    uint256 private _targetReserveRatio; // basis points (e.g., 15000 = 150%)
    uint256 private _minReserveRatio; // basis points (e.g., 12000 = 120%)
    uint256 private _maxYieldAllocation; // basis points (e.g., 3000 = 30%)
    uint256 private _emergencyWithdrawalLimit; // basis points (e.g., 2000 = 20%)
    
    // Stablecoin integrations (for multi-currency support)
    mapping(address => bool) private _supportedStablecoins;
    mapping(address => uint256) private _stablecoinBalances;
    
    // Risk exposure
    mapping(string => uint256) private _regionalExposure; // region -> total coverage amount
    mapping(string => uint256) private _cropExposure; // cropType -> total coverage amount
    uint256 private _totalCoverageExposure;
    
    // Yield strategy contracts
    mapping(address => bool) private _yieldStrategies;
    mapping(address => uint256) private _strategyAllocations; // Strategy -> allocation percentage (basis points)
    
    // Policy data
    mapping(uint256 => bool) private _activePolicies; // policyId -> is active
    mapping(uint256 => uint256) private _policyCoverage; // policyId -> coverage amount
    
    /**
     * @dev Modifier to check if caller is authorized
     */
    modifier onlyInsurance() {
        if (msg.sender != _insuranceContract) revert UnauthorizedCaller();
        _;
    }
    
    /**
     * @dev Modifier to check if yield strategy is valid
     */
    modifier onlyYieldStrategy(address strategy) {
        if (!_yieldStrategies[strategy]) revert UnauthorizedCaller();
        _;
    }
    
    /**
     * @dev Initialize function
     */
    function initialize(address insuranceContract) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        
        _version = "1.0.0";
        _insuranceContract = insuranceContract;
        
        // Set default financial parameters
        _targetReserveRatio = 15000; // 150%
        _minReserveRatio = 12000; // 120%
        _maxYieldAllocation = 3000; // 30%
        _emergencyWithdrawalLimit = 2000; // 20%
    }
    
    /**
     * @dev Deposit premium payment
     */
    function depositPremium(uint256 policyId) 
        external 
        payable 
        override 
        onlyInsurance 
        whenNotPaused 
        returns (bool success) 
    {
        require(msg.value > 0, "Premium amount must be positive");
        
        // Update policy tracking
        _activePolicies[policyId] = true;
        
        // Get policy details to update exposure
        IAgroChainInsurance insurance = IAgroChainInsurance(_insuranceContract);
        (IAgroChainInsurance.Policy memory policy, ) = insurance.getPolicyDetails(policyId);
        
        // Update risk exposure
        _regionalExposure[policy.region] += policy.coverageAmount;
        _cropExposure[policy.cropType] += policy.coverageAmount;
        _totalCoverageExposure += policy.coverageAmount;
        _policyCoverage[policyId] = policy.coverageAmount;
        _policyCount++;
        
        // Distribute premium to pools
        uint256 premiumForClaims = (msg.value * 7000) / 10000; // 70% to claim pool
        uint256 premiumForYield = (msg.value * 2000) / 10000; // 20% to yield pool
        uint256 premiumForFees = msg.value - premiumForClaims - premiumForYield; // 10% to premium pool (fees)
        
        _claimPool += premiumForClaims;
        _yieldPool += premiumForYield;
        _premiumPool += premiumForFees;
        
        // Update stats
        _totalPremiumsCollected += msg.value;
        
        emit PremiumDeposited(policyId, msg.value);
        
        // Check if yield pool should be deployed to strategies
        _considerYieldDeployment();
        
        return true;
    }
    
    /**
     * @dev Process claim payment
     */
    function processClaim(uint256 policyId, address payable recipient, uint256 amount) 
        external 
        override 
        onlyInsurance 
        whenNotPaused 
        nonReentrant 
        returns (bool success) 
    {
        require(amount > 0, "Claim amount must be positive");
        require(recipient != address(0), "Invalid recipient");
        require(_activePolicies[policyId], "Policy not active");
        
        // Check if we have enough funds
        if (_claimPool < amount) {
            // Try to rebalance from yield pool
            if (_claimPool + _yieldPool >= amount) {
                uint256 neededFromYield = amount - _claimPool;
                _yieldPool -= neededFromYield;
                _claimPool += neededFromYield;
                emit RiskPoolRebalanced(block.timestamp, _claimPool + _yieldPool + _premiumPool);
            } else {
                revert InsufficientFunds();
            }
        }
        
        // Update claim pool
        _claimPool -= amount;
        _totalClaimsPaid += amount;
        
        // Transfer funds to recipient
        (bool sent, ) = recipient.call{value: amount}("");
        if (!sent) revert TransferFailed();
        
        emit ClaimPaid(policyId, recipient, amount);
        
        // Check if we need to rebalance pools
        _checkAndRebalancePools();
        
        return true;
    }
    
    /**
     * @dev Process policy refund
     */
    function processRefund(uint256 policyId, address payable recipient, uint256 amount) 
        external 
        override 
        onlyInsurance 
        whenNotPaused 
        nonReentrant 
        returns (bool success) 
    {
        require(amount > 0, "Refund amount must be positive");
        require(recipient != address(0), "Invalid recipient");
        require(_activePolicies[policyId], "Policy not active");
        
        // Check if we have enough funds
        if (_premiumPool < amount) {
            // Try to rebalance from other pools
            if (_premiumPool + _yieldPool >= amount) {
                uint256 neededFromYield = amount - _premiumPool;
                _yieldPool -= neededFromYield;
                _premiumPool += neededFromYield;
                emit RiskPoolRebalanced(block.timestamp, _claimPool + _yieldPool + _premiumPool);
            } else {
                revert InsufficientFunds();
            }
        }
        
        // Update premium pool
        _premiumPool -= amount;
        
        // Update policy status
        _activePolicies[policyId] = false;
        
        // Get policy details to update exposure
        IAgroChainInsurance insurance = IAgroChainInsurance(_insuranceContract);
        (IAgroChainInsurance.Policy memory policy, ) = insurance.getPolicyDetails(policyId);
        
        // Update risk exposure
        _regionalExposure[policy.region] -= policy.coverageAmount;
        _cropExposure[policy.cropType] -= policy.coverageAmount;
        _totalCoverageExposure -= policy.coverageAmount;
        _policyCoverage[policyId] = 0;
        _policyCount--;
        
        // Transfer funds to recipient
        (bool sent, ) = recipient.call{value: amount}("");
        if (!sent) revert TransferFailed();
        
        emit RefundProcessed(policyId, recipient, amount);
        
        return true;
    }
    
    /**
     * @dev Get balance information
     */
    function getBalanceInfo() 
        external 
        view 
        override 
        returns (
            uint256 premiumPool,
            uint256 claimPool,
            uint256 yieldPool,
            uint256 totalBalance,
            uint256 totalClaims
        ) 
    {
        return (
            _premiumPool,
            _claimPool,
            _yieldPool,
            _premiumPool + _claimPool + _yieldPool,
            _totalClaimsPaid
        );
    }
    
    /**
     * @dev Get financial health indicators
     */
    function getFinancialHealth() 
        external 
        view 
        override 
        returns (
            uint256 solvencyRatio,
            uint256 reserveRatio,
            uint256 liquidityRatio
        ) 
    {
        uint256 totalAssets = _premiumPool + _claimPool + _yieldPool;
        
        // Solvency ratio = total assets / total coverage exposure
        solvencyRatio = _totalCoverageExposure > 0 
            ? (totalAssets * 10000) / _totalCoverageExposure 
            : 10000; // 100% if no exposure
        
        // Reserve ratio = claim pool / total coverage exposure
        reserveRatio = _totalCoverageExposure > 0 
            ? (_claimPool * 10000) / _totalCoverageExposure 
            : 10000; // 100% if no exposure
        
        // Liquidity ratio = (premium pool + claim pool) / total short-term obligations
        // For simplicity, we'll estimate short-term obligations as 10% of total coverage
        uint256 shortTermObligations = _totalCoverageExposure / 10;
        liquidityRatio = shortTermObligations > 0 
            ? ((_premiumPool + _claimPool) * 10000) / shortTermObligations 
            : 10000; // 100% if no obligations
            
        return (solvencyRatio, reserveRatio, liquidityRatio);
    }
    
    /**
     * @dev Add capital to the treasury
     */
    
    function addCapital() external payable nonReentrant whenNotPaused {
        require(msg.value > 0, "Amount must be positive");
        // Add to claim pool by default
        _claimPool += msg.value;
        _totalCapitalAdded += msg.value;
        
        emit CapitalAdded(msg.sender, msg.value);
        
        // Rebalance pools if needed
        _checkAndRebalancePools();
    }
    
    /**
     * @dev Handle yield strategy returns
     */
    function receiveYieldReturns() external payable onlyYieldStrategy(msg.sender) {
        require(msg.value > 0, "Amount must be positive");
        
        // Add to yield pool
        _yieldPool += msg.value;
        _totalYieldGenerated += msg.value;
        
        emit YieldGenerated(msg.value);
        
        // Rebalance pools if needed
        _checkAndRebalancePools();
    }
    
    /**
     * @dev Withdraw from yield strategies in emergency
     */
    function emergencyWithdrawal(address strategy, uint256 amount) external onlyOwner nonReentrant {
        require(_yieldStrategies[strategy], "Invalid strategy");
        require(amount > 0, "Amount must be positive");
        
        // Calculate maximum allowed withdrawal
        uint256 maxWithdrawal = (_premiumPool + _claimPool + _yieldPool) * _emergencyWithdrawalLimit / 10000;
        
        if (amount > maxWithdrawal) revert ExceedsWithdrawalLimit();
        
        // Call withdraw on strategy contract
        // In a real implementation, this would make a call to the strategy contract
        // For simplicity, we'll simulate it here
        
        // Add withdrawn amount to claim pool
        _claimPool += amount;
        
        emit CapitalWithdrawn(strategy, amount);
    }
    
    /**
     * @dev Withdraw fees to owner
     */
    function withdrawFees(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be positive");
        
        // Calculate maximum allowed fee withdrawal (from premium pool only)
        uint256 maxFeeWithdrawal = _premiumPool / 2; // Up to 50% of premium pool
        
        require(amount <= maxFeeWithdrawal, "Exceeds maximum fee withdrawal");
        
        // Update premium pool
        _premiumPool -= amount;
        
        // Transfer to owner
        (bool sent, ) = owner().call{value: amount}("");
        if (!sent) revert TransferFailed();
        
        emit CapitalWithdrawn(owner(), amount);
    }
    
    /**
     * @dev Get risk exposure information
     */
    function getRiskExposure() external view returns (
        uint256 totalExposure,
        uint256 activePolicyCount,
        uint256 coverageToReserveRatio
    ) {
        totalExposure = _totalCoverageExposure;
        activePolicyCount = _policyCount;
        
        // Coverage to reserve ratio = total coverage / claim pool
        coverageToReserveRatio = _claimPool > 0 
            ? (_totalCoverageExposure * 10000) / _claimPool 
            : 0; // 0% if no reserve
    }
    
    /**
     * @dev Get regional exposure
     */
    function getRegionalExposure(string calldata region) external view returns (uint256) {
        return _regionalExposure[region];
    }
    
    /**
     * @dev Get crop type exposure
     */
    function getCropExposure(string calldata cropType) external view returns (uint256) {
        return _cropExposure[cropType];
    }
    
    /**
     * @dev Internal function to check and rebalance pools if needed
     */
    function _checkAndRebalancePools() internal {
        // Check if claim pool is below minimum reserve ratio
        uint256 currentReserveRatio;
        
        if (_totalCoverageExposure > 0) {
            // Evitar overflow na multiplicação
            if (_claimPool <= type(uint256).max / 10000) {
                // Se não há risco de overflow, faça a multiplicação antes da divisão
                currentReserveRatio = (_claimPool * 10000) / _totalCoverageExposure;
            } else {
                // Caso contrário, divida primeiro para evitar overflow
                currentReserveRatio = _claimPool / (_totalCoverageExposure / 10000);
            }
        } else {
            currentReserveRatio = 10000; // Valor padrão quando não há exposição
        }
        
        if (currentReserveRatio < _minReserveRatio) {
            // Calcular targetClaimPool com segurança
            uint256 targetClaimPool;
            if (_totalCoverageExposure <= type(uint256).max / _minReserveRatio) {
                // Se não há risco de overflow
                targetClaimPool = (_totalCoverageExposure * _minReserveRatio) / 10000;
            } else {
                // Divida primeiro para evitar overflow
                targetClaimPool = (_totalCoverageExposure / 10000) * _minReserveRatio;
            }
            
            // Evitar underflow em caso de targetClaimPool < _claimPool
            uint256 shortfall;
            if (targetClaimPool > _claimPool) {
                shortfall = targetClaimPool - _claimPool;
                
                // Cap shortfall to available yield
                if (shortfall > _yieldPool) {
                    shortfall = _yieldPool;
                }
                
                if (shortfall > 0) {
                    _yieldPool -= shortfall;
                    _claimPool += shortfall;
                    
                    // Verificar overflow antes de somar para o evento
                    uint256 totalPoolsAmount;
                    
                    // Soma com verificação de overflow
                    unchecked {
                        // Primeiro some _claimPool e _yieldPool
                        totalPoolsAmount = _claimPool;
                        if (totalPoolsAmount + _yieldPool < totalPoolsAmount) {
                            // Overflow detectado
                            totalPoolsAmount = type(uint256).max;
                        } else {
                            totalPoolsAmount += _yieldPool;
                            
                            // Agora adicione _premiumPool
                            if (totalPoolsAmount + _premiumPool < totalPoolsAmount) {
                                // Overflow detectado
                                totalPoolsAmount = type(uint256).max;
                            } else {
                                totalPoolsAmount += _premiumPool;
                            }
                        }
                    }
                    
                    emit RiskPoolRebalanced(block.timestamp, totalPoolsAmount);
                }
            }
        }
        
        // Check if we should deploy more to yield strategies
        _considerYieldDeployment();
    }
    
    /**
     * @dev Internal function to consider deploying yield
     */
    function _considerYieldDeployment() internal {
        // Only deploy if current yield pool exceeds threshold
        uint256 totalBalance = _premiumPool + _claimPool + _yieldPool;
        uint256 maxYieldAllowed = (totalBalance * _maxYieldAllocation) / 10000;
        
        // If current yield pool is already at or above max allowed, don't deploy more
        if (_yieldPool >= maxYieldAllowed) {
            return;
        }
        
        // If claim pool has sufficient reserves, we can deploy more to yield
        uint256 currentReserveRatio = _totalCoverageExposure > 0 
            ? (_claimPool * 10000) / _totalCoverageExposure 
            : 10000;
            
        if (currentReserveRatio > _targetReserveRatio) {
            // Calculate how much we can safely move to yield
            uint256 excessReserve = _claimPool - (_totalCoverageExposure * _targetReserveRatio / 10000);
            
            // Cap to available space in yield allocation
            uint256 yieldSpace = maxYieldAllowed - _yieldPool;
            if (excessReserve > yieldSpace) {
                excessReserve = yieldSpace;
            }
            
            if (excessReserve > 0) {
                _claimPool -= excessReserve;
                _yieldPool += excessReserve;
                
                emit RiskPoolRebalanced(block.timestamp, _claimPool + _yieldPool + _premiumPool);
                
                // In a real implementation, we would then allocate this to yield strategies
                // For simplicity, we'll assume it happens automatically
            }
        }
    }
    
    // ======== Admin Functions ========
    
    /**
     * @dev Update insurance contract
     */
    function setInsuranceContract(address insuranceContract) external onlyOwner {
        require(insuranceContract != address(0), "Invalid insurance address");
        _insuranceContract = insuranceContract;
    }
    
    /**
     * @dev Set financial parameters
     */
    function setFinancialParameters(
        uint256 targetReserveRatio,
        uint256 minReserveRatio,
        uint256 maxYieldAllocation,
        uint256 emergencyWithdrawalLimit
    ) external onlyOwner {
        require(targetReserveRatio > minReserveRatio, "Target must exceed minimum");
        require(minReserveRatio > 0, "Minimum reserve ratio must be positive");
        require(maxYieldAllocation <= 5000, "Max yield allocation too high"); // Max 50%
        require(emergencyWithdrawalLimit <= 5000, "Emergency withdrawal limit too high"); // Max 50%
        
        _targetReserveRatio = targetReserveRatio;
        _minReserveRatio = minReserveRatio;
        _maxYieldAllocation = maxYieldAllocation;
        _emergencyWithdrawalLimit = emergencyWithdrawalLimit;
    }
    
    /**
     * @dev Add supported stablecoin
     */
    function addSupportedStablecoin(address token) external onlyOwner {
        require(token != address(0), "Invalid token address");
        _supportedStablecoins[token] = true;
    }
    
    /**
     * @dev Remove supported stablecoin
     */
    function removeSupportedStablecoin(address token) external onlyOwner {
        _supportedStablecoins[token] = false;
    }
    
    /**
     * @dev Add yield strategy
     */
    function addYieldStrategy(address strategy, uint256 allocation) external onlyOwner {
        require(strategy != address(0), "Invalid strategy address");
        require(allocation > 0 && allocation <= 5000, "Invalid allocation"); // Max 50%
        
        _yieldStrategies[strategy] = true;
        _strategyAllocations[strategy] = allocation;
        
        // TODO: In a real implementation, we would rebalance allocations
    }
    
    /**
     * @dev Remove yield strategy
     */
    function removeYieldStrategy(address strategy) external onlyOwner {
        _yieldStrategies[strategy] = false;
        _strategyAllocations[strategy] = 0;
        
        // TODO: In a real implementation, we would withdraw funds from this strategy
    }
    
    /**
     * @dev Force pool rebalancing
     */
    function forceRebalance() external onlyOwner {
        _checkAndRebalancePools();
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
     * @dev Receive function - allows receiving ETH
     */
    receive() external payable {
        // Add to claim pool by default
        _claimPool += msg.value;
        _totalCapitalAdded += msg.value;
        
        emit CapitalAdded(msg.sender, msg.value);
    }
}
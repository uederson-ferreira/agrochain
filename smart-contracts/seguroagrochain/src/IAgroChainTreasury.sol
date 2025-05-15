// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAgroChainTreasury
 * @dev Interface for the treasury management system
 */
interface IAgroChainTreasury {
    // Events
    event PremiumDeposited(uint256 indexed policyId, uint256 amount);
    event ClaimPaid(uint256 indexed policyId, address indexed recipient, uint256 amount);
    event RefundProcessed(uint256 indexed policyId, address indexed recipient, uint256 amount);
    event CapitalAdded(address indexed from, uint256 amount);
    event CapitalWithdrawn(address indexed to, uint256 amount);
    event YieldGenerated(uint256 amount);
    event RiskPoolRebalanced(uint256 timestamp, uint256 totalReserves);
    
    /**
     * @dev Deposit premium payment
     * @param policyId ID of the insurance policy
     * @return success Whether deposit was successful
     */
    function depositPremium(uint256 policyId) external payable returns (bool success);
    
    /**
     * @dev Process claim payment
     * @param policyId ID of the insurance policy
     * @param recipient Address to receive payment
     * @param amount Amount to be paid
     * @return success Whether payment was successful
     */
    function processClaim(uint256 policyId, address payable recipient, uint256 amount) external returns (bool success);
    
    /**
     * @dev Process policy refund
     * @param policyId ID of the insurance policy
     * @param recipient Address to receive refund
     * @param amount Amount to be refunded
     * @return success Whether refund was successful
     */
    function processRefund(uint256 policyId, address payable recipient, uint256 amount) external returns (bool success);
    
    /**
     * @dev Get current balance information
     * @return premiumPool Amount in the premium pool
     * @return claimPool Amount in the claim reserve pool
     * @return yieldPool Amount in the yield generation pool
     * @return totalBalance Total balance of all pools
     * @return totalClaims Total claims paid
     */
    function getBalanceInfo() external view returns (
        uint256 premiumPool,
        uint256 claimPool,
        uint256 yieldPool,
        uint256 totalBalance,
        uint256 totalClaims
    );
    
    /**
     * @dev Get financial health indicators
     * @return solvencyRatio Ratio of total assets to total liabilities
     * @return reserveRatio Ratio of claim reserves to total policy coverage
     * @return liquidityRatio Ratio of liquid assets to short-term liabilities
     */
    function getFinancialHealth() external view returns (
        uint256 solvencyRatio,
        uint256 reserveRatio,
        uint256 liquidityRatio
    );
}
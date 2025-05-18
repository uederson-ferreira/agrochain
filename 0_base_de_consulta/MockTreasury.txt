// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title MockTreasury
 * @dev Mock contract for testing AgroChainInsurance
 */
contract MockTreasury {
    uint256 public premiumReceived;
    uint256 public claimsPaid;
    uint256 public refundsPaid;
    
    function depositPremium(uint256 policyId) external payable returns (bool) {
        premiumReceived += msg.value;
        return true;
    }
    
    function processClaim(uint256 policyId, address payable recipient, uint256 amount) external returns (bool) {
        claimsPaid += amount;
        // In a real test environment, we would transfer funds
        // payable(recipient).transfer(amount);
        return true;
    }
    
    function processRefund(uint256 policyId, address payable recipient, uint256 amount) external returns (bool) {
        refundsPaid += amount;
        // In a real test environment, we would transfer funds
        // payable(recipient).transfer(amount);
        return true;
    }
    
    function getPremiumReceived() external view returns (uint256) {
        return premiumReceived;
    }
    
    function getClaimsPaid() external view returns (uint256) {
        return claimsPaid;
    }
    
    function getRefundsPaid() external view returns (uint256) {
        return refundsPaid;
    }
    
    // Mock functions for treasury health
    function getBalanceInfo() external view returns (
        uint256 premiumPool,
        uint256 claimPool,
        uint256 yieldPool,
        uint256 totalBalance,
        uint256 totalClaims
    ) {
        return (
            premiumReceived - refundsPaid, // Premium pool
            1000 ether - claimsPaid,       // Claim pool 
            100 ether,                     // Yield pool
            1100 ether + premiumReceived - claimsPaid - refundsPaid, // Total
            claimsPaid                     // Total claims
        );
    }
    
    function getFinancialHealth() external pure returns (
        uint256 solvencyRatio,
        uint256 reserveRatio,
        uint256 liquidityRatio
    ) {
        return (
            15000, // 150% solvency
            12000, // 120% reserve ratio
            20000  // 200% liquidity ratio
        );
    }
    
    function getRiskExposure() external pure returns (
        uint256 totalExposure,
        uint256 activePolicyCount,
        uint256 coverageToReserveRatio
    ) {
        return (
            500 ether, // Total exposure
            3,         // Active policy count
            5000       // Coverage to reserve ratio (50%)
        );
    }
    
    // Function to receive ETH
    receive() external payable {}
}
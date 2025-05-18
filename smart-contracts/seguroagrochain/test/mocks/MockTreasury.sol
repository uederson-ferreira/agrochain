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
    
    function depositPremium(uint256 /*policyId*/) external payable returns (bool) {
        premiumReceived += msg.value;
        return true;
    }
    
    function processClaim(uint256 /*policyId*/, address payable recipient, uint256 amount) external returns (bool) {
        require(address(this).balance >= amount, "Insufficient balance for claim");
        claimsPaid += amount;
        recipient.transfer(amount); // Transferindo ETH para o recipient
        return true;
    }
    
    function processRefund(uint256 /*policyId*/, address payable recipient, uint256 amount) external returns (bool) {
        require(address(this).balance >= amount, "Insufficient balance for refund");
        refundsPaid += amount;
        recipient.transfer(amount); // Transferindo ETH para o recipient
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
    
    function getBalanceInfo() external view returns (
        uint256 premiumPool,
        uint256 claimPool,
        uint256 yieldPool,
        uint256 totalBalance,
        uint256 totalClaims
    ) {
        return (
            premiumReceived - refundsPaid,
            1000 ether - claimsPaid,
            100 ether,
            address(this).balance,
            claimsPaid
        );
    }
    
    function getFinancialHealth() external pure returns (
        uint256 solvencyRatio,
        uint256 reserveRatio,
        uint256 liquidityRatio
    ) {
        return (
            15000,
            12000,
            20000
        );
    }
    
    function getRiskExposure() external pure returns (
        uint256 totalExposure,
        uint256 activePolicyCount,
        uint256 coverageToReserveRatio
    ) {
        return (
            500 ether,
            3,
            5000
        );
    }
    
    receive() external payable {}
}
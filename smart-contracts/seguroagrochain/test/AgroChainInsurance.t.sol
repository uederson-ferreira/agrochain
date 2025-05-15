// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/AgroChainInsurance.sol";
import "./mocks/MockOracle.sol";
import "./mocks/MockTreasury.sol";

contract AgroChainInsuranceTest is Test {
    AgroChainInsurance insurance;
    MockOracle oracle;
    MockTreasury treasury;
    
    address owner = address(1);
    address farmer = address(2);
    address governance = address(3);
    
    function setUp() public {
        // Deploy mock contracts
        oracle = new MockOracle();
        treasury = new MockTreasury();
        
        // Deploy insurance contract
        vm.startPrank(owner);
        insurance = new AgroChainInsurance();
        
        // Inicializa com os 3 parâmetros requeridos
        insurance.initialize(
            address(oracle),
            address(treasury),
            governance
        );
        
        // Add supported region and crop
        insurance.addSupportedRegion("Bahia");
        insurance.addSupportedCrop("Soja");
        
        // Set regional oracles
        address[] memory oracleAddresses = new address[](1);
        oracleAddresses[0] = address(oracle);
        insurance.setRegionalOracles("Bahia", oracleAddresses);
        
        vm.stopPrank();
    }
    
    function testCreatePolicy() public {
        // Prepare policy parameters
        address payable _farmer = payable(farmer);
        uint256 _coverageAmount = 100 ether;
        uint256 _startDate = block.timestamp + 1 days;
        uint256 _endDate = block.timestamp + 30 days;
        string memory _region = "Bahia";
        string memory _cropType = "Soja";
        
        IAgroChainInsurance.ClimateParameter[] memory parameters = new IAgroChainInsurance.ClimateParameter[](1);
        parameters[0] = IAgroChainInsurance.ClimateParameter({
            parameterType: "rainfall",
            thresholdValue: 50, // 50mm
            periodInDays: 30,
            triggerAbove: false,
            payoutPercentage: 5000 // 50%
        });
        
        // Create policy
        vm.prank(owner);
        uint256 policyId = insurance.createPolicy(
            _farmer,
            _coverageAmount,
            _startDate,
            _endDate,
            _region,
            _cropType,
            parameters
        );
        
        // Verify policy was created
        assertEq(policyId, 1, "Policy ID should be 1");
        
        // Get policy details and verify
        (IAgroChainInsurance.Policy memory policy, IAgroChainInsurance.ClimateParameter[] memory policyParams) = insurance.getPolicyDetails(policyId);
        
        assertEq(policy.id, policyId, "Policy ID mismatch");
        assertEq(policy.farmer, _farmer, "Farmer address mismatch");
        assertEq(policy.coverageAmount, _coverageAmount, "Coverage amount mismatch");
        assertEq(policy.startDate, _startDate, "Start date mismatch");
        assertEq(policy.endDate, _endDate, "End date mismatch");
        assertEq(policy.active, false, "Policy should not be active yet");
        assertEq(policy.claimed, false, "Policy should not be claimed yet");
        assertEq(policy.region, _region, "Region mismatch");
        assertEq(policy.cropType, _cropType, "Crop type mismatch");
        
        // Verify climate parameters
        assertEq(policyParams.length, 1, "Should have 1 climate parameter");
        assertEq(policyParams[0].parameterType, "rainfall", "Parameter type mismatch");
        assertEq(policyParams[0].thresholdValue, 50, "Threshold value mismatch");
        assertEq(policyParams[0].periodInDays, 30, "Period mismatch");
        assertEq(policyParams[0].triggerAbove, false, "Trigger above flag mismatch");
        assertEq(policyParams[0].payoutPercentage, 5000, "Payout percentage mismatch");
    }
    
    function testActivatePolicy() public {
        // First create a policy
        testCreatePolicy();
        
        uint256 policyId = 1;
        
        // Get policy premium
        (IAgroChainInsurance.Policy memory policy, ) = insurance.getPolicyDetails(policyId);
        uint256 premium = policy.premium;
        
        // Activate policy
        vm.deal(farmer, premium); // Give farmer some ETH
        vm.prank(farmer);
        insurance.activatePolicy{value: premium}(policyId);
        
        // Verify policy is active
        (policy, ) = insurance.getPolicyDetails(policyId);
        assertEq(policy.active, true, "Policy should be active");
        
        // Verify treasury received premium
        assertEq(treasury.getPremiumReceived(), premium, "Treasury did not receive premium");
    }
    
    function testRequestClimateData() public {
        // First create and activate a policy
        testActivatePolicy();
        
        uint256 policyId = 1;
        
        // Move time to after policy start
        vm.warp(block.timestamp + 2 days);
        
        // Request climate data
        vm.prank(farmer);
        bytes32 requestId = insurance.requestClimateData(policyId, "rainfall");
        
        // Verify request was sent to oracle
        assertEq(oracle.lastPolicyId(), policyId, "Oracle did not receive policy ID");
        assertEq(oracle.lastParameterType(), "rainfall", "Oracle did not receive parameter type");
    }
    
    function testProcessClaim() public {
        // First create and activate a policy
        testActivatePolicy();
        
        uint256 policyId = 1;
        
        // Move time to after policy start
        vm.warp(block.timestamp + 2 days);
        
        // Request climate data
        vm.prank(farmer);
        bytes32 requestId = insurance.requestClimateData(policyId, "rainfall");
        
        // Create mock climate data (below threshold - should trigger)
        IAgroChainInsurance.ClimateData memory climateData = IAgroChainInsurance.ClimateData({
            requestId: requestId,
            parameterType: "rainfall",
            measuredValue: 30, // Below 50mm threshold
            timestamp: block.timestamp,
            dataSource: "Mock Oracle",
            signature: bytes("mock_signature")
        });
        
        // Process claim
        vm.prank(address(oracle));
        (bool success, uint256 amount) = insurance.processClaim(policyId, climateData);
        
        // Verify claim was processed successfully
        assertTrue(success, "Claim processing failed");
        
        // Get policy coverage and expected payout
        (IAgroChainInsurance.Policy memory policy, IAgroChainInsurance.ClimateParameter[] memory parameters) = insurance.getPolicyDetails(policyId);
        uint256 expectedPayout = (policy.coverageAmount * parameters[0].payoutPercentage) / 10000;
        
        // Verify payout amount
        assertEq(amount, expectedPayout, "Payout amount mismatch");
        
        // Verify policy status
        (policy, ) = insurance.getPolicyDetails(policyId);
        assertTrue(policy.claimed, "Policy should be marked as claimed");
        assertEq(policy.claimPaid, expectedPayout, "Claim paid amount mismatch");
        
        // Verify treasury processed payment
        assertEq(treasury.getClaimsPaid(), expectedPayout, "Treasury did not process claim payment");
    }
    
    function testCancelPolicy() public {
        // First create and activate a policy
        testActivatePolicy();
        
        uint256 policyId = 1;
        
        // Get policy premium
        (IAgroChainInsurance.Policy memory policy, ) = insurance.getPolicyDetails(policyId);
        uint256 premium = policy.premium;
        
        // Cancel policy
        vm.prank(farmer);
        uint256 refundAmount = insurance.cancelPolicy(policyId);
        
        // Calculate expected refund (premium minus cancellation fee)
        uint256 cancellationFeePercentage = 2000; // 20% (from AgroChainTreasury)
        uint256 expectedRefund = premium - ((premium * cancellationFeePercentage) / 10000);
        
        // Verify refund amount
        assertEq(refundAmount, expectedRefund, "Refund amount mismatch");
        
        // Verify policy is no longer active
        (policy, ) = insurance.getPolicyDetails(policyId);
        assertEq(policy.active, false, "Policy should not be active");
        
        // Verify treasury processed refund
        assertEq(treasury.getRefundsPaid(), expectedRefund, "Treasury did not process refund");
    }
    
    // Alterado de testFailCreatePolicyWithInvalidParameters para test_RevertWhen_CreatePolicyWithInvalidParameters
    function test_RevertWhen_CreatePolicyWithInvalidParameters() public {
        // Prepare policy parameters with invalid region
        address payable _farmer = payable(farmer);
        uint256 _coverageAmount = 100 ether;
        uint256 _startDate = block.timestamp + 1 days;
        uint256 _endDate = block.timestamp + 30 days;
        string memory _region = "InvalidRegion";
        string memory _cropType = "Soja";
        
        IAgroChainInsurance.ClimateParameter[] memory parameters = new IAgroChainInsurance.ClimateParameter[](1);
        parameters[0] = IAgroChainInsurance.ClimateParameter({
            parameterType: "rainfall",
            thresholdValue: 50,
            periodInDays: 30,
            triggerAbove: false,
            payoutPercentage: 5000
        });
        
        // Expect the transaction to revert
        vm.expectRevert();
        
        // Create policy - should fail due to invalid region
        vm.prank(owner);
        insurance.createPolicy(
            _farmer,
            _coverageAmount,
            _startDate,
            _endDate,
            _region,
            _cropType,
            parameters
        );
    }
    
    // Alterado de testFailActivatePolicyWithInsufficientFunds para test_RevertWhen_ActivatePolicyWithInsufficientFunds
    function test_RevertWhen_ActivatePolicyWithInsufficientFunds() public {
        // First create a policy
        testCreatePolicy();
        
        uint256 policyId = 1;
        
        // Expect the transaction to revert due to insufficient funds
        vm.expectRevert();
        
        // Try to activate with insufficient funds
        vm.deal(farmer, 0.1 ether); // Not enough ETH
        vm.prank(farmer);
        insurance.activatePolicy{value: 0.1 ether}(policyId);
    }
    
    function testGetPolicyStatus() public {
        // First create and activate a policy
        testActivatePolicy();
        
        uint256 policyId = 1;
        
        // Get policy status
        (
            bool active,
            bool claimed,
            uint256 claimPaid,
            uint256 remainingCoverage,
            uint256 timeRemaining
        ) = insurance.getPolicyStatus(policyId);
        
        // Verify status
        assertTrue(active, "Policy should be active");
        assertFalse(claimed, "Policy should not be claimed");
        assertEq(claimPaid, 0, "No claims should be paid yet");
        
        // Get policy details
        (IAgroChainInsurance.Policy memory policy, ) = insurance.getPolicyDetails(policyId);
        
        // Verify remaining coverage
        assertEq(remainingCoverage, policy.coverageAmount, "Remaining coverage should equal total coverage");
        
        // Verify time remaining
        assertEq(timeRemaining, policy.endDate - block.timestamp, "Time remaining mismatch");
    }
}
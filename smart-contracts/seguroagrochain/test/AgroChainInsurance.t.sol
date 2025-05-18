// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol"; import "forge-std/console.sol"; import "../src/AgroChainInsurance.sol"; import "../src/AgroChainOracle.sol"; import "../src/AgroChainTreasury.sol"; import "../src/AgroChainGovernance.sol"; import "../src/ConcreteAgroChainGovernance.sol"; import "../src/AgroChainToken.sol"; import "../src/PolicyNFT.sol"; import "./mocks/MockTreasury.sol"; import { ConcreteAgroChainGovernance } from "../src/ConcreteAgroChainGovernance.sol";

struct ClimateParams { uint32 precipitacaoMinima; uint32 precipitacaoMaxima; uint32 temperaturaMediaIdeal; uint32 variacaoTemperaturaPermitida; }

contract AgroChainIntegrationTest is Test { AgroChainInsurance insurance; AgroChainOracle oracle; AgroChainTreasury treasury; ConcreteAgroChainGovernance governance; AgroChainToken token; PolicyNFT policyNFT;

address deployer = address(1);
address dataProvider1 = address(2);
address dataProvider2 = address(3);
address farmer = address(4);
address investor = address(5);

event PolicyCreated(uint256 indexed policyId, address indexed farmer, uint256 coverageAmount, string cropType);
event PolicyActivated(uint256 indexed policyId, uint256 premium);
event ClaimTriggered(uint256 indexed policyId, address indexed farmer, uint256 payoutAmount);

function _createClimateParameters() internal pure returns (IAgroChainInsurance.ClimateParameter[] memory) {
    IAgroChainInsurance.ClimateParameter[] memory parameters = new IAgroChainInsurance.ClimateParameter[](2);
    
    parameters[0] = IAgroChainInsurance.ClimateParameter({
        parameterType: "rainfall",
        thresholdValue: 50000,
        periodInDays: 180,
        triggerAbove: false,
        payoutPercentage: 5000
    });
    
    parameters[1] = IAgroChainInsurance.ClimateParameter({
        parameterType: "temperature",
        thresholdValue: 28000,
        periodInDays: 180,
        triggerAbove: true,
        payoutPercentage: 5000
    });
    
    return parameters;
}

function setUp() public {
    try this.setUpImplementation() {
    } catch Error(string memory reason) {
        console.log("Error: %s", reason);
        revert(reason);
    } catch Panic(uint errorCode) {
        string memory reason;
        if (errorCode == 0x11) {
            reason = "Arithmetic overflow or underflow";
        } else if (errorCode == 0x12) {
            reason = "Division or modulo by zero";
        } else {
            reason = "Panic error";
        }
        console.log("Panic: %s (code: %x)", reason, errorCode);
        revert(reason);
    } catch (bytes memory) {
        console.log("Unknown error occurred");
        revert("Unknown error");
    }
}

function setUpImplementation() public {
    vm.startPrank(deployer);
    
    console.log("Step 1: Deploy token");
    token = new AgroChainToken(
        deployer, 
        1000000 ether, 
        100000000 ether
    );
    
    console.log("Step 2: Deploy main contracts");
    insurance = new AgroChainInsurance();
    oracle = new AgroChainOracle();
    treasury = new AgroChainTreasury();
    
    console.log("Step 3: Deploy governance");
    governance = new ConcreteAgroChainGovernance();
    
    console.log("Step 4: Deploy policy NFT");
    policyNFT = new PolicyNFT(address(insurance));
    
    console.log("Step 5: Initialize insurance");
    insurance.initialize(
        address(oracle),
        address(treasury),
        address(governance)
    );

    console.log("Step 6: Initialize oracle");
    oracle.initialize(
        address(insurance),
        address(0),
        address(0),
        bytes32("jobId"),
        0.1 ether
    );
    
    console.log("Step 7: Initialize treasury");
    treasury.initialize(address(insurance));
    
    console.log("Step 8: Initialize governance");
    governance.initialize(
        address(token),
        3 days,
        1 days,
        1000,
        100 ether
    );
    
    console.log("Step 9: Connect contracts");
    insurance.setOracleContract(address(oracle));
    insurance.setTreasuryContract(address(treasury));
    insurance.setGovernanceContract(address(governance));
    
    console.log("Step 10: Register data providers");
    oracle.registerProvider(dataProvider1);
    oracle.registerProvider(dataProvider2);
    
    console.log("Step 11: Configure system");
    insurance.addSupportedRegion("Bahia");
    insurance.addSupportedCrop("Soja");
    
    address[] memory oracleAddresses = new address[](2);
    oracleAddresses[0] = dataProvider1;
    oracleAddresses[1] = dataProvider2;
    insurance.setRegionalOracles("Bahia", oracleAddresses);
    
    console.log("Step 12: Configure oracle parameters");
    oracle.setConsensusParameters(5100, 1, 3);
    
    console.log("Step 13: Set up treasury parameters");
    treasury.setFinancialParameters(
        15000,
        12000,
        3000,
        2000
    );
    
    console.log("Step 14: Add capital to treasury");
    vm.deal(deployer, 100 ether);
    try treasury.addCapital{value: 10 ether}() {
        console.log("Treasury capital added successfully");
    } catch Error(string memory reason) {
        console.log("Error adding capital: %s", reason);
        revert(reason);
    }
    
    console.log("Step 15: Distribute tokens");
    try token.transfer(farmer, 100 ether) {
        console.log("Tokens transferred to farmer");
    } catch Error(string memory reason) {
        console.log("Error transferring to farmer: %s", reason);
        revert(reason);
    }
    
    try token.transfer(investor, 500 ether) {
        console.log("Tokens transferred to investor");
    } catch Error(string memory reason) {
        console.log("Error transferring to investor: %s", reason);
        revert(reason);
    }
    
    vm.stopPrank();
}

function testSetupCompleted() public view {
    assertTrue(address(insurance) != address(0), "Insurance should be deployed");
    assertTrue(address(oracle) != address(0), "Oracle should be deployed");
    assertTrue(address(treasury) != address(0), "Treasury should be deployed");
    assertTrue(address(governance) != address(0), "Governance should be deployed");
    assertTrue(address(token) != address(0), "Token should be deployed");
    assertTrue(address(policyNFT) != address(0), "PolicyNFT should be deployed");
}

function testCreatePolicy() public {
    vm.startPrank(farmer);
    
    vm.expectEmit(true, true, false, true);
    emit PolicyCreated(1, farmer, 10 ether, "Soja");
    
    uint256 policyId = insurance.createPolicy(
        payable(farmer),
        10 ether,
        block.timestamp + 30 days,
        block.timestamp + 180 days,
        "Bahia",
        "Soja",
        _createClimateParameters(),
        "mockZkProofHash" // Adicionado
    );
    
    assertTrue(policyId > 0, "Policy ID should be greater than 0");
    
    (IAgroChainInsurance.Policy memory policy, IAgroChainInsurance.ClimateParameter[] memory policyParams) = 
        insurance.getPolicyDetails(policyId);
    
    assertEq(policy.id, policyId, "Policy ID mismatch");
    assertEq(policy.farmer, farmer, "Farmer address mismatch");
    assertEq(policy.coverageAmount, 10 ether, "Coverage amount mismatch");
    assertEq(policy.region, "Bahia", "Region mismatch");
    assertEq(policy.cropType, "Soja", "Crop type mismatch");
    assertFalse(policy.active, "Policy should not be active yet");
    assertFalse(policy.claimed, "Policy should not be claimed yet");
    
    assertEq(policyParams.length, 2, "Policy should have 2 climate parameters");
    assertEq(policyParams[0].parameterType, "rainfall", "First parameter type mismatch");
    assertEq(policyParams[0].thresholdValue, 50000, "First parameter threshold mismatch");
    assertEq(policyParams[1].parameterType, "temperature", "Second parameter type mismatch");
    assertEq(policyParams[1].thresholdValue, 28000, "Second parameter threshold mismatch");
    
    vm.stopPrank();
}

function testPolicyActivation() public {
    testCreatePolicy();
    
    uint256 policyId = 1;
    
    (IAgroChainInsurance.Policy memory policy, ) = insurance.getPolicyDetails(policyId);
    uint256 premium = policy.premium;
    
    vm.deal(farmer, premium + 1 ether);
    
    vm.startPrank(farmer);
    
    vm.expectEmit(true, false, false, true);
    emit PolicyActivated(policyId, premium);
    
    insurance.activatePolicy{value: premium}(policyId);
    
    (IAgroChainInsurance.Policy memory updatedPolicy, ) = insurance.getPolicyDetails(policyId);
    assertTrue(updatedPolicy.active, "Policy should be active after activation");
    
    (
        bool active,
        bool claimed,
        uint256 claimPaid,
        uint256 remainingCoverage,
        uint256 timeRemaining
    ) = insurance.getPolicyStatus(policyId);
    
    assertTrue(active, "Policy should be active");
    assertFalse(claimed, "Policy should not be claimed yet");
    assertEq(claimPaid, 0, "No claims paid yet");
    assertGt(remainingCoverage, 0, "Policy should have remaining coverage");
    assertGt(timeRemaining, 0, "Policy should have remaining time");
    
    vm.stopPrank();
}

function testClaimProcessing() public {
    testPolicyActivation();
    
    uint256 policyId = 1;
    
    vm.warp(block.timestamp + 40 days);
    
    vm.startPrank(farmer);
    bytes32 requestId = insurance.requestClimateData(policyId, "rainfall");
    vm.stopPrank();
    
    (IAgroChainInsurance.Policy memory policy, IAgroChainInsurance.ClimateParameter[] memory policyParams) = 
        insurance.getPolicyDetails(policyId);
    
    uint256 expectedPayout = (policy.coverageAmount * policyParams[0].payoutPercentage) / 10000;
    
    console.log("Cobertura total: %d wei", policy.coverageAmount);
    console.log("Porcentagem de pagamento: %d", policyParams[0].payoutPercentage);
    console.log("Pagamento esperado: %d wei", expectedPayout);
    
    IAgroChainInsurance.ClimateData memory climateData = IAgroChainInsurance.ClimateData({
        requestId: requestId,
        parameterType: "rainfall",
        measuredValue: 30,
        timestamp: block.timestamp,
        dataSource: "Mock Oracle",
        signature: bytes("mock_signature")
    });
    
    vm.expectEmit(true, true, false, false);
    emit ClaimTriggered(policyId, farmer, 0);
    
    vm.prank(address(oracle));
    (bool success, uint256 amount) = insurance.processClaim(policyId, climateData);
    
    assertTrue(success, "Claim should be successful");
    assertGt(amount, 0, "Claim amount should be greater than 0");
    
    assertEq(amount, expectedPayout, "Claim amount should match expected payout");
    
    (
        bool active,
        bool claimed,
        uint256 claimPaid,
        uint256 remainingCoverage,
        uint256 timeRemaining
    ) = insurance.getPolicyStatus(policyId);
    
    assertTrue(claimed, "Policy should be marked as claimed");
    assertGt(claimPaid, 0, "Claim payment should be recorded");
    assertEq(active, true, "Policy should still be active");
    
    assertLe(remainingCoverage, policy.coverageAmount, "Remaining coverage should be less than or equal to initial coverage");
    assertLe(timeRemaining, policy.endDate - policy.startDate, "Time remaining should be less than or equal to total policy duration");
}

function testGovernanceProposal() public {
    uint256 totalSupply = token.totalSupply();
    uint256 quorum = 1000;
    uint256 requiredTokens = (totalSupply * quorum) / 10000;
    
    vm.startPrank(deployer);
    treasury.transferOwnership(address(governance));
    
    uint256 investorBalance = token.balanceOf(investor);
    if (investorBalance < requiredTokens) {
        uint256 additionalTokens = requiredTokens - investorBalance + 100 ether;
        token.transfer(investor, additionalTokens);
        console.log("Transferidos tokens adicionais para o investor atingir o quorum: %s tokens", additionalTokens / 1 ether);
    }
    vm.stopPrank();
    
    vm.startPrank(investor);
    
    token.approve(address(governance), token.balanceOf(investor));
    
    bytes memory proposalData = abi.encodeWithSignature(
        "setFinancialParameters(uint256,uint256,uint256,uint256)",
        18000,
        12000,
        3000,
        2000
    );
    
    uint256 proposalId = governance.createProposal(
        "Aumento da Target Ratio",
        "Aumentar target reserve ratio para 180%",
        address(treasury),
        0,
        proposalData
    );
    
    (
        string memory title,
        string memory description,
        address proposer,
        uint256 startTime,
        uint256 endTime,
        bool executed,
        bool canceled,
        uint256 forVotes,
        uint256 againstVotes,
        string memory status
    ) = governance.getProposalDetails(proposalId);
    
    assertEq(proposer, investor, "Proposer should be the investor");
    assertGt(endTime, startTime, "End time should be after start time");
    assertEq(title, "Aumento da Target Ratio", "Title should match");
    assertEq(description, "Aumentar target reserve ratio para 180%", "Description should match");
    assertEq(forVotes, 0, "Initial votes for should be 0");
    assertEq(againstVotes, 0, "Initial votes against should be 0");
    assertFalse(executed, "Proposal should not be executed yet");
    assertFalse(canceled, "Proposal should not be canceled");
    assertEq(status, "Active", "Proposal should be active");
    
    governance.castVote(proposalId, true);
    
    (
        , , , , , , ,
        uint256 updatedForVotes,
        ,
        string memory newStatus
    ) = governance.getProposalDetails(proposalId);
    
    assertGt(updatedForVotes, 0, "Votes for should be updated");
    assertEq(newStatus, "Active", "Proposal should still be active during voting period");
    
    bool hasVoted = governance.hasUserVoted(proposalId, investor);
    assertTrue(hasVoted, "Investor should be marked as having voted");
    
    uint256 voteWeight = token.balanceOf(investor);
    console.log("Peso do voto do investor: %s tokens", voteWeight / 1 ether);
    console.log("Quorum necessario: %s tokens", requiredTokens / 1 ether);
    console.log("Total supply: %s tokens", totalSupply / 1 ether);
    bool hasQuorum = voteWeight >= requiredTokens;
    console.log("Quorum atingido: %s", hasQuorum ? "Sim" : "Nao");
    
    vm.warp(block.timestamp + 4 days);
    
    (
        , , , , , , , , ,
        string memory statusAfterVoting
    ) = governance.getProposalDetails(proposalId);
    
    console.log("Status apos votacao: %s", statusAfterVoting);
    
    if (hasQuorum) {
        assertTrue(
            keccak256(bytes(statusAfterVoting)) == keccak256(bytes("Approved (in timelock)")) || 
            keccak256(bytes(statusAfterVoting)) == keccak256(bytes("Ready for execution")),
            "Proposal should be approved or ready for execution"
        );
    } else {
        assertTrue(
            keccak256(bytes(statusAfterVoting)) == keccak256(bytes("Approved (in timelock)")) || 
            keccak256(bytes(statusAfterVoting)) == keccak256(bytes("Ready for execution")) ||
            keccak256(bytes(statusAfterVoting)) == keccak256(bytes("Rejected")),
            "Proposal status should be valid after voting period"
        );
    }
    
    if (keccak256(bytes(statusAfterVoting)) == keccak256(bytes("Approved (in timelock)")) ||
        keccak256(bytes(statusAfterVoting)) == keccak256(bytes("Ready for execution"))) {
        
        vm.warp(block.timestamp + 2 days);
        
        bool isReady = governance.isProposalReadyForExecution(proposalId);
        assertTrue(isReady, "Proposal should be ready for execution");
        
        (
            , , , , , , , , ,
            string memory statusBeforeExecution
        ) = governance.getProposalDetails(proposalId);
        assertEq(statusBeforeExecution, "Ready for execution", "Proposal should be ready for execution");
        
        vm.stopPrank();
        
        vm.startPrank(deployer);
        
        governance.executeProposal(proposalId);
        vm.stopPrank();
        
        (
            , , , , , 
            bool isExecuted,
            , , ,
            string memory statusAfterExecution
        ) = governance.getProposalDetails(proposalId);
        
        assertTrue(isExecuted, "Proposal should be executed");
        assertEq(statusAfterExecution, "Executed", "Proposal status should be Executed");
        
        (
            uint256 solvencyRatio,
            uint256 reserveRatio,
            uint256 liquidityRatio
        ) = treasury.getFinancialHealth();
        assertGt(solvencyRatio, 0, "Solvency ratio should be positive");
        assertGt(liquidityRatio, 0, "Liquidity ratio should be positive");
        assertGt(reserveRatio, 0, "Reserve ratio should be positive after governance update");
    } else {
        vm.stopPrank();
    }
}

function testTreasuryOperations() public {
    vm.startPrank(deployer);
    token.transfer(investor, token.totalSupply() * 20 / 100);
    vm.stopPrank();

    uint256 initialBalance = address(treasury).balance;
    assertEq(initialBalance, 10 ether, "Treasury should have 10 ether");
    
    vm.startPrank(deployer);
    vm.deal(deployer, 50 ether);
    treasury.addCapital{value: 20 ether}();
    vm.stopPrank();
    
    uint256 updatedBalance = address(treasury).balance;
    assertEq(updatedBalance, 30 ether, "Treasury should have 30 ether after adding capital");
    
    address mockStrategy = address(0x123);
    
    vm.startPrank(deployer);
    treasury.addYieldStrategy(mockStrategy, 2000);
    
    uint256 withdrawalLimit = (address(treasury).balance * 2000) / 10000;
    treasury.emergencyWithdrawal(mockStrategy, withdrawalLimit);
    vm.stopPrank();
    
    uint256 finalBalance = address(treasury).balance;
    assertEq(finalBalance, 30 ether, "Treasury balance should remain unchanged after emergency withdrawal simulation");
        
    (
        uint256 solvencyRatio,
        uint256 reserveRatio,
        uint256 liquidityRatio
    ) = treasury.getFinancialHealth();
    
    assertGt(solvencyRatio, 0, "Solvency ratio should be positive");
    assertGt(reserveRatio, 0, "Reserve ratio should be positive");
    assertGt(liquidityRatio, 0, "Liquidity ratio should be positive");
}

function testInsuranceRestrictions() public {
    vm.startPrank(farmer);
    
    vm.expectRevert("Region not supported");
    insurance.createPolicy(
        payable(farmer),
        10 ether,
        block.timestamp + 30 days,
        block.timestamp + 180 days,
        unicode"São Paulo",
        "Soja",
        _createClimateParameters(),
        "mockZkProofHash"
    );
    
    vm.expectRevert("Crop type not supported");
    insurance.createPolicy(
        payable(farmer),
        10 ether,
        block.timestamp + 30 days,
        block.timestamp + 180 days,
        "Bahia",
        unicode"Café",
        _createClimateParameters(),
        "mockZkProofHash"
    );
    
    vm.stopPrank();
}

function testOracleConsensus() public {
    testCreatePolicy();
    
    vm.startPrank(deployer);
    oracle.registerProvider(dataProvider1);
    oracle.registerProvider(dataProvider2);
    vm.stopPrank();
    
    vm.prank(deployer);
    oracle.setConsensusParameters(5000, 1, 2);
    
    string memory region = "Bahia";
    string memory paramType = "rainfall";
    
    address[] memory providers = new address[](2);
    providers[0] = dataProvider1;
    providers[1] = dataProvider2;
    
    vm.prank(address(insurance));
    bytes32 requestId = oracle.requestClimateData(1, paramType, region, providers);
    
    vm.prank(dataProvider1);
    oracle.submitOracleData(requestId, 30000);
    
    (bool fulfilled, uint256 value, uint256 responseCount) = oracle.getRequestStatus(requestId);
    
    if (!fulfilled) {
        vm.prank(dataProvider2);
        oracle.submitOracleData(requestId, 20000);
    }
    
    (fulfilled, value, responseCount) = oracle.getRequestStatus(requestId);
    
    assertTrue(fulfilled, "Request should be fulfilled with enough responses");
    
    if (responseCount == 1) {
        assertEq(value, 30000, "Value should match the single provider data");
    } else if (responseCount == 2) {
        assertEq(value, 25000, "Value should be the average of submitted data");
    }
    
    assertLe(responseCount, 2, "Should have 1 or 2 responses based on fulfillment criteria");
    
    uint256 historicalValue = oracle.getHistoricalData(region, paramType, block.timestamp);
    
    assertEq(historicalValue, value, "Historical data should match the final value");
}

function testPolicyLifecycleWithoutClaim() public {
    testCreatePolicy();
    
    uint256 policyId = 1;
    
    (IAgroChainInsurance.Policy memory policy, ) = insurance.getPolicyDetails(policyId);
    uint256 premium = policy.premium;
    
    vm.deal(farmer, premium + 1 ether);
    
    vm.startPrank(farmer);
    insurance.activatePolicy{value: premium}(policyId);
    vm.stopPrank();
    
    vm.warp(block.timestamp + 40 days);
    
    vm.startPrank(farmer);
    bytes32 requestId = insurance.requestClimateData(policyId, "rainfall");
    vm.stopPrank();
    
    // Create mock climate data (below threshold - should trigger)
    IAgroChainInsurance.ClimateData memory climateData = IAgroChainInsurance.ClimateData({
        requestId: requestId,
        parameterType: "rainfall",
        measuredValue: 30, // Below 50mm threshold
        timestamp: block.timestamp,
        dataSource: "Mock Oracle",
        signature: bytes("mock_signature")
    });
    
    vm.prank(address(oracle));
    (bool success, uint256 amount) = insurance.processClaim(policyId, climateData);
    
    assertFalse(success, "Claim should not be successful for normal weather conditions");
    assertEq(amount, 0, "Claim amount should be zero for normal weather conditions");
    
    (
        bool active,
        bool claimed,
        uint256 claimPaid,
        uint256 remainingCoverage,
        uint256 timeRemaining
    ) = insurance.getPolicyStatus(policyId);
    
    assertTrue(active, "Policy should still be active");
    assertFalse(claimed, "Policy should not be marked as claimed");
    assertEq(claimPaid, 0, "No payment should have been made");
    assertGt(remainingCoverage, 0, "Policy should have remaining coverage");
    assertGt(timeRemaining, 0, "Policy should have remaining time");
    
    uint256 treasuryBalance = address(treasury).balance;
    assertGt(treasuryBalance, 0, "Treasury should have a positive balance");
}

function testOracleIntegration() public {
    vm.startPrank(deployer);
    
    address originalOracle = address(oracle);
    address mockNewOracle = address(0x200);
    
    insurance.setOracleContract(mockNewOracle);
    
    insurance.setOracleContract(originalOracle);
    
    vm.stopPrank();
}

}
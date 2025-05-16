// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/AgroChainToken.sol";
import "../src/AgroChainInsurance.sol";
import "../src/AgroChainOracle.sol";
import "../src/AgroChainTreasury.sol";
import "../src/ConcreteAgroChainGovernance.sol";
import "../src/PolicyNFT.sol";

contract DeployScript is Script {
    function run() public {
        // Inicia a transmissão usando a chave privada fornecida via linha de comando
        vm.startBroadcast();
        
        // Obter o endereço do deployer
        address deployer = msg.sender;
        
        console.log("Deploying contracts from address:", deployer);
        
        // Deploy token
        AgroChainToken token = new AgroChainToken(
            deployer, 
            1000000 ether, 
            100000000 ether
        );
        
        // Deploy main contracts
        AgroChainInsurance insurance = new AgroChainInsurance();
        AgroChainOracle oracle = new AgroChainOracle();
        AgroChainTreasury treasury = new AgroChainTreasury();
        
        // Deploy governance
        ConcreteAgroChainGovernance governance = new ConcreteAgroChainGovernance();
        
        // Deploy policy NFT
        PolicyNFT policyNFT = new PolicyNFT(address(insurance));
        
        // Initialize contracts
        insurance.initialize(
            address(oracle),
            address(treasury),
            address(governance)
        );
        
        oracle.initialize(
            address(insurance),
            address(0), // No real Chainlink token for dev
            address(0), // No real Chainlink oracle for dev
            bytes32("jobId"),
            0.1 ether
        );
        
        treasury.initialize(address(insurance));
        
        governance.initialize(
            address(token),
            3 days, // Voting period
            1 days, // Execution delay
            1000, // 10% quorum
            100 ether // 100 tokens to create proposal
        );
        
        // Connect contracts
        insurance.setOracleContract(address(oracle));
        insurance.setTreasuryContract(address(treasury));
        insurance.setGovernanceContract(address(governance));
        
        // Configuration
        insurance.addSupportedRegion("Bahia");
        insurance.addSupportedCrop("Soja");
        
        vm.stopBroadcast();
        
        // Imprime os endereços dos contratos para referência
        console.log("Deployed contracts:");
        console.log("Token:", address(token));
        console.log("Insurance:", address(insurance));
        console.log("Oracle:", address(oracle));
        console.log("Treasury:", address(treasury));
        console.log("Governance:", address(governance));
        console.log("PolicyNFT:", address(policyNFT));
    }
}
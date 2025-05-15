// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AgroChainFactory} from "../src/AgroChainFactory.sol";
import {AgroChainInsurance} from "../src/AgroChainInsurance.sol";
import {AgroChainOracle} from "../src/AgroChainOracle.sol";
import {AgroChainTreasury} from "../src/AgroChainTreasury.sol";
import {AgroChainGovernance} from "../src/AgroChainGovernance.sol";
import {ConcreteAgroChainGovernance} from "../src/ConcreteAgroChainGovernance.sol";
import {AgroChainToken} from "../src/AgroChainToken.sol";
import {PolicyNFT as PolicyNFTContract} from "../src/PolicyNFT.sol";

/**
 * @title DeployScript
 * @dev Script para implantar todos os contratos do sistema AgroChain
 */
contract DeployScript is Script {
    function run() external {
        // Recupera a chave privada do ambiente ou usa uma padrão
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Inicia a transmissão de transações
        vm.startBroadcast(deployerPrivateKey);
        
        // Implanta os contratos

        // 1. Deploy AgroChainToken
        AgroChainToken token = new AgroChainToken(
            msg.sender,              // treasury inicial
            1000000 ether,          // fornecimento inicial
            100000000 ether         // cap de fornecimento
        );
        console.log("AgroChainToken implantado em:", address(token));
        
        // 2. Deploy AgroChainInsurance
        AgroChainInsurance insurance = new AgroChainInsurance();
        insurance.initialize(
            address(0), // Oracle - será configurado depois
            address(0), // Treasury - será configurado depois
            address(0)  // Governance - será configurado depois
        );
        console.log("AgroChainInsurance implantado em:", address(insurance));
        
        // 3. Deploy AgroChainOracle
        AgroChainOracle oracle = new AgroChainOracle();
        oracle.initialize(
            address(insurance),
            address(0),           // sem token chainlink para teste
            address(0),           // sem oracle chainlink para teste
            bytes32("jobId"),
            0.1 ether
        );
        console.log("AgroChainOracle implantado em:", address(oracle));
        
        // 4. Deploy AgroChainTreasury
        AgroChainTreasury treasury = new AgroChainTreasury();
        treasury.initialize(address(insurance));
        console.log("AgroChainTreasury implantado em:", address(treasury));
        
        // 5. Deploy AgroChainGovernance
        ConcreteAgroChainGovernance governanceImpl = new ConcreteAgroChainGovernance();
        AgroChainGovernance governance = AgroChainGovernance(payable(address(governanceImpl)));
        governance.initialize(
            address(token),
            3 days,              // período de votação
            1 days,              // delay de execução
            1000,                // quórum de 10%
            1000 ether           // threshold de proposta
        );
        console.log("AgroChainGovernance implantado em:", address(governance));
        
        // 6. Deploy PolicyNFT
        PolicyNFTContract policyNFT = new PolicyNFTContract(address(insurance));
        console.log("PolicyNFT implantado em:", address(policyNFT));
        
        // Conecta os contratos entre si
        insurance.setOracleContract(address(oracle));
        insurance.setTreasuryContract(address(treasury));
        insurance.setGovernanceContract(address(governance));
        
        // Configura parâmetros iniciais
        // Adiciona regiões suportadas
        insurance.addSupportedRegion("Bahia");
        insurance.addSupportedRegion("Mato Grosso");
        insurance.addSupportedRegion("Parana");
        
        // Adiciona culturas suportadas
        insurance.addSupportedCrop("Soja");
        insurance.addSupportedCrop("Milho");
        insurance.addSupportedCrop("Cafe");
        
        // Termina a transmissão
        vm.stopBroadcast();
        
        console.log("Implantacao concluida com sucesso!");
    }
}
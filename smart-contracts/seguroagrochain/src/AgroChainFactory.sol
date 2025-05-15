// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "./AgroChainInsurance.sol";
import "./AgroChainOracle.sol";
import "./AgroChainTreasury.sol";
import "./AgroChainGovernance.sol";
import "./AgroChainToken.sol";
import {PolicyNFT as PolicyNFTContract} from "./PolicyNFT.sol"; // Usando alias

/**
 * @title AgroChainFactory
 * @dev Factory contract to deploy and configure the entire AgroChain system
 * @notice This is used for initial deployment and setup
 */
contract AgroChainFactory {
    // Deployed contract addresses
    address public insuranceContract;
    address public oracleContract;
    address public treasuryContract;
    address public governanceContract;
    address public tokenContract;
    address public policyNFTContract; // Adicionado o contrato de PolicyNFT
    
    // Proxy admin
    ProxyAdmin public proxyAdmin;
    
    // Events
    event SystemDeployed(
        address insurance,
        address oracle,
        address treasury,
        address governance,
        address token,
        address policyNFT
    );
    
    /**
     * @dev Deploy the entire AgroChain system
     * @param initialOwner Address that will own the contracts
     * @param initialTokenSupply Initial supply of governance tokens
     * @param tokenCap Maximum cap for token supply
     * @param votingPeriod Duration of voting period in seconds
     * @param executionDelay Timelock between approval and execution
     * @param quorumThreshold Quorum threshold in basis points (e.g., 1000 = 10%)
     * @param proposalThreshold Minimum tokens required to create a proposal
     * @param chainlinkToken Chainlink token address for oracle
     * @param chainlinkOracle Chainlink oracle address
     * @param chainlinkJobId Chainlink job ID for weather data
     * @param chainlinkFee Chainlink fee in LINK tokens
     */
    function deployAgroChainSystem(
        address initialOwner,
        uint256 initialTokenSupply,
        uint256 tokenCap,
        uint256 votingPeriod,
        uint256 executionDelay,
        uint256 quorumThreshold,
        uint256 proposalThreshold,
        address chainlinkToken,
        address chainlinkOracle,
        bytes32 chainlinkJobId,
        uint256 chainlinkFee
    ) external returns (bool) {
        require(initialOwner != address(0), "Invalid owner address");
        
        // Create proxy admin
        proxyAdmin = new ProxyAdmin();
        
        // Transfer proxy admin ownership to the initial owner
        proxyAdmin.transferOwnership(initialOwner);
        
        // Deploy implementation contracts
        AgroChainInsurance insuranceImplementation = new AgroChainInsurance();
        AgroChainOracle oracleImplementation = new AgroChainOracle();
        AgroChainTreasury treasuryImplementation = new AgroChainTreasury();
        AgroChainGovernance governanceImplementation = AgroChainGovernance(payable(address(0)));
        
        // Deploy proxies
        bytes memory insuranceData = abi.encodeWithSelector(
            AgroChainInsurance(address(0)).initialize.selector,
            address(0), // oracle - será configurado depois
            address(0), // treasury - será configurado depois
            address(0)  // governance - será configurado depois
        );
        
        TransparentUpgradeableProxy insuranceProxy = new TransparentUpgradeableProxy(
            address(insuranceImplementation),
            address(proxyAdmin),
            insuranceData
        );
        insuranceContract = address(insuranceProxy);
        
        bytes memory treasuryData = abi.encodeWithSelector(
            AgroChainTreasury(payable(address(0))).initialize.selector,
            insuranceContract
        );
        
        TransparentUpgradeableProxy treasuryProxy = new TransparentUpgradeableProxy(
            address(treasuryImplementation),
            address(proxyAdmin),
            treasuryData
        );
        treasuryContract = address(treasuryProxy);
        
        bytes memory oracleData = abi.encodeWithSelector(
            AgroChainOracle(address(0)).initialize.selector,
            insuranceContract,
            chainlinkToken,
            chainlinkOracle,
            chainlinkJobId,
            chainlinkFee
        );
        
        TransparentUpgradeableProxy oracleProxy = new TransparentUpgradeableProxy(
            address(oracleImplementation),
            address(proxyAdmin),
            oracleData
        );
        oracleContract = address(oracleProxy);
        
        // Deploy governance token (not upgradeable)
        AgroChainToken token = new AgroChainToken(
            initialOwner,
            initialTokenSupply,
            tokenCap
        );
        tokenContract = address(token);
        
        bytes memory governanceData = abi.encodeWithSelector(
            AgroChainGovernance(payable(address(0))).initialize.selector,
            tokenContract,
            votingPeriod,
            executionDelay,
            quorumThreshold,
            proposalThreshold
        );
        
        // Deploy governance proxy
        TransparentUpgradeableProxy governanceProxy = new TransparentUpgradeableProxy(
            address(governanceImplementation),
            address(proxyAdmin),
            governanceData
        );
        governanceContract = address(governanceProxy);
        
        // Deploy PolicyNFT (não upgradeable)
        PolicyNFTContract policyNFT = new PolicyNFTContract(insuranceContract);
        policyNFTContract = address(policyNFT);
        
        // Connect contracts to each other
        AgroChainInsurance(insuranceContract).setOracleContract(oracleContract);
        AgroChainInsurance(insuranceContract).setTreasuryContract(treasuryContract);
        AgroChainInsurance(insuranceContract).setGovernanceContract(governanceContract);
        
        // Transfer ownership of all contracts to the initial owner
        Ownable(insuranceContract).transferOwnership(initialOwner);
        Ownable(oracleContract).transferOwnership(initialOwner);
        Ownable(treasuryContract).transferOwnership(initialOwner);
        Ownable(governanceContract).transferOwnership(initialOwner);
        Ownable(policyNFTContract).transferOwnership(initialOwner);
        
        emit SystemDeployed(
            insuranceContract,
            oracleContract,
            treasuryContract,
            governanceContract,
            tokenContract,
            policyNFTContract
        );
        
        return true;
    }
}
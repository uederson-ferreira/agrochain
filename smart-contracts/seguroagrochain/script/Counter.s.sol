// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/AgroChainInsurance.sol";

/**
 * @title CounterScript
 * @dev Script padrão para substituir o Counter.s.sol gerado automaticamente
 * Este script é apenas um placeholder, use Deploy.s.sol para implantação completa
 */
contract CounterScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
        
        // Apenas um exemplo simples para substituir o Counter.s.sol padrão
        AgroChainInsurance insurance = new AgroChainInsurance();
        console.log("Deployed AgroChainInsurance at:", address(insurance));
    }
}
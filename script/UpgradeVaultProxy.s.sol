// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {VaultToken} from "../src/VaultToken.sol";
import {VaultTokenV2} from "../src/VaultTokenV2.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title UpgradeVaultProxy
 * @notice Script para hacer upgrade de VaultToken V1 -> V2 (o cualquier versión)
 * @dev Proceso de upgrade:
 *      1. Deploy nueva implementación (ej: VaultTokenV2)
 *      2. Llamar upgradeToAndCall() en el PROXY
 *      3. Opcionalmente inicializar nuevas variables (initializeV2)
 * 
 * IMPORTANTE: 
 * - El upgrade solo puede ser ejecutado por el OWNER del vault
 * - La dirección del PROXY no cambia (usuarios siguen usando la misma)
 * - Los fondos y estado se mantienen intactos
 * - Solo cambia la lógica (implementación)
 */
contract UpgradeVaultProxy is Script {
    
    // ⚠️ CONFIGURAR ESTAS VARIABLES ANTES DE EJECUTAR
    address constant PROXY_ADDRESS = address(0); // ← Dirección del proxy existente
    
    function run() external {
        // Validar que se configuró la dirección del proxy
        require(PROXY_ADDRESS != address(0), "Configure PROXY_ADDRESS first!");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Wrap el proxy en la interfaz V1 para interactuar
        VaultToken vaultProxy = VaultToken(PROXY_ADDRESS);
        
        console.log("=== Upgrading VaultToken Proxy ===");
        console.log("Upgrader (must be owner):", deployer);
        console.log("Proxy Address:", PROXY_ADDRESS);
        console.log("Current Version:", vaultProxy.version());
        console.log("Current Implementation:", getImplementationAddress(PROXY_ADDRESS));
        console.log("Current Owner:", vaultProxy.owner());
        
        // Verificar que el deployer es el owner
        require(vaultProxy.owner() == deployer, "Deployer is not the owner!");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy la nueva implementación (V2)
        console.log("\n1. Deploying new implementation (V2)...");
        VaultTokenV2 newImplementation = new VaultTokenV2();
        console.log("New Implementation deployed at:", address(newImplementation));
        
        // 2. Preparar datos para inicializar V2 (si es necesario)
        bytes memory initData = abi.encodeWithSelector(
            VaultTokenV2.initializeV2.selector
        );
        
        // 3. Hacer el upgrade (llamar upgradeToAndCall en el PROXY)
        console.log("\n2. Upgrading proxy to new implementation...");
        vaultProxy.upgradeToAndCall(address(newImplementation), initData);
        
        console.log("Upgrade completed successfully!");
        
        vm.stopBroadcast();
        
        // 4. Verificar el upgrade
        console.log("\n=== Upgrade Verification ===");
        VaultTokenV2 upgradedVault = VaultTokenV2(PROXY_ADDRESS);
        console.log("Proxy Address (unchanged):", PROXY_ADDRESS);
        console.log("New Implementation:", getImplementationAddress(PROXY_ADDRESS));
        console.log("New Version:", upgradedVault.version());
        console.log("TVL (should be preserved):", upgradedVault.totalAssets());
        console.log("Owner (should be preserved):", upgradedVault.owner());
        
        // Verificar nuevas funcionalidades de V2
        console.log("\n=== New V2 Features ===");
        console.log("Current APY:", upgradedVault.currentAPY());
        console.log("Last APY Update:", upgradedVault.lastAPYUpdate());
        console.log("Total Profits Generated:", upgradedVault.totalProfitsGenerated());
        
        console.log("\n=== Next Steps ===");
        console.log("1. Verify new implementation on BaseScan:");
        console.log("   forge verify-contract", address(newImplementation), "src/VaultTokenV2.sol:VaultTokenV2");
        console.log("\n2. Test new V2 functions:");
        console.log("   - depositWithDeadline()");
        console.log("   - updateAPY()");
        console.log("   - getVaultInfo()");
        console.log("\n3. Update frontend to use new V2 ABI (if needed)");
    }
    
    /**
     * @notice Obtiene la dirección de la implementación actual del proxy
     * @param proxy Dirección del proxy
     * @return implementation Dirección de la implementación
     */
    function getImplementationAddress(address proxy) internal view returns (address) {
        // ERC1967 implementation slot
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        bytes32 implementationBytes = vm.load(proxy, slot);
        return address(uint160(uint256(implementationBytes)));
    }
}


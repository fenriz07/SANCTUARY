// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/VaultToken.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title UpgradeVault
 * @notice Script para hacer upgrade del vault usando patrón UUPS
 * @dev El vault debe estar desplegado con proxy UUPS
 */
contract UpgradeVault is Script {
    // Direcciones de los contratos existentes (configurar por red)
    address constant VAULT_PROXY_MAINNET = 0x1dBa528D6534477De47bCfeBfb1F196d433dc7F9;
    
    function run() external {
        // Determinar qué dirección de proxy usar
        address proxyAddress;
        
        if (block.chainid == 8453) {
            // Base Mainnet
            proxyAddress = VAULT_PROXY_MAINNET;
        } else {
            revert("Unsupported network");
        }
        
        console.log("==============================================");
        console.log("Upgrading VaultToken on network:", block.chainid);
        console.log("Proxy address:", proxyAddress);
        console.log("==============================================");
        console.log("");
        
        // Obtener la private key del deployer
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer:", deployer);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Desplegar nueva implementación
        console.log("1. Deploying new VaultToken implementation...");
        VaultToken newImplementation = new VaultToken();
        console.log("   New implementation:", address(newImplementation));
        console.log("");
        
        // 2. Verificar que el deployer es owner del proxy
        VaultToken proxy = VaultToken(proxyAddress);
        address currentOwner = proxy.owner();
        console.log("2. Verifying ownership...");
        console.log("   Current owner:", currentOwner);
        console.log("   Deployer:", deployer);
        
        if (currentOwner != deployer) {
            console.log("   ERROR: Deployer is not the owner!");
            revert("Deployer must be owner to upgrade");
        }
        console.log("   OK: Deployer is the owner");
        console.log("");
        
        // 3. Hacer upgrade usando upgradeToAndCall
        console.log("3. Upgrading proxy to new implementation...");
        proxy.upgradeToAndCall(address(newImplementation), "");
        console.log("   Upgrade successful!");
        console.log("");
        
        // 4. Verificar versión
        console.log("4. Verifying upgrade...");
        string memory newVersion = proxy.version();
        console.log("   New version:", newVersion);
        
        // Verificar que la nueva implementación es correcta
        address implementationAddress = _getImplementation(proxyAddress);
        console.log("   Implementation address:", implementationAddress);
        
        if (implementationAddress != address(newImplementation)) {
            console.log("   ERROR: Implementation mismatch!");
            revert("Upgrade verification failed");
        }
        console.log("   OK: Implementation upgraded successfully");
        console.log("");
        
        vm.stopBroadcast();
        
        console.log("==============================================");
        console.log("Upgrade completed successfully!");
        console.log("==============================================");
        console.log("");
        console.log("Summary:");
        console.log("  Proxy:", proxyAddress);
        console.log("  New Implementation:", address(newImplementation));
        console.log("  Version:", newVersion);
        console.log("");
        console.log("Next steps:");
        console.log("  1. Test withdrawal on mainnet");
        console.log("  2. Verify contract on BaseScan");
    }
    
    /**
     * @notice Obtiene la dirección de la implementación actual del proxy
     * @dev Lee el storage slot ERC1967 de la implementación
     */
    function _getImplementation(address proxy) internal view returns (address) {
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        bytes32 data = vm.load(proxy, slot);
        return address(uint160(uint256(data)));
    }
}


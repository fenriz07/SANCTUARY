// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {VaultToken} from "../src/VaultToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployVaultProxy
 * @notice Script para deployar VaultToken con patrón UUPS proxy
 * @dev Deploy proceso:
 *      1. Deploy implementación (VaultToken logic)
 *      2. Deploy proxy (ERC1967Proxy)
 *      3. Inicializar proxy con datos del vault
 *      4. El proxy queda apuntando a la implementación
 */
contract DeployVaultProxy is Script {
    
    // Configuración para Base Sepolia (testnet)
    address constant USDC_BASE_SEPOLIA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant TREASURY = address(0x8b710Fb249e087b52f20E6afAaDd9829c138D175); 
    
    // Configuración para Base Mainnet
    address constant USDC_BASE_MAINNET = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Deploying VaultToken with UUPS Proxy ===");
        console.log("Deployer:", deployer);
        console.log("Network:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy la implementación (logic contract)
        console.log("\n1. Deploying implementation...");
        VaultToken implementation = new VaultToken();
        console.log("Implementation deployed at:", address(implementation));
        
        // 2. Preparar datos de inicialización
        console.log("\n2. Preparing initialization data...");
        address usdcAddress = block.chainid == 8453 ? USDC_BASE_MAINNET : USDC_BASE_SEPOLIA;
        
        bytes memory initData = abi.encodeWithSelector(
            VaultToken.initialize.selector,
            IERC20(usdcAddress),      // _asset
            "Santuary Vault USDC",    // _name
            "sUSDC",                  // _symbol
            TREASURY,                 // _treasury
            deployer                  // _owner
        );
        
        // 3. Deploy el proxy y llamar a initialize
        console.log("\n3. Deploying proxy...");
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        console.log("Proxy deployed at:", address(proxy));
        
        // 4. Wrap proxy en interfaz VaultToken para interactuar
        VaultToken vaultToken = VaultToken(address(proxy));
        
        // 5. Verificar deployment
        console.log("\n=== Deployment Summary ===");
        console.log("Implementation:", address(implementation));
        console.log("Proxy (VaultToken):", address(proxy));
        console.log("Asset (USDC):", vaultToken.asset());
        console.log("Name:", vaultToken.name());
        console.log("Symbol:", vaultToken.symbol());
        console.log("Owner:", vaultToken.owner());
        console.log("Treasury:", vaultToken.treasury());
        console.log("Version:", vaultToken.version());
        console.log("Performance Fee:", vaultToken.performanceFee(), "bps");
        console.log("Management Fee:", vaultToken.managementFee(), "bps");
        console.log("Max Total Assets:", vaultToken.maxTotalAssets());
        
        vm.stopBroadcast();
        
        // 6. Guardar addresses para verificación
        console.log("\n=== Next Steps ===");
        console.log("1. Verify implementation:");
        console.log("   forge verify-contract", address(implementation), "src/VaultToken.sol:VaultToken --chain-id", block.chainid);
        console.log("\n2. Verify proxy:");
        console.log("   forge verify-contract", address(proxy), "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy --chain-id", block.chainid);
        console.log("\n3. Interact with VaultToken at proxy address:", address(proxy));
        console.log("\n4. Save these addresses:");
        console.log("   VAULT_PROXY=", address(proxy));
        console.log("   VAULT_IMPLEMENTATION=", address(implementation));
    }
}


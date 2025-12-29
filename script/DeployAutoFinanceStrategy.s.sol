// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/strategies/AutoFinanceStrategy.sol";
import "../src/VaultToken.sol";
import "../src/interfaces/IAutoPool.sol";

/**
 * @title DeployAutoFinanceStrategy
 * @notice Script para deployar y configurar la estrategia de Auto Finance en Base Mainnet
 * @dev Despliega AutoFinanceStrategy y la conecta al vault existente
 * 
 * NOTA: Solo funciona en Base Mainnet - Auto Finance no está disponible en testnet
 * 
 * Uso:
 * forge script script/DeployAutoFinanceStrategy.s.sol:DeployAutoFinanceStrategy \
 *   --rpc-url $BASE_MAINNET_RPC_URL \
 *   --broadcast \
 *   --verify
 * 
 * Variables de entorno requeridas:
 * - BASE_MAINNET_RPC_URL: URL del RPC de Base Mainnet
 * - PRIVATE_KEY: Private key del deployer
 * - ETHERSCAN_API_KEY: API key para verificación en BaseScan
 */
contract DeployAutoFinanceStrategy is Script {
    
    // ========== ADDRESSES - BASE MAINNET ONLY ==========
    
    address constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant AUTO_POOL_BASE_USD = 0x9c6864105AEC23388C89600046213a44C384c831;
    
    // ========== STATE VARIABLES ==========
    
    address public vaultProxy;
    address public deployer;
    address public treasury;
    
    // ========== DEPLOYMENT ==========
    
    function run() external {
        // Setup
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Deploy Auto Finance Strategy ===");
        console.log("Deployer:", deployer);
        console.log("Network:", block.chainid);
        
        // Verificar que estamos en Base Mainnet
        require(block.chainid == 8453, "This script only works on Base Mainnet (chain ID 8453)");
        console.log("Network: Base Mainnet");
        
        // Addresses de mainnet
        address usdc = USDC_BASE;
        address autoPool = AUTO_POOL_BASE_USD;
        
        // Cargar dirección del vault proxy desde variable de entorno
        vaultProxy = vm.envAddress("VAULT_PROXY");
        require(vaultProxy != address(0), "VAULT_PROXY environment variable not set");
        console.log("Vault Proxy:", vaultProxy);
        
        // Cargar treasury desde el vault
        VaultToken vault = VaultToken(vaultProxy);
        treasury = vault.treasury();
        console.log("Treasury:", treasury);
        
        // Deploy
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy AutoFinanceStrategy
        AutoFinanceStrategy strategy = new AutoFinanceStrategy(
            vaultProxy,      // vault
            usdc,           // asset
            autoPool,       // autoPool
            deployer        // owner
        );
        
        console.log("Strategy deployed at:", address(strategy));
        
        // 2. Verificar que la estrategia esté configurada correctamente
        require(strategy.vault() == vaultProxy, "Vault mismatch");
        require(strategy.asset() == usdc, "Asset mismatch");
        
        // 3. Configurar la estrategia en el vault
        // NOTA: Esta llamada debe hacerse por el owner del vault
        // Si el deployer no es el owner, esto fallará y debe hacerse manualmente
        try vault.updateStrategy(address(strategy)) {
            console.log("Strategy set in vault successfully");
        } catch {
            console.log("WARNING: Could not set strategy in vault (not owner)");
            console.log("Run manually: vault.updateStrategy(", address(strategy), ")");
        }
        
        vm.stopBroadcast();
        
        // ========== POST-DEPLOYMENT INFO ==========
        
        console.log("\n=== Deployment Summary ===");
        console.log("Strategy:", address(strategy));
        console.log("Vault:", vaultProxy);
        console.log("Asset (USDC):", usdc);
        console.log("Auto Pool:", autoPool);
        console.log("Owner:", deployer);
        
        console.log("\n=== Next Steps ===");
        console.log("1. Verify contract on BaseScan");
        console.log("2. If updateStrategy() failed, call it manually:");
        console.log("   vault.updateStrategy(", address(strategy), ")");
        console.log("3. Test deposit/withdraw flow");
        console.log("4. Monitor APY and yields");
    }
}


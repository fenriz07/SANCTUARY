// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/strategies/AutoFinanceStrategy.sol";
import "../src/VaultToken.sol";
import "../src/interfaces/IAutoPool.sol";

/**
 * @title DeployAutoFinanceStrategy
 * @notice Script para deployar y configurar la estrategia de Auto Finance
 * @dev Despliega AutoFinanceStrategy y la conecta al vault existente
 * 
 * Uso:
 * forge script script/DeployAutoFinanceStrategy.s.sol:DeployAutoFinanceStrategy \
 *   --rpc-url $BASE_SEPOLIA_RPC_URL \
 *   --broadcast \
 *   --verify
 * 
 * Variables de entorno requeridas:
 * - BASE_SEPOLIA_RPC_URL: URL del RPC de Base Sepolia
 * - PRIVATE_KEY: Private key del deployer
 * - ETHERSCAN_API_KEY: API key para verificación
 */
contract DeployAutoFinanceStrategy is Script {
    
    // ========== ADDRESSES ==========
    
    // Base Mainnet
    address constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant AUTO_POOL_BASE_USD = 0x275F0A1Db98db1c4e915BDE5B5D2F5a5eD4C6D8F; // Placeholder - necesita confirmación
    
    // Base Sepolia (testnet)
    address constant USDC_SEPOLIA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // Mock USDC
    address constant AUTO_POOL_SEPOLIA = address(0); // No disponible en testnet
    
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
        
        // Determinar addresses según la red
        address usdc;
        address autoPool;
        
        if (block.chainid == 8453) {
            // Base Mainnet
            console.log("Network: Base Mainnet");
            usdc = USDC_BASE;
            autoPool = AUTO_POOL_BASE_USD;
        } else if (block.chainid == 84532) {
            // Base Sepolia
            console.log("Network: Base Sepolia");
            usdc = USDC_SEPOLIA;
            autoPool = AUTO_POOL_SEPOLIA;
            
            // NOTA: Auto Finance no está disponible en testnet
            // Para testear, se puede deployar un mock de IAutoPool
            require(autoPool != address(0), "Auto Finance not available on testnet");
        } else {
            revert("Unsupported network");
        }
        
        // Cargar dirección del vault proxy desde archivo
        vaultProxy = _loadVaultProxyAddress();
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
        
        // Guardar addresses
        _saveDeployment(address(strategy), vaultProxy, usdc, autoPool);
        
        console.log("\n=== Next Steps ===");
        console.log("1. Verify contract on BaseScan");
        console.log("2. If updateStrategy() failed, call it manually:");
        console.log("   vault.updateStrategy(", address(strategy), ")");
        console.log("3. Test deposit/withdraw flow");
        console.log("4. Monitor APY and yields");
    }
    
    // ========== HELPERS ==========
    
    function _loadVaultProxyAddress() internal view returns (address) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/cache/.deployment.json");
        
        try vm.readFile(path) returns (string memory json) {
            bytes memory data = vm.parseJson(json, ".vaultProxy");
            address addr = abi.decode(data, (address));
            require(addr != address(0), "Invalid vault proxy address");
            return addr;
        } catch {
            revert("Could not load vault proxy address from cache/.deployment.json");
        }
    }
    
    function _saveDeployment(
        address strategy,
        address vault,
        address usdc,
        address autoPool
    ) internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/cache/.deployment.json");
        
        // Leer archivo existente
        string memory json = vm.readFile(path);
        
        // Parsear y agregar nueva info
        string memory obj = "deployment";
        vm.serializeAddress(obj, "autoFinanceStrategy", strategy);
        vm.serializeAddress(obj, "vaultProxy", vault);
        vm.serializeAddress(obj, "usdc", usdc);
        string memory output = vm.serializeAddress(obj, "autoPool", autoPool);
        
        // Escribir de vuelta
        vm.writeJson(output, path);
        
        console.log("\nDeployment info saved to:", path);
    }
}


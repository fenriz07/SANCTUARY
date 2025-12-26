// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/mocks/MockAutoPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployMockAutoPool
 * @notice Deploy un mock de Auto Finance en Base Sepolia para testing
 * 
 * Uso:
 * forge script script/DeployMockAutoPool.s.sol:DeployMockAutoPool \
 *   --rpc-url $BASE_SEPOLIA_RPC_URL \
 *   --broadcast \
 *   --verify
 */
contract DeployMockAutoPool is Script {
    
    // Base Sepolia
    address constant USDC_SEPOLIA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Deploying Mock Auto Finance baseUSD ===");
        console.log("Deployer:", deployer);
        console.log("Network:", block.chainid);
        console.log("USDC:", USDC_SEPOLIA);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy Mock AutoPool
        MockAutoPool mockAutoPool = new MockAutoPool(
            USDC_SEPOLIA,
            "Mock Tokemak baseUSD",
            "mbaseUSD"
        );
        
        console.log("\n=== Deployment Successful ===");
        console.log("Mock AutoPool:", address(mockAutoPool));
        console.log("Name:", mockAutoPool.name());
        console.log("Symbol:", mockAutoPool.symbol());
        console.log("Asset (USDC):", mockAutoPool.asset());
        console.log("APY:", mockAutoPool.apy(), "bps (8.82%)");
        
        vm.stopBroadcast();
        
        console.log("\n=== Next Steps ===");
        console.log("1. Verify contract on BaseScan Sepolia");
        console.log("2. Update DeployAutoFinanceStrategy.s.sol:");
        console.log("   address constant AUTO_POOL_SEPOLIA =", address(mockAutoPool), ";");
        console.log("3. Deploy strategy with this address");
        console.log("4. Test deposit/withdraw flow");
        
        // Guardar address
        _saveAddress(address(mockAutoPool));
    }
    
    function _saveAddress(address mockAutoPool) internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/cache/.testnet-deployment.json");
        
        string memory obj = "testnet";
        vm.serializeAddress(obj, "mockAutoPool", mockAutoPool);
        vm.serializeAddress(obj, "usdc", USDC_SEPOLIA);
        string memory output = vm.serializeUint(obj, "chainId", block.chainid);
        
        vm.writeJson(output, path);
        console.log("\nAddress saved to:", path);
    }
}


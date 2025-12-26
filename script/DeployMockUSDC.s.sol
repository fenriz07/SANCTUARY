// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @notice Mock USDC para testing (6 decimales como el real)
 * @dev Solo para testnet/local, NUNCA deployar en mainnet
 */
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        // Mint 1 millón de USDC al deployer
        _mint(msg.sender, 1_000_000 * 10**6);
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    /**
     * @notice Mintear USDC a cualquier address (solo testing)
     * @param to Dirección destino
     * @param amount Cantidad en unidades base (6 decimales)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    /**
     * @notice Mintear a múltiples addresses
     * @param recipients Array de direcciones
     * @param amounts Array de cantidades
     */
    function mintBatch(address[] calldata recipients, uint256[] calldata amounts) external {
        require(recipients.length == amounts.length, "Length mismatch");
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }
}

/**
 * @title DeployMockUSDC
 * @notice Script para deployar Mock USDC en testnet o local
 */
contract DeployMockUSDC is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Deploying Mock USDC ===");
        console.log("Deployer:", deployer);
        console.log("Network:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        MockUSDC usdc = new MockUSDC();
        
        console.log("\n=== Deployment Complete ===");
        console.log("Mock USDC Address:", address(usdc));
        console.log("Deployer Balance:", usdc.balanceOf(deployer), "(raw units)");
        console.log("Deployer Balance:", usdc.balanceOf(deployer) / 10**6, "USDC");
        console.log("Decimals:", usdc.decimals());
        
        vm.stopBroadcast();
        
        console.log("\n=== Next Steps ===");
        console.log("1. Save address to .env:");
        console.log("   USDC_ADDRESS=", address(usdc));
        console.log("\n2. Mint more USDC:");
        console.log("   cast send", address(usdc), '"mint(address,uint256)" <address> <amount>');
        console.log("\n3. Update DeployVaultProxy.s.sol:");
        console.log("   USDC_BASE_SEPOLIA =", address(usdc));
    }
}


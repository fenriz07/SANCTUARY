// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAutoPool} from "../src/interfaces/IAutoPool.sol";

/**
 * @title VerifyAutoPool
 * @notice Script para verificar que el contrato de Auto Finance en Base existe y funciona
 * @dev Este script verifica la dirección real del autopool antes de deployment
 * 
 * Uso:
 * forge script script/VerifyAutoPool.s.sol:VerifyAutoPool \
 *   --rpc-url https://mainnet.base.org \
 *   --broadcast
 */
contract VerifyAutoPool is Script {
    
    // Dirección REAL del Auto Finance baseUSD en Base Mainnet
    address constant AUTO_POOL = 0x9c6864105AEC23388C89600046213a44C384c831;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    
    function run() external view {
        console.log("=== Verificando Auto Finance baseUSD Autopool ===");
        console.log("Network:", block.chainid);
        console.log("Autopool Address:", AUTO_POOL);
        console.log("");
        
        // Verificar que el contrato existe
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(AUTO_POOL)
        }
        
        if (codeSize == 0) {
            console.log("ERROR: No hay bytecode en esta direccion!");
            return;
        }
        console.log("1. Bytecode exists:", codeSize, "bytes");
        
        // Cast a IAutoPool
        IAutoPool autoPool = IAutoPool(AUTO_POOL);
        
        // Verificar funciones ERC4626
        try autoPool.asset() returns (address assetAddr) {
            console.log("2. Asset (USDC):", assetAddr);
            require(assetAddr == USDC, "Asset mismatch!");
        } catch {
            console.log("ERROR: asset() failed");
            return;
        }
        
        try autoPool.totalAssets() returns (uint256 total) {
            console.log("3. Total Assets:", total);
        } catch {
            console.log("ERROR: totalAssets() failed");
            return;
        }
        
        try autoPool.totalSupply() returns (uint256 supply) {
            console.log("4. Total Supply (shares):", supply);
        } catch {
            console.log("ERROR: totalSupply() failed");
            return;
        }
        
        try autoPool.name() returns (string memory tokenName) {
            console.log("5. Name:", tokenName);
        } catch {
            console.log("WARNING: name() not available");
        }
        
        try autoPool.symbol() returns (string memory tokenSymbol) {
            console.log("6. Symbol:", tokenSymbol);
        } catch {
            console.log("WARNING: symbol() not available");
        }
        
        // Test convertToShares
        try autoPool.convertToShares(1e6) returns (uint256 shares) {
            console.log("7. 1 USDC converts to:", shares, "shares");
        } catch {
            console.log("ERROR: convertToShares() failed");
            return;
        }
        
        // Test convertToAssets
        try autoPool.convertToAssets(1e6) returns (uint256 assets) {
            console.log("8. 1 share converts to:", assets, "USDC");
        } catch {
            console.log("ERROR: convertToAssets() failed");
            return;
        }
        
        console.log("");
        console.log("=============================================");
        console.log("VERIFICATION SUCCESSFUL!");
        console.log("Auto Finance baseUSD is ERC4626 compatible");
        console.log("Safe to use in AutoFinanceStrategy");
        console.log("=============================================");
    }
}


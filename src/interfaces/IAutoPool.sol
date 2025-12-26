// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/interfaces/IERC4626.sol";

/**
 * @title IAutoPool
 * @notice Interface para interactuar con Auto Finance Autopools en Base
 * @dev Los Autopools de Auto Finance implementan el estándar ERC4626
 * 
 * Auto Finance es un protocolo de optimización de yield que rebalancea automáticamente
 * entre múltiples protocolos DeFi (Aave, Morpho, Fluid, Euler, Aerodrome, Curve, Balancer)
 * 
 * Autopools: https://app.auto.finance/pools/baseUSD
 * Docs: https://docs.auto.finance/
 */
interface IAutoPool is IERC4626 {
    
    // ========== STRUCTS ==========
    
    /**
     * @notice Información sobre el destino de inversión
     * @param destinationAddress Dirección del destino (Aave, Morpho, etc)
     * @param currentBalance Balance actual en ese destino
     * @param lastRebalance Timestamp del último rebalanceo
     */
    struct DestinationInfo {
        address destinationAddress;
        uint256 currentBalance;
        uint256 lastRebalance;
    }
    
    // ========== EVENTS ==========
    
    event Rebalanced(uint256 totalAssets, uint256 timestamp);
    event DestinationAdded(address indexed destination);
    event DestinationRemoved(address indexed destination);
    
    // ========== VIEW FUNCTIONS ==========
    
    /**
     * @notice Retorna el APY actual del pool
     * @return APY en basis points (10000 = 100%)
     */
    function getPoolAPY() external view returns (uint256);
    
    /**
     * @notice Retorna información de todos los destinos activos
     * @return Array de información de destinos
     */
    function getDestinations() external view returns (DestinationInfo[] memory);
    
    /**
     * @notice Retorna el total de assets bajo gestión
     * @return Total de assets en el autopool
     */
    function totalIdle() external view returns (uint256);
    
    /**
     * @notice Retorna el timestamp del último rebalanceo
     * @return Timestamp del último rebalanceo
     */
    function lastRebalanceTimestamp() external view returns (uint256);
    
    // ========== CORE FUNCTIONS (heredadas de ERC4626) ==========
    
    // Las siguientes funciones son parte del estándar ERC4626:
    // - deposit(uint256 assets, address receiver) -> uint256 shares
    // - mint(uint256 shares, address receiver) -> uint256 assets
    // - withdraw(uint256 assets, address receiver, address owner) -> uint256 shares
    // - redeem(uint256 shares, address receiver, address owner) -> uint256 assets
    // - totalAssets() -> uint256
    // - convertToShares(uint256 assets) -> uint256
    // - convertToAssets(uint256 shares) -> uint256
    // - maxDeposit(address) -> uint256
    // - maxMint(address) -> uint256
    // - maxWithdraw(address owner) -> uint256
    // - maxRedeem(address owner) -> uint256
    // - previewDeposit(uint256 assets) -> uint256
    // - previewMint(uint256 shares) -> uint256
    // - previewWithdraw(uint256 assets) -> uint256
    // - previewRedeem(uint256 shares) -> uint256
}


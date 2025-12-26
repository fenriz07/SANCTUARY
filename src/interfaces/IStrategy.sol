// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IStrategy
 * @notice Interface estándar para estrategias de inversión del vault
 * @dev Todas las estrategias deben implementar esta interface para ser compatibles con VaultToken
 */
interface IStrategy {
    
    // ========== EVENTS ==========
    
    event Invested(uint256 amount);
    event Divested(uint256 amount);
    event RewardsClaimed(uint256 amount);
    
    // ========== ERRORS ==========
    
    error OnlyVault();
    error InsufficientBalance();
    
    // ========== CORE FUNCTIONS ==========
    
    /**
     * @notice Invierte assets en el protocolo DeFi subyacente
     * @param amount Cantidad de assets a invertir
     * @return actualAmount Cantidad real invertida (puede diferir por slippage)
     */
    function invest(uint256 amount) external returns (uint256 actualAmount);
    
    /**
     * @notice Retira assets del protocolo DeFi subyacente
     * @param amount Cantidad de assets a retirar
     * @return actualAmount Cantidad real retirada
     */
    function divest(uint256 amount) external returns (uint256 actualAmount);
    
    /**
     * @notice Reclama rewards/yields generados por la estrategia
     * @return rewardAmount Cantidad de rewards reclamados
     */
    function claimRewards() external returns (uint256 rewardAmount);
    
    /**
     * @notice Retira todos los assets de emergencia
     * @dev Solo debe poder ser llamado por el vault en caso de emergencia
     * @return totalAmount Total de assets recuperados
     */
    function emergencyWithdraw() external returns (uint256 totalAmount);
    
    // ========== VIEW FUNCTIONS ==========
    
    /**
     * @notice Retorna el total de assets bajo gestión en esta estrategia
     * @return Total de assets invertidos
     */
    function totalAssets() external view returns (uint256);
    
    /**
     * @notice Retorna la dirección del asset base (ej: USDC)
     * @return Dirección del token asset
     */
    function asset() external view returns (address);
    
    /**
     * @notice Retorna la dirección del vault owner
     * @return Dirección del vault
     */
    function vault() external view returns (address);
    
    /**
     * @notice Retorna información sobre la estrategia
     * @return name Nombre de la estrategia
     * @return version Versión de la estrategia
     */
    function strategyInfo() external pure returns (string memory name, string memory version);
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IAutoPool.sol";

/**
 * @title AutoFinanceStrategy
 * @notice Estrategia de inversión que deposita USDC en Auto Finance baseUSD Autopool
 * @dev Implementa IStrategy para ser compatible con VaultToken
 * 
 * Auto Finance es un protocolo de optimización de yield en Base que rebalancea
 * automáticamente entre múltiples protocolos DeFi para maximizar rendimientos.
 * 
 * Protocolos integrados en baseUSD:
 * - Lending: Aave, Morpho, Fluid, Euler
 * - DEXs: Aerodrome, Curve, Balancer
 * 
 * APY actual: ~8.82% (variable según condiciones de mercado)
 * 
 * @custom:security-contact security@vault.xyz
 */
contract AutoFinanceStrategy is IStrategy, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ========== STATE VARIABLES ==========
    
    /// @notice Dirección del vault que controla esta estrategia
    address public immutable vault;
    
    /// @notice Token asset (USDC)
    IERC20 public immutable assetToken;
    
    /// @notice Auto Finance baseUSD Autopool
    IAutoPool public immutable autoPool;
    
    /// @notice Shares del autopool que poseemos
    uint256 public totalShares;
    
    /// @notice Slippage tolerance en basis points (100 = 1%)
    uint256 public slippageTolerance;
    
    // ========== CONSTANTS ==========
    
    uint256 public constant MAX_SLIPPAGE = 500; // 5% máximo
    uint256 public constant BASIS_POINTS = 10_000;
    
    // ========== CUSTOM ERRORS ==========
    
    error SlippageTooHigh();
    error SlippageExceeded();
    error ZeroAmount();
    error ZeroAddress();
    
    // ========== MODIFIERS ==========
    
    modifier onlyVault() {
        if (msg.sender != vault) revert IStrategy.OnlyVault();
        _;
    }
    
    // ========== CONSTRUCTOR ==========
    
    /**
     * @notice Constructor de la estrategia
     * @param _vault Dirección del vault owner
     * @param _asset Dirección del token asset (USDC)
     * @param _autoPool Dirección del Auto Finance baseUSD Autopool
     * @param _owner Dirección del owner (para funciones admin)
     */
    constructor(
        address _vault,
        address _asset,
        address _autoPool,
        address _owner
    ) Ownable(_owner) {
        if (_vault == address(0)) revert ZeroAddress();
        if (_asset == address(0)) revert ZeroAddress();
        if (_autoPool == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();
        
        vault = _vault;
        assetToken = IERC20(_asset);
        autoPool = IAutoPool(_autoPool);
        slippageTolerance = 50; // 0.5% default
        
        // Aprobar el autopool para gastar nuestros assets
        assetToken.forceApprove(_autoPool, type(uint256).max);
    }
    
    // ========== CORE FUNCTIONS ==========
    
    /**
     * @notice Invierte assets en Auto Finance baseUSD Autopool
     * @param amount Cantidad de USDC a invertir
     * @return actualAmount Cantidad real invertida (shares convertidas)
     */
    function invest(uint256 amount) 
        external 
        override 
        onlyVault 
        nonReentrant 
        returns (uint256 actualAmount) 
    {
        if (amount == 0) revert ZeroAmount();
        
        // Transferir assets del vault a esta estrategia
        assetToken.safeTransferFrom(vault, address(this), amount);
        
        // Calcular shares esperadas
        uint256 expectedShares = autoPool.previewDeposit(amount);
        uint256 minShares = expectedShares * (BASIS_POINTS - slippageTolerance) / BASIS_POINTS;
        
        // Depositar en Auto Finance
        // deposit(assets, receiver) retorna shares recibidas
        uint256 sharesReceived = autoPool.deposit(amount, address(this));
        
        // Validar slippage
        if (sharesReceived < minShares) revert SlippageTooHigh();
        
        // Actualizar contabilidad
        totalShares += sharesReceived;
        actualAmount = amount;
        
        emit Invested(amount);
    }
    
    /**
     * @notice Retira assets de Auto Finance baseUSD Autopool
     * @param amount Cantidad de USDC a retirar
     * @return actualAmount Cantidad real retirada
     */
    function divest(uint256 amount) 
        external 
        override 
        onlyVault 
        nonReentrant 
        returns (uint256 actualAmount) 
    {
        if (amount == 0) revert ZeroAmount();
        
        // Convertir el amount deseado a shares usando convertToShares
        // Esto evita el bug de previewWithdraw() que causa StateChangeDuringStaticCall
        uint256 sharesToBurn = autoPool.convertToShares(amount);
        
        // Validar que tengamos suficientes shares
        if (sharesToBurn > totalShares) revert IStrategy.InsufficientBalance();
        
        // Calcular assets mínimos aceptables (protección slippage)
        uint256 minAssets = amount * (BASIS_POINTS - slippageTolerance) / BASIS_POINTS;
        
        // Usar redeem() en lugar de withdraw() para evitar el bug del AutoPool
        // redeem(shares, receiver, owner) retorna assets recibidos
        actualAmount = autoPool.redeem(sharesToBurn, vault, address(this));
        
        // Validar slippage
        if (actualAmount < minAssets) revert SlippageExceeded();
        
        // Actualizar contabilidad
        totalShares -= sharesToBurn;
        
        emit Divested(actualAmount);
    }
    
    /**
     * @notice Reclama rewards generados (Auto Finance autocompound automáticamente)
     * @dev Auto Finance no tiene rewards separados, los yields se reflejan en el valor de shares
     * @return rewardAmount Siempre 0 porque no hay rewards separados
     */
    function claimRewards() external override onlyVault returns (uint256 rewardAmount) {
        // Auto Finance autocompound automáticamente los yields
        // Los rendimientos se reflejan en el aumento del valor de nuestras shares
        // No hay tokens de reward separados para reclamar
        
        emit RewardsClaimed(0);
        return 0;
    }
    
    /**
     * @notice Retira todos los assets en caso de emergencia
     * @dev Solo puede ser llamado por el vault
     * @return totalAmount Total de assets recuperados
     */
    function emergencyWithdraw() 
        external 
        override 
        onlyVault 
        nonReentrant 
        returns (uint256 totalAmount) 
    {
        if (totalShares == 0) return 0;
        
        // Redimir todas nuestras shares
        // redeem(shares, receiver, owner) retorna assets recibidos
        totalAmount = autoPool.redeem(totalShares, vault, address(this));
        
        // Reset contabilidad
        totalShares = 0;
        
        emit Divested(totalAmount);
    }
    
    // ========== VIEW FUNCTIONS ==========
    
    /**
     * @notice Retorna el total de assets bajo gestión en esta estrategia
     * @dev Convierte nuestras shares a assets usando el exchange rate actual
     * @return Total de assets invertidos
     */
    function totalAssets() external view override returns (uint256) {
        if (totalShares == 0) return 0;
        
        // Convertir shares a assets usando el exchange rate actual del autopool
        return autoPool.convertToAssets(totalShares);
    }
    
    /**
     * @notice Retorna la dirección del asset base (USDC)
     * @return Dirección del token asset
     */
    function asset() external view override returns (address) {
        return address(assetToken);
    }
    
    /**
     * @notice Retorna información sobre la estrategia
     * @return name Nombre de la estrategia
     * @return version Versión de la estrategia
     */
    function strategyInfo() 
        external 
        pure 
        override 
        returns (string memory name, string memory version) 
    {
        return ("Auto Finance baseUSD Strategy", "1.0.0");
    }
    
    /**
     * @notice Retorna el APY actual del autopool
     * @return APY en basis points (882 = 8.82%)
     */
    function getCurrentAPY() external view returns (uint256) {
        return autoPool.getPoolAPY();
    }
    
    /**
     * @notice Retorna información de las shares en el autopool
     * @return shares Total de shares que poseemos
     * @return value Valor en assets de esas shares
     */
    function getSharesInfo() external view returns (uint256 shares, uint256 value) {
        shares = totalShares;
        value = totalShares > 0 ? autoPool.convertToAssets(totalShares) : 0;
    }
    
    // ========== ADMIN FUNCTIONS ==========
    
    /**
     * @notice Aprueba al AutoPool para gastar sus propias shares
     * @dev Necesario para que withdraw() funcione. Solo callable por owner.
     * Esta función soluciona un bug del constructor que no aprobaba las shares.
     */
    function approveAutoPoolShares() external onlyOwner {
        IERC20(address(autoPool)).forceApprove(address(autoPool), type(uint256).max);
    }
    
    /**
     * @notice Actualiza la tolerancia al slippage
     * @param _slippageTolerance Nueva tolerancia en basis points
     */
    function updateSlippageTolerance(uint256 _slippageTolerance) external onlyOwner {
        if (_slippageTolerance > MAX_SLIPPAGE) revert SlippageTooHigh();
        slippageTolerance = _slippageTolerance;
    }
    
    /**
     * @notice Recupera tokens ERC20 enviados por error
     * @param token Dirección del token a recuperar
     * @param amount Cantidad a recuperar
     */
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        // No permitir recuperar el asset principal ni las shares del autopool
        if (token == address(assetToken)) revert("Cannot recover asset");
        if (token == address(autoPool)) revert("Cannot recover shares");
        
        IERC20(token).safeTransfer(owner(), amount);
    }
}


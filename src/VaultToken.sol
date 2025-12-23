// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title VaultToken
 * @notice Vault ERC4626 que genera yields automáticamente depositando en estrategias DeFi
 * @dev Implementa el estándar ERC4626 para vaults tokenizados
 * 
 * Características:
 * - Depósitos y retiros sin lockup period
 * - Performance fee sobre ganancias (10% default)
 * - Management fee anual (1% default)
 * - Pausable en caso de emergencias
 * - Protección contra reentrancy
 */
contract VaultToken is ERC4626, Ownable, ReentrancyGuard, Pausable {
    
    // ========== STATE VARIABLES ==========
    
    /// @notice Estrategia actual de inversión
    address public strategy;
    
    /// @notice Performance fee en basis points (10000 = 100%)
    uint256 public performanceFee;
    
    /// @notice Management fee anual en basis points
    uint256 public managementFee;
    
    /// @notice Timestamp de la última vez que se cobraron fees
    uint256 public lastFeeCollection;
    
    /// @notice Máximo total de assets permitidos (TVL cap)
    uint256 public maxTotalAssets;
    
    /// @notice Mínimo requerido para depositar
    uint256 public minDepositAmount;
    
    /// @notice Dirección del treasury donde van los fees
    address public treasury;
    
    // ========== CONSTANTS ==========
    
    uint256 public constant MAX_PERFORMANCE_FEE = 2000; // 20% máximo
    uint256 public constant MAX_MANAGEMENT_FEE = 500;   // 5% máximo
    uint256 public constant FEE_BASIS = 10_000;         // 100%
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    
    // ========== EVENTS ==========
    
    event StrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
    event FeesUpdated(uint256 performanceFee, uint256 managementFee);
    event Harvested(uint256 profit, uint256 feeAmount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event MaxTotalAssetsUpdated(uint256 oldMax, uint256 newMax);
    
    // ========== ERRORS ==========
    
    error BelowMinimumDeposit();
    error ExceedsMaxTotalAssets();
    error InvalidFeeAmount();
    error ZeroAddress();
    error NoAssetsToHarvest();
    
    // ========== CONSTRUCTOR ==========
    
    /**
     * @notice Inicializa el vault
     * @param _asset Token subyacente (ej: USDC)
     * @param _name Nombre del vault token (ej: "Vault USDC")
     * @param _symbol Símbolo del vault token (ej: "vUSDC")
     * @param _treasury Dirección donde se envían los fees
     */
    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _treasury
    ) 
        ERC4626(_asset) 
        ERC20(_name, _symbol) 
        Ownable(msg.sender)
    {
        if (_treasury == address(0)) revert ZeroAddress();
        
        treasury = _treasury;
        performanceFee = 1000;              // 10% default
        managementFee = 100;                // 1% anual default
        lastFeeCollection = block.timestamp;
        maxTotalAssets = 1_000_000e6;       // 1M USDC (6 decimales)
        minDepositAmount = 0.01e6;          // 0.01 USDC
    }
    
    // ========== DEPOSIT/WITHDRAW FUNCTIONS ==========
    
    /**
     * @notice Deposita assets y recibe shares del vault
     * @param assets Cantidad de tokens a depositar
     * @param receiver Dirección que recibirá los shares
     * @return shares Cantidad de shares emitidos
     */
    function deposit(
        uint256 assets, 
        address receiver
    ) 
        public 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256 shares) 
    {
        if (assets < minDepositAmount) revert BelowMinimumDeposit();
        if (totalAssets() + assets > maxTotalAssets) revert ExceedsMaxTotalAssets();
        
        // Llamar a la implementación base de ERC4626
        shares = super.deposit(assets, receiver);
        
        // Si hay estrategia configurada, invertir automáticamente
        if (strategy != address(0)) {
            _investInStrategy(assets);
        }
    }
    
    /**
     * @notice Retira assets quemando shares
     * @param assets Cantidad de assets a retirar
     * @param receiver Dirección que recibirá los assets
     * @param owner Dueño de los shares
     * @return shares Cantidad de shares quemados
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        // Si no hay suficiente balance idle, retirar de estrategia
        uint256 idle = IERC20(asset()).balanceOf(address(this));
        if (idle < assets && strategy != address(0)) {
            _divestFromStrategy(assets - idle);
        }
        
        // Llamar a la implementación base de ERC4626
        shares = super.withdraw(assets, receiver, owner);
    }
    
    // ========== VAULT MANAGEMENT ==========
    
    /**
     * @notice Recolecta yields de la estrategia y cobra fees
     * @dev Solo puede ser llamado por el owner o un keeper autorizado
     */
    function harvest() external onlyOwner {
        if (strategy == address(0)) revert NoAssetsToHarvest();
        
        uint256 beforeBalance = totalAssets();
        
        // Aquí se llamaría a strategy.claimRewards()
        // Por ahora es placeholder para el MVP
        
        uint256 afterBalance = totalAssets();
        
        if (afterBalance > beforeBalance) {
            uint256 profit = afterBalance - beforeBalance;
            
            // Cobrar performance fee
            uint256 feeAmount = (profit * performanceFee) / FEE_BASIS;
            
            if (feeAmount > 0) {
                IERC20(asset()).transfer(treasury, feeAmount);
                emit Harvested(profit, feeAmount);
            }
        }
        
        lastFeeCollection = block.timestamp;
    }
    
    /**
     * @notice Retorna el total de assets bajo gestión (TVL)
     * @dev Incluye balance idle + balance en estrategia
     */
    function totalAssets() public view override returns (uint256) {
        uint256 idle = IERC20(asset()).balanceOf(address(this));
        
        // Si hay estrategia, sumar también esos assets
        // Por ahora solo retorna idle para el MVP
        return idle;
    }
    
    // ========== ADMIN FUNCTIONS ==========
    
    /**
     * @notice Actualiza la estrategia de inversión
     * @param _newStrategy Dirección de la nueva estrategia
     */
    function updateStrategy(address _newStrategy) external onlyOwner {
        emit StrategyUpdated(strategy, _newStrategy);
        strategy = _newStrategy;
    }
    
    /**
     * @notice Actualiza los fees del vault
     * @param _performanceFee Nuevo performance fee en basis points
     * @param _managementFee Nuevo management fee en basis points
     */
    function updateFees(uint256 _performanceFee, uint256 _managementFee) external onlyOwner {
        if (_performanceFee > MAX_PERFORMANCE_FEE) revert InvalidFeeAmount();
        if (_managementFee > MAX_MANAGEMENT_FEE) revert InvalidFeeAmount();
        
        performanceFee = _performanceFee;
        managementFee = _managementFee;
        
        emit FeesUpdated(_performanceFee, _managementFee);
    }
    
    /**
     * @notice Actualiza la dirección del treasury
     * @param _newTreasury Nueva dirección del treasury
     */
    function updateTreasury(address _newTreasury) external onlyOwner {
        if (_newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, _newTreasury);
        treasury = _newTreasury;
    }
    
    /**
     * @notice Actualiza el máximo de assets permitidos
     * @param _maxTotalAssets Nuevo límite máximo
     */
    function updateMaxTotalAssets(uint256 _maxTotalAssets) external onlyOwner {
        emit MaxTotalAssetsUpdated(maxTotalAssets, _maxTotalAssets);
        maxTotalAssets = _maxTotalAssets;
    }
    
    /**
     * @notice Pausa el vault (emergencias)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @notice Reanuda el vault
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // ========== INTERNAL FUNCTIONS ==========
    
    /**
     * @notice Invierte assets en la estrategia
     * @param amount Cantidad a invertir
     */
    function _investInStrategy(uint256 amount) internal {
        // TODO: Implementar en siguiente fase
        // IERC20(asset()).approve(strategy, amount);
        // IStrategy(strategy).invest(amount);
    }
    
    /**
     * @notice Retira assets de la estrategia
     * @param amount Cantidad a retirar
     */
    function _divestFromStrategy(uint256 amount) internal {
        // TODO: Implementar en siguiente fase
        // IStrategy(strategy).divest(amount);
    }
}


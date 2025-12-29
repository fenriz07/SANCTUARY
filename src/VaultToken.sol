// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IStrategy.sol";

/**
 * @title VaultToken
 * @notice Vault ERC4626 que genera yields automáticamente depositando en estrategias DeFi
 * @dev Implementa el estándar ERC4626 para vaults tokenizados con patrón UUPS upgradeable
 * 
 * Características:
 * - Depósitos y retiros sin lockup period
 * - Performance fee sobre ganancias (10% default)
 * - Management fee anual (1% default)
 * - Pausable en caso de emergencias
 * - Protección contra reentrancy
 * - Upgradeable con UUPS pattern
 * 
 * @custom:security-contact security@vault.xyz
 */
contract VaultToken is 
    Initializable,
    ERC4626Upgradeable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable,
    UUPSUpgradeable 
{
    
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
    
    /// @notice High-Water Mark: último precio por share donde se cobraron fees
    /// @dev Usa 18 decimales de precisión (1e18 = 1.0)
    uint256 public lastHarvestedPricePerShare;
    
    // ========== CONSTANTS ==========
    
    uint256 public constant MAX_PERFORMANCE_FEE = 2000; // 20% máximo
    uint256 public constant MAX_MANAGEMENT_FEE = 500;   // 5% máximo
    uint256 public constant FEE_BASIS = 10_000;         // 100%
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 private constant PRECISION = 1e18;          // Precisión para PPS
    
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
    
    // ========== CONSTRUCTOR & INITIALIZER ==========
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @notice Inicializa el vault (reemplaza al constructor en proxies)
     * @param _asset Token subyacente (ej: USDC)
     * @param _name Nombre del vault token (ej: "Vault USDC")
     * @param _symbol Símbolo del vault token (ej: "vUSDC")
     * @param _treasury Dirección donde se envían los fees
     * @param _owner Dirección del owner del vault
     */
    function initialize(
        IERC20 _asset,
        string memory _name,
        string memory _symbol,
        address _treasury,
        address _owner
    ) public initializer {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_owner == address(0)) revert ZeroAddress();
        
        // Inicializar contratos base
        __ERC4626_init(_asset);
        __ERC20_init(_name, _symbol);
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        
        // Inicializar state variables
        treasury = _treasury;
        performanceFee = 1000;              // 10% default
        managementFee = 100;                // 1% anual default
        lastFeeCollection = block.timestamp;
        maxTotalAssets = 1_000_000e6;       // 1M USDC (6 decimales)
        minDepositAmount = 0.01e6;          // 0.01 USDC
        lastHarvestedPricePerShare = PRECISION; // 1:1 inicial (1e18)
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
            uint256 needed = assets - idle;
            
            // Pedir un poco más (1%) para compensar por slippage del autopool
            // Esto evita el error "transfer amount exceeds balance"
            uint256 toRequest = needed + (needed / 100);
            
            // No podemos pedir más de lo que la estrategia tiene
            uint256 strategyBalance = IStrategy(strategy).totalAssets();
            if (toRequest > strategyBalance) {
                toRequest = strategyBalance;
            }
            
            _divestFromStrategy(toRequest);
            
            // Verificar que ahora tengamos suficiente
            uint256 newIdle = IERC20(asset()).balanceOf(address(this));
            if (newIdle < assets) {
                // Si aún no es suficiente, intentar divest todo lo que queda
                if (strategyBalance > toRequest) {
                    _divestFromStrategy(strategyBalance - toRequest);
                }
            }
        }
        
        // Llamar a la implementación base de ERC4626
        shares = super.withdraw(assets, receiver, owner);
    }
    
    /**
     * @notice Redeem shares por assets
     * @param shares Cantidad de shares a quemar
     * @param receiver Dirección que recibirá los assets
     * @param owner Dueño de los shares
     * @return assets Cantidad de assets recibidos
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        // Calcular cuántos assets corresponden a estos shares
        assets = previewRedeem(shares);
        
        // Si no hay suficiente balance idle, retirar de estrategia
        uint256 idle = IERC20(asset()).balanceOf(address(this));
        if (idle < assets && strategy != address(0)) {
            uint256 needed = assets - idle;
            
            // Pedir un poco más (1%) para compensar por slippage del autopool
            uint256 toRequest = needed + (needed / 100);
            
            // No podemos pedir más de lo que la estrategia tiene
            uint256 strategyBalance = IStrategy(strategy).totalAssets();
            if (toRequest > strategyBalance) {
                toRequest = strategyBalance;
            }
            
            _divestFromStrategy(toRequest);
            
            // Verificar que ahora tengamos suficiente
            uint256 newIdle = IERC20(asset()).balanceOf(address(this));
            if (newIdle < assets) {
                // Si aún no es suficiente, intentar divest todo lo que queda
                if (strategyBalance > toRequest) {
                    _divestFromStrategy(strategyBalance - toRequest);
                }
            }
        }
        
        // Llamar a la implementación base de ERC4626
        assets = super.redeem(shares, receiver, owner);
    }
    
    // ========== VAULT MANAGEMENT ==========
    
    /**
     * @notice Recolecta yields de la estrategia y cobra performance fees
     * @dev Usa High-Water Mark basado en precio por share para calcular ganancias
     *      Solo cobra fees cuando el PPS supera el máximo histórico
     *      Inmune a deposits/withdraws ya que estos no afectan el PPS
     */
    function harvest() external virtual onlyOwner {
        if (strategy == address(0)) revert NoAssetsToHarvest();
        
        // Si no hay shares emitidos, no hay nada que hacer
        uint256 supply = totalSupply();
        if (supply == 0) return;
        
        // Calcular precio actual por share con precisión de 18 decimales
        uint256 currentPPS = (totalAssets() * PRECISION) / supply;
        
        // Si no superamos el High-Water Mark, no hay ganancias
        if (currentPPS <= lastHarvestedPricePerShare) {
            lastFeeCollection = block.timestamp;
            return; // No cobrar fees en pérdidas o sin ganancias
        }
        
        // Calcular profit por share
        uint256 profitPerShare = currentPPS - lastHarvestedPricePerShare;
        
        // Profit total = profit por share * total de shares
        uint256 totalProfit = (profitPerShare * supply) / PRECISION;
        
        // Calcular performance fee sobre el profit
        uint256 feeAmount = (totalProfit * performanceFee) / FEE_BASIS;
        
        if (feeAmount > 0) {
            // Retirar el fee de la estrategia al vault
            _divestFromStrategy(feeAmount);
            
            // Transferir fee al treasury
            IERC20(asset()).transfer(treasury, feeAmount);
            emit Harvested(totalProfit, feeAmount);
        }
        
        // CRÍTICO: Actualizar el High-Water Mark DESPUÉS de cobrar fees
        // Esto previene double-charging y establece el nuevo máximo histórico
        uint256 newPPS = (totalAssets() * PRECISION) / totalSupply();
        lastHarvestedPricePerShare = newPPS;
        lastFeeCollection = block.timestamp;
    }
    
    /**
     * @notice Retorna el total de assets bajo gestión (TVL)
     * @dev Incluye balance idle + balance en estrategia
     */
    function totalAssets() public view override returns (uint256) {
        uint256 idle = IERC20(asset()).balanceOf(address(this));
        
        // Si hay estrategia, sumar también esos assets
        if (strategy != address(0)) {
            uint256 strategyAssets = IStrategy(strategy).totalAssets();
            return idle + strategyAssets;
        }
        
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
        // Aprobar la estrategia para gastar nuestros assets
        IERC20(asset()).approve(strategy, amount);
        
        // Llamar a invest() de la estrategia
        IStrategy(strategy).invest(amount);
    }
    
    /**
     * @notice Retira assets de la estrategia
     * @param amount Cantidad a retirar
     */
    function _divestFromStrategy(uint256 amount) internal {
        // La estrategia enviará los assets directamente al vault
        IStrategy(strategy).divest(amount);
    }
    
    // ========== UUPS UPGRADE AUTHORIZATION ==========
    
    /**
     * @notice Autoriza upgrades del contrato (solo owner)
     * @dev Función requerida por UUPSUpgradeable
     * @param newImplementation Dirección de la nueva implementación
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    /**
     * @notice Retorna la versión actual del contrato
     * @return Versión del contrato (ej: "1.0.0")
     */
    function version() public pure virtual returns (string memory) {
        return "1.0.0";
    }
}


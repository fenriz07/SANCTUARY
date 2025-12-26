// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/strategies/AutoFinanceStrategy.sol";
import "../src/VaultToken.sol";
import "../src/interfaces/IAutoPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockAutoPool
 * @notice Mock de Auto Finance Autopool para testing
 * @dev Simula el comportamiento de un ERC4626 vault con yields
 */
contract MockAutoPool is Test {
    IERC20 public immutable asset;
    uint256 public totalSupply;
    uint256 public apy = 882; // 8.82% APY
    uint256 public lastUpdate;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    string public constant name = "Auto Finance baseUSD";
    string public constant symbol = "baseUSD";
    uint8 public constant decimals = 6;
    
    constructor(address _asset) {
        asset = IERC20(_asset);
        lastUpdate = block.timestamp;
    }
    
    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        // Acumular yields antes de deposit
        _accrueYields();
        
        // Transferir assets
        asset.transferFrom(msg.sender, address(this), assets);
        
        // Calcular shares basado en el balance real del pool
        uint256 currentAssets = asset.balanceOf(address(this)) - assets; // balance antes del deposit
        shares = totalSupply == 0 ? assets : (assets * totalSupply) / (currentAssets == 0 ? assets : currentAssets);
        
        // Mint shares
        balanceOf[receiver] += shares;
        totalSupply += shares;
        
        return shares;
    }
    
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        // Acumular yields
        _accrueYields();
        
        // Verificar que tengamos suficientes assets
        require(asset.balanceOf(address(this)) >= assets, "Insufficient assets in pool");
        
        // Calcular shares a quemar basado en el balance real
        uint256 currentAssets = asset.balanceOf(address(this));
        shares = (assets * totalSupply) / currentAssets;
        
        // Verificar allowance si no es el owner
        if (msg.sender != owner) {
            require(allowance[owner][msg.sender] >= shares, "Insufficient allowance");
            allowance[owner][msg.sender] -= shares;
        }
        
        // Quemar shares
        require(balanceOf[owner] >= shares, "Insufficient balance");
        balanceOf[owner] -= shares;
        totalSupply -= shares;
        
        // Transferir assets
        asset.transfer(receiver, assets);
        
        return shares;
    }
    
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        // Acumular yields
        _accrueYields();
        
        // Verificar allowance si no es el owner
        if (msg.sender != owner) {
            require(allowance[owner][msg.sender] >= shares, "Insufficient allowance");
            allowance[owner][msg.sender] -= shares;
        }
        
        // Calcular assets a entregar basado en el balance real
        uint256 currentAssets = asset.balanceOf(address(this));
        assets = (shares * currentAssets) / totalSupply;
        
        // Quemar shares
        require(balanceOf[owner] >= shares, "Insufficient balance");
        balanceOf[owner] -= shares;
        totalSupply -= shares;
        
        // Transferir assets
        asset.transfer(receiver, assets);
        
        return assets;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function convertToAssets(uint256 shares) external view returns (uint256) {
        if (totalSupply == 0) return shares;
        
        // Simular yields acumulados
        uint256 currentAssets = asset.balanceOf(address(this));
        uint256 timeElapsed = block.timestamp - lastUpdate;
        if (timeElapsed > 0 && currentAssets > 0) {
            uint256 yield = (currentAssets * apy * timeElapsed) / (10000 * 365 days);
            currentAssets += yield;
        }
        
        return (shares * currentAssets) / totalSupply;
    }
    
    function convertToShares(uint256 assets) external view returns (uint256) {
        if (totalSupply == 0) return assets;
        
        // Simular yields acumulados
        uint256 currentAssets = asset.balanceOf(address(this));
        uint256 timeElapsed = block.timestamp - lastUpdate;
        if (timeElapsed > 0 && currentAssets > 0) {
            uint256 yield = (currentAssets * apy * timeElapsed) / (10000 * 365 days);
            currentAssets += yield;
        }
        
        return (assets * totalSupply) / currentAssets;
    }
    
    function previewDeposit(uint256 assets) external view returns (uint256) {
        return this.convertToShares(assets);
    }
    
    function previewWithdraw(uint256 assets) external view returns (uint256) {
        return this.convertToShares(assets);
    }
    
    function previewRedeem(uint256 shares) external view returns (uint256) {
        return this.convertToAssets(shares);
    }
    
    function maxDeposit(address) external pure returns (uint256) {
        return type(uint256).max;
    }
    
    function maxWithdraw(address owner) external view returns (uint256) {
        return this.convertToAssets(balanceOf[owner]);
    }
    
    function maxRedeem(address owner) external view returns (uint256) {
        return balanceOf[owner];
    }
    
    function getPoolAPY() external view returns (uint256) {
        return apy;
    }
    
    function totalAssets() external view returns (uint256) {
        // Retornar el balance real + yields simulados
        uint256 currentAssets = asset.balanceOf(address(this));
        uint256 timeElapsed = block.timestamp - lastUpdate;
        if (timeElapsed > 0 && currentAssets > 0) {
            uint256 yield = (currentAssets * apy * timeElapsed) / (10000 * 365 days);
            currentAssets += yield;
        }
        return currentAssets;
    }
    
    function _accrueYields() internal {
        uint256 timeElapsed = block.timestamp - lastUpdate;
        if (timeElapsed > 0) {
            uint256 currentBalance = asset.balanceOf(address(this));
            if (currentBalance > 0) {
                // Simular yields: mintear tokens directamente al pool
                // En producción esto sería el yield real del protocolo
                uint256 yield = (currentBalance * apy * timeElapsed) / (10000 * 365 days);
                
                // Dar al pool más USDC para simular yields
                deal(address(asset), address(this), currentBalance + yield);
            }
            lastUpdate = block.timestamp;
        }
    }
    
    // Helper para avanzar tiempo y simular yields
    function simulateYields(uint256 timeInSeconds) external {
        vm.warp(block.timestamp + timeInSeconds);
        _accrueYields();
    }
}

/**
 * @title AutoFinanceStrategyTest
 * @notice Tests para la estrategia de Auto Finance
 */
contract AutoFinanceStrategyTest is Test {
    
    // Contratos
    VaultToken public vaultImplementation;
    VaultToken public vault;
    AutoFinanceStrategy public strategy;
    MockAutoPool public autoPool;
    IERC20 public usdc;
    
    // Addresses
    address public owner = address(this);
    address public treasury = makeAddr("treasury");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    
    // Constantes
    uint256 constant INITIAL_BALANCE = 10_000e6; // 10,000 USDC
    uint256 constant DEPOSIT_AMOUNT = 1_000e6;   // 1,000 USDC
    
    // ========== SETUP ==========
    
    function setUp() public {
        // Deploy mock USDC
        usdc = IERC20(_deployMockUSDC());
        
        // Deploy Mock AutoPool
        autoPool = new MockAutoPool(address(usdc));
        
        // Deploy Vault (usando patrón de tu proyecto)
        vaultImplementation = new VaultToken();
        vault = VaultToken(_deployProxy(address(vaultImplementation)));
        vault.initialize(
            usdc,
            "Vault USDC",
            "vUSDC",
            treasury,
            owner
        );
        
        // Deploy Strategy
        strategy = new AutoFinanceStrategy(
            address(vault),
            address(usdc),
            address(autoPool),
            owner
        );
        
        // Configurar estrategia en el vault
        vault.updateStrategy(address(strategy));
        
        // Mint USDC a usuarios de prueba
        deal(address(usdc), alice, INITIAL_BALANCE);
        deal(address(usdc), bob, INITIAL_BALANCE);
        
        // Labels para debugging
        vm.label(address(vault), "Vault");
        vm.label(address(strategy), "Strategy");
        vm.label(address(autoPool), "AutoPool");
        vm.label(address(usdc), "USDC");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
    }
    
    // ========== BASIC TESTS ==========
    
    function test_Deployment() public {
        assertEq(strategy.vault(), address(vault));
        assertEq(strategy.asset(), address(usdc));
        assertEq(address(strategy.autoPool()), address(autoPool));
        assertEq(strategy.owner(), owner);
    }
    
    function test_DepositAndInvest() public {
        // Alice deposita en el vault
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 shares = vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();
        
        // Verificar
        assertGt(shares, 0, "Should receive shares");
        assertEq(vault.balanceOf(alice), shares, "Share balance mismatch");
        
        // Verificar que se invirtió en la estrategia
        assertGt(strategy.totalAssets(), 0, "Strategy should have assets");
        assertGt(autoPool.balanceOf(address(strategy)), 0, "Strategy should have autopool shares");
    }
    
    function test_WithdrawFromStrategy() public {
        // Setup: Alice deposita
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, alice);
        
        // Alice retira
        uint256 sharesToRedeem = vault.balanceOf(alice);
        uint256 assetsReceived = vault.redeem(sharesToRedeem, alice, alice);
        vm.stopPrank();
        
        // Verificar
        assertApproxEqRel(assetsReceived, DEPOSIT_AMOUNT, 0.01e18, "Should receive ~same amount");
        assertEq(vault.balanceOf(alice), 0, "Should have no shares left");
        assertEq(strategy.totalAssets(), 0, "Strategy should be empty");
    }
    
    function test_AccumulateYields() public {
        // Alice deposita
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();
        
        uint256 assetsBefore = vault.totalAssets();
        
        // Simular 30 días de yields
        autoPool.simulateYields(30 days);
        
        uint256 assetsAfter = vault.totalAssets();
        
        // Verificar que los assets aumentaron
        assertGt(assetsAfter, assetsBefore, "Assets should increase with yields");
        
        // APY ~8.82%, en 30 días debería ser ~0.73%
        uint256 expectedYield = (assetsBefore * 73) / 10000;
        assertApproxEqRel(assetsAfter - assetsBefore, expectedYield, 0.1e18, "Yield mismatch");
    }
    
    function test_Harvest() public {
        // Alice deposita
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();
        
        // Simular yields
        autoPool.simulateYields(30 days);
        
        uint256 treasuryBefore = usdc.balanceOf(treasury);
        
        // Harvest
        vault.harvest();
        
        uint256 treasuryAfter = usdc.balanceOf(treasury);
        
        // Verificar que el treasury recibió fees
        assertGt(treasuryAfter, treasuryBefore, "Treasury should receive fees");
    }
    
    function test_MultipleUsers() public {
        // Alice deposita
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 aliceShares = vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();
        
        // Bob deposita
        vm.startPrank(bob);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        uint256 bobShares = vault.deposit(DEPOSIT_AMOUNT, bob);
        vm.stopPrank();
        
        // Simular yields
        autoPool.simulateYields(30 days);
        
        // Alice retira
        vm.prank(alice);
        uint256 aliceReceived = vault.redeem(aliceShares, alice, alice);
        
        // Bob retira
        vm.prank(bob);
        uint256 bobReceived = vault.redeem(bobShares, bob, bob);
        
        // Ambos deberían recibir aproximadamente lo mismo + yields
        assertApproxEqRel(aliceReceived, bobReceived, 0.01e18, "Both should receive similar amounts");
        assertGt(aliceReceived, DEPOSIT_AMOUNT, "Should receive more than deposited (yields)");
    }
    
    function test_EmergencyWithdraw() public {
        // Alice deposita
        vm.startPrank(alice);
        usdc.approve(address(vault), DEPOSIT_AMOUNT);
        vault.deposit(DEPOSIT_AMOUNT, alice);
        vm.stopPrank();
        
        uint256 vaultBalanceBefore = usdc.balanceOf(address(vault));
        uint256 strategyAssetsBefore = strategy.totalAssets();
        
        // Emergency withdraw desde el vault
        vm.prank(address(vault));
        uint256 recovered = strategy.emergencyWithdraw();
        
        // Verificar
        assertEq(recovered, strategyAssetsBefore, "Should recover all assets");
        assertEq(strategy.totalAssets(), 0, "Strategy should be empty");
        assertGt(usdc.balanceOf(address(vault)), vaultBalanceBefore, "Vault should have more USDC");
    }
    
    // ========== HELPERS ==========
    
    function _deployMockUSDC() internal returns (address) {
        // Deploy un simple ERC20 mock
        bytes memory bytecode = abi.encodePacked(
            type(MockERC20).creationCode,
            abi.encode("USD Coin", "USDC", 6)
        );
        
        address addr;
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        
        return addr;
    }
    
    function _deployProxy(address implementation) internal returns (address) {
        // Proxy simple para testing
        bytes memory initCode = abi.encodePacked(
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            implementation,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        
        address proxy;
        assembly {
            proxy := create(0, add(initCode, 0x20), mload(initCode))
        }
        
        return proxy;
    }
}

// Mock ERC20 simple
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (msg.sender != from) {
            allowance[from][msg.sender] -= amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {VaultToken} from "../src/VaultToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @notice Mock USDC para testing (6 decimales como el real)
 */
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 1_000_000e6); // 1M USDC
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title VaultTokenTest
 * @notice Tests completos para VaultToken con patrón UUPS proxy
 */
contract VaultTokenTest is Test {
    VaultToken public vaultToken;
    VaultToken public implementation;
    ERC1967Proxy public proxy;
    MockUSDC public usdc;
    
    address public owner;
    address public treasury;
    address public user1;
    address public user2;
    
    // Events a testear
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    
    function setUp() public {
        // Crear addresses de prueba
        owner = makeAddr("owner");
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy USDC mock
        usdc = new MockUSDC();
        
        // Deploy implementation
        implementation = new VaultToken();
        
        // Preparar datos de inicialización
        bytes memory initData = abi.encodeWithSelector(
            VaultToken.initialize.selector,
            IERC20(address(usdc)),
            "Vault USDC",
            "vUSDC",
            treasury,
            owner
        );
        
        // Deploy proxy
        proxy = new ERC1967Proxy(address(implementation), initData);
        
        // Wrap proxy en interfaz VaultToken
        vaultToken = VaultToken(address(proxy));
        
        // Transferir USDC a usuarios de prueba
        usdc.transfer(user1, 10_000e6);  // 10k USDC
        usdc.transfer(user2, 10_000e6);  // 10k USDC
    }
    
    // ========== INITIALIZATION TESTS ==========
    
    function test_Initialization() public {
        assertEq(address(vaultToken.asset()), address(usdc), "Asset should be USDC");
        assertEq(vaultToken.name(), "Vault USDC", "Name should be Vault USDC");
        assertEq(vaultToken.symbol(), "vUSDC", "Symbol should be vUSDC");
        assertEq(vaultToken.owner(), owner, "Owner should be set");
        assertEq(vaultToken.treasury(), treasury, "Treasury should be set");
        assertEq(vaultToken.performanceFee(), 1000, "Performance fee should be 10%");
        assertEq(vaultToken.managementFee(), 100, "Management fee should be 1%");
        assertEq(vaultToken.version(), "1.0.0", "Version should be 1.0.0");
    }
    
    function test_CannotInitializeTwice() public {
        vm.expectRevert();
        vaultToken.initialize(
            IERC20(address(usdc)),
            "Test",
            "TEST",
            treasury,
            owner
        );
    }
    
    function test_ImplementationIsDisabled() public {
        vm.expectRevert();
        implementation.initialize(
            IERC20(address(usdc)),
            "Test",
            "TEST",
            treasury,
            owner
        );
    }
    
    // ========== DEPOSIT TESTS ==========
    
    function test_Deposit() public {
        uint256 depositAmount = 1000e6; // 1000 USDC
        
        vm.startPrank(user1);
        usdc.approve(address(vaultToken), depositAmount);
        
        uint256 shares = vaultToken.deposit(depositAmount, user1);
        vm.stopPrank();
        
        assertEq(vaultToken.balanceOf(user1), shares, "User should have shares");
        assertEq(vaultToken.totalAssets(), depositAmount, "Total assets should match deposit");
        assertGt(shares, 0, "Shares should be > 0");
    }
    
    function test_Deposit_FirstDepositor() public {
        uint256 depositAmount = 100e6;
        
        vm.startPrank(user1);
        usdc.approve(address(vaultToken), depositAmount);
        uint256 shares = vaultToken.deposit(depositAmount, user1);
        vm.stopPrank();
        
        // Primer depositor: shares = assets (ratio 1:1)
        assertEq(shares, depositAmount, "First deposit should be 1:1");
    }
    
    function test_Deposit_MultipleUsers() public {
        // User1 deposita primero
        vm.startPrank(user1);
        usdc.approve(address(vaultToken), 1000e6);
        vaultToken.deposit(1000e6, user1);
        vm.stopPrank();
        
        // User2 deposita después
        vm.startPrank(user2);
        usdc.approve(address(vaultToken), 500e6);
        vaultToken.deposit(500e6, user2);
        vm.stopPrank();
        
        assertEq(vaultToken.totalAssets(), 1500e6, "Total assets should be sum");
        assertGt(vaultToken.balanceOf(user1), vaultToken.balanceOf(user2), "User1 should have more shares");
    }
    
    function test_Deposit_RevertsIfBelowMinimum() public {
        uint256 tooSmall = 0.001e6; // 0.001 USDC < 0.01 mínimo
        
        vm.startPrank(user1);
        usdc.approve(address(vaultToken), tooSmall);
        
        vm.expectRevert(VaultToken.BelowMinimumDeposit.selector);
        vaultToken.deposit(tooSmall, user1);
        vm.stopPrank();
    }
    
    function test_Deposit_RevertsIfExceedsMaxTotalAssets() public {
        uint256 tooMuch = 2_000_000e6; // 2M USDC > 1M max
        
        // Mintear más USDC a user1
        usdc.mint(user1, tooMuch);
        
        vm.startPrank(user1);
        usdc.approve(address(vaultToken), tooMuch);
        
        vm.expectRevert(VaultToken.ExceedsMaxTotalAssets.selector);
        vaultToken.deposit(tooMuch, user1);
        vm.stopPrank();
    }
    
    function test_Deposit_RevertsWhenPaused() public {
        // Owner pausa el vault
        vm.prank(owner);
        vaultToken.pause();
        
        vm.startPrank(user1);
        usdc.approve(address(vaultToken), 1000e6);
        
        vm.expectRevert();
        vaultToken.deposit(1000e6, user1);
        vm.stopPrank();
    }
    
    // ========== WITHDRAW TESTS ==========
    
    function test_Withdraw() public {
        // Setup: depositar primero
        uint256 depositAmount = 1000e6;
        vm.startPrank(user1);
        usdc.approve(address(vaultToken), depositAmount);
        vaultToken.deposit(depositAmount, user1);
        
        // Withdraw la mitad
        uint256 withdrawAmount = 500e6;
        uint256 balanceBefore = usdc.balanceOf(user1);
        
        vaultToken.withdraw(withdrawAmount, user1, user1);
        vm.stopPrank();
        
        uint256 balanceAfter = usdc.balanceOf(user1);
        
        assertEq(balanceAfter - balanceBefore, withdrawAmount, "Should receive withdrawn amount");
        assertEq(vaultToken.totalAssets(), depositAmount - withdrawAmount, "Total assets should decrease");
    }
    
    function test_Withdraw_FullAmount() public {
        uint256 depositAmount = 1000e6;
        
        vm.startPrank(user1);
        usdc.approve(address(vaultToken), depositAmount);
        vaultToken.deposit(depositAmount, user1);
        
        uint256 shares = vaultToken.balanceOf(user1);
        vaultToken.redeem(shares, user1, user1);
        vm.stopPrank();
        
        assertEq(vaultToken.balanceOf(user1), 0, "Should have no shares left");
        assertApproxEqAbs(vaultToken.totalAssets(), 0, 1, "Vault should be nearly empty");
    }
    
    function test_Withdraw_RevertsWhenPaused() public {
        // Setup: depositar
        vm.startPrank(user1);
        usdc.approve(address(vaultToken), 1000e6);
        vaultToken.deposit(1000e6, user1);
        vm.stopPrank();
        
        // Pausar vault
        vm.prank(owner);
        vaultToken.pause();
        
        // Intentar withdraw
        vm.startPrank(user1);
        vm.expectRevert();
        vaultToken.withdraw(500e6, user1, user1);
        vm.stopPrank();
    }
    
    // ========== ADMIN FUNCTIONS TESTS ==========
    
    function test_UpdateFees() public {
        vm.prank(owner);
        vaultToken.updateFees(1500, 200); // 15% performance, 2% management
        
        assertEq(vaultToken.performanceFee(), 1500);
        assertEq(vaultToken.managementFee(), 200);
    }
    
    function test_UpdateFees_RevertsIfTooHigh() public {
        vm.startPrank(owner);
        
        // Performance fee > 20%
        vm.expectRevert(VaultToken.InvalidFeeAmount.selector);
        vaultToken.updateFees(2500, 100);
        
        // Management fee > 5%
        vm.expectRevert(VaultToken.InvalidFeeAmount.selector);
        vaultToken.updateFees(1000, 600);
        
        vm.stopPrank();
    }
    
    function test_UpdateFees_RevertsIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        vaultToken.updateFees(1500, 200);
    }
    
    function test_UpdateTreasury() public {
        address newTreasury = makeAddr("newTreasury");
        
        vm.prank(owner);
        vaultToken.updateTreasury(newTreasury);
        
        assertEq(vaultToken.treasury(), newTreasury);
    }
    
    function test_UpdateTreasury_RevertsIfZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(VaultToken.ZeroAddress.selector);
        vaultToken.updateTreasury(address(0));
    }
    
    function test_UpdateMaxTotalAssets() public {
        uint256 newMax = 5_000_000e6; // 5M USDC
        
        vm.prank(owner);
        vaultToken.updateMaxTotalAssets(newMax);
        
        assertEq(vaultToken.maxTotalAssets(), newMax);
    }
    
    function test_PauseAndUnpause() public {
        vm.startPrank(owner);
        
        vaultToken.pause();
        assertTrue(vaultToken.paused());
        
        vaultToken.unpause();
        assertFalse(vaultToken.paused());
        
        vm.stopPrank();
    }
    
    function test_Pause_RevertsIfNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        vaultToken.pause();
    }
    
    // ========== PROXY & UPGRADE TESTS ==========
    
    function test_ProxyPointsToImplementation() public {
        // Verificar que el proxy usa la implementación correcta
        bytes32 implementationSlot = vm.load(
            address(proxy),
            0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc // ERC1967 implementation slot
        );
        
        address currentImplementation = address(uint160(uint256(implementationSlot)));
        assertEq(currentImplementation, address(implementation), "Proxy should point to implementation");
    }
    
    function test_Version() public {
        assertEq(vaultToken.version(), "1.0.0");
    }
    
    // ========== FUZZ TESTS ==========
    
    function testFuzz_Deposit(uint256 amount) public {
        // Bound entre mínimo y máximo
        amount = bound(amount, 0.01e6, 1_000_000e6);
        
        usdc.mint(user1, amount);
        
        vm.startPrank(user1);
        usdc.approve(address(vaultToken), amount);
        uint256 shares = vaultToken.deposit(amount, user1);
        vm.stopPrank();
        
        assertGt(shares, 0, "Should receive shares");
        assertEq(vaultToken.totalAssets(), amount, "Total assets should match");
    }
    
    function testFuzz_DepositAndWithdraw(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 0.01e6, 1_000_000e6);
        
        usdc.mint(user1, depositAmount);
        
        vm.startPrank(user1);
        usdc.approve(address(vaultToken), depositAmount);
        uint256 shares = vaultToken.deposit(depositAmount, user1);
        
        // Withdraw everything
        vaultToken.redeem(shares, user1, user1);
        vm.stopPrank();
        
        assertEq(vaultToken.balanceOf(user1), 0, "Should have no shares");
    }
}

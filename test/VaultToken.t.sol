// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/VaultToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @notice Token ERC20 simple para testing
 */
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        // Mintear 1 millón de tokens para testing
        _mint(msg.sender, 1_000_000e6); // 6 decimales como USDC real
    }
    
    function decimals() public pure override returns (uint8) {
        return 6; // USDC usa 6 decimales
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title VaultTokenTest
 * @notice Tests básicos para el VaultToken
 */
contract VaultTokenTest is Test {
    VaultToken public vault;
    MockUSDC public usdc;
    
    address public owner = address(this);
    address public treasury = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    
    // Setup se ejecuta antes de cada test
    function setUp() public {
        // Deploy mock USDC
        usdc = new MockUSDC();
        
        // Deploy vault
        vault = new VaultToken(
            IERC20(address(usdc)),
            "Vault USDC",
            "vUSDC",
            treasury
        );
        
        // Dar tokens a los usuarios de prueba
        usdc.mint(user1, 10_000e6); // 10k USDC
        usdc.mint(user2, 10_000e6); // 10k USDC
    }
    
    // ========== TESTS BÁSICOS ==========
    
    function testInitialization() public view {
        assertEq(vault.name(), "Vault USDC");
        assertEq(vault.symbol(), "vUSDC");
        assertEq(address(vault.asset()), address(usdc));
        assertEq(vault.treasury(), treasury);
        assertEq(vault.performanceFee(), 1000); // 10%
        assertEq(vault.managementFee(), 100);   // 1%
    }
    
    function testDeposit() public {
        uint256 depositAmount = 1000e6; // 1000 USDC
        
        // Usuario 1 deposita
        vm.startPrank(user1);
        usdc.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, user1);
        vm.stopPrank();
        
        // Verificar que recibió shares
        assertEq(shares, depositAmount); // 1:1 en primer depósito
        assertEq(vault.balanceOf(user1), depositAmount);
        assertEq(vault.totalAssets(), depositAmount);
        assertEq(usdc.balanceOf(address(vault)), depositAmount);
    }
    
    function testMultipleDeposits() public {
        uint256 amount = 1000e6;
        
        // User1 deposita
        vm.startPrank(user1);
        usdc.approve(address(vault), amount);
        vault.deposit(amount, user1);
        vm.stopPrank();
        
        // User2 deposita
        vm.startPrank(user2);
        usdc.approve(address(vault), amount);
        vault.deposit(amount, user2);
        vm.stopPrank();
        
        // Verificar balances
        assertEq(vault.balanceOf(user1), amount);
        assertEq(vault.balanceOf(user2), amount);
        assertEq(vault.totalAssets(), amount * 2);
    }
    
    function testWithdraw() public {
        uint256 depositAmount = 1000e6;
        
        // Primero depositar
        vm.startPrank(user1);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        
        // Luego retirar
        uint256 balanceBefore = usdc.balanceOf(user1);
        vault.withdraw(depositAmount, user1, user1);
        uint256 balanceAfter = usdc.balanceOf(user1);
        vm.stopPrank();
        
        // Verificar
        assertEq(vault.balanceOf(user1), 0);
        assertEq(balanceAfter - balanceBefore, depositAmount);
        assertEq(vault.totalAssets(), 0);
    }
    
    function testPartialWithdraw() public {
        uint256 depositAmount = 1000e6;
        uint256 withdrawAmount = 400e6;
        
        // Depositar
        vm.startPrank(user1);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        
        // Retirar parcial
        vault.withdraw(withdrawAmount, user1, user1);
        vm.stopPrank();
        
        // Verificar que quedó el resto
        assertGt(vault.balanceOf(user1), 0);
        assertEq(vault.totalAssets(), depositAmount - withdrawAmount);
    }
    
    // ========== TESTS DE LÍMITES ==========
    
    function testCannotDepositBelowMinimum() public {
        uint256 tooSmall = 0.001e6; // Menos del mínimo
        
        vm.startPrank(user1);
        usdc.approve(address(vault), tooSmall);
        
        vm.expectRevert(VaultToken.BelowMinimumDeposit.selector);
        vault.deposit(tooSmall, user1);
        vm.stopPrank();
    }
    
    function testCannotExceedMaxTotalAssets() public {
        uint256 tooMuch = 2_000_000e6; // Más del máximo (1M)
        
        // Mintear más tokens
        usdc.mint(user1, tooMuch);
        
        vm.startPrank(user1);
        usdc.approve(address(vault), tooMuch);
        
        vm.expectRevert(VaultToken.ExceedsMaxTotalAssets.selector);
        vault.deposit(tooMuch, user1);
        vm.stopPrank();
    }
    
    // ========== TESTS DE ADMIN ==========
    
    function testUpdateFees() public {
        uint256 newPerfFee = 1500; // 15%
        uint256 newMgmtFee = 200;  // 2%
        
        vault.updateFees(newPerfFee, newMgmtFee);
        
        assertEq(vault.performanceFee(), newPerfFee);
        assertEq(vault.managementFee(), newMgmtFee);
    }
    
    function testCannotSetFeesTooHigh() public {
        uint256 tooHighPerf = 3000; // 30% (max es 20%)
        uint256 validMgmt = 100;
        
        vm.expectRevert(VaultToken.InvalidFeeAmount.selector);
        vault.updateFees(tooHighPerf, validMgmt);
    }
    
    function testPauseUnpause() public {
        // Pausar
        vault.pause();
        
        // No se puede depositar cuando está pausado
        vm.startPrank(user1);
        usdc.approve(address(vault), 1000e6);
        
        vm.expectRevert();
        vault.deposit(1000e6, user1);
        vm.stopPrank();
        
        // Reanudar
        vault.unpause();
        
        // Ahora sí se puede depositar
        vm.startPrank(user1);
        vault.deposit(1000e6, user1);
        vm.stopPrank();
        
        assertEq(vault.balanceOf(user1), 1000e6);
    }
    
    function testUpdateTreasury() public {
        address newTreasury = address(0x999);
        
        vault.updateTreasury(newTreasury);
        
        assertEq(vault.treasury(), newTreasury);
    }
    
    function testCannotSetZeroAddressTreasury() public {
        vm.expectRevert(VaultToken.ZeroAddress.selector);
        vault.updateTreasury(address(0));
    }
    
    // ========== TESTS DE ERC4626 STANDARD ==========
    
    function testPreviewDeposit() public view {
        uint256 assets = 1000e6;
        uint256 shares = vault.previewDeposit(assets);
        
        // En vault vacío, debe ser 1:1
        assertEq(shares, assets);
    }
    
    function testPreviewWithdraw() public {
        // Depositar primero
        vm.startPrank(user1);
        usdc.approve(address(vault), 1000e6);
        vault.deposit(1000e6, user1);
        vm.stopPrank();
        
        // Preview de retiro
        uint256 shares = vault.previewWithdraw(500e6);
        assertEq(shares, 500e6); // Debería ser 1:1
    }
    
    function testMaxDeposit() public view {
        uint256 maxDeposit = vault.maxDeposit(user1);
        
        // maxDeposit retorna type(uint256).max por default en ERC4626
        // cuando no hay límites específicos de usuario
        assertGt(maxDeposit, 0);
    }
    
    function testMaxWithdraw() public {
        uint256 depositAmount = 1000e6;
        
        // Depositar
        vm.startPrank(user1);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        
        // Max withdraw debería ser igual al depósito
        uint256 maxWithdraw = vault.maxWithdraw(user1);
        assertEq(maxWithdraw, depositAmount);
        vm.stopPrank();
    }
    
    // ========== FUZZING TESTS ==========
    
    function testFuzz_Deposit(uint256 amount) public {
        // Limitar el rango del fuzz
        vm.assume(amount >= vault.minDepositAmount());
        vm.assume(amount <= vault.maxTotalAssets());
        vm.assume(amount <= 10_000e6); // Límite del balance de user1
        
        vm.startPrank(user1);
        usdc.approve(address(vault), amount);
        uint256 shares = vault.deposit(amount, user1);
        vm.stopPrank();
        
        assertEq(shares, amount);
        assertEq(vault.balanceOf(user1), amount);
    }
    
    function testFuzz_DepositAndWithdraw(uint256 amount) public {
        vm.assume(amount >= vault.minDepositAmount());
        vm.assume(amount <= 10_000e6);
        
        vm.startPrank(user1);
        
        // Depositar
        usdc.approve(address(vault), amount);
        vault.deposit(amount, user1);
        
        // Retirar todo
        uint256 balanceBefore = usdc.balanceOf(user1);
        vault.withdraw(amount, user1, user1);
        uint256 balanceAfter = usdc.balanceOf(user1);
        
        vm.stopPrank();
        
        // Debería recibir exactamente lo que depositó
        assertEq(balanceAfter - balanceBefore, amount);
        assertEq(vault.balanceOf(user1), 0);
    }
}


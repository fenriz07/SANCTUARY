// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {VaultToken} from "../src/VaultToken.sol";
import {VaultTokenV2} from "../src/VaultTokenV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @notice Mock USDC para testing
 */
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        _mint(msg.sender, 10_000_000e6); // 10M USDC
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title VaultTokenUpgradeTest
 * @notice Tests del proceso de upgrade de V1 -> V2 usando UUPS
 * @dev Verifica que:
 *      1. El upgrade preserva storage
 *      2. Nuevas funcionalidades de V2 funcionan
 *      3. Funcionalidades de V1 siguen funcionando después del upgrade
 */
contract VaultTokenUpgradeTest is Test {
    VaultToken public vaultTokenV1;
    VaultTokenV2 public vaultTokenV2;
    VaultToken public implementationV1;
    VaultTokenV2 public implementationV2;
    ERC1967Proxy public proxy;
    MockUSDC public usdc;
    
    address public owner;
    address public treasury;
    address public user1;
    address public user2;
    
    function setUp() public {
        // Crear addresses
        owner = makeAddr("owner");
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy USDC
        usdc = new MockUSDC();
        
        // === DEPLOY V1 ===
        
        // Deploy implementation V1
        implementationV1 = new VaultToken();
        
        // Preparar init data
        bytes memory initData = abi.encodeWithSelector(
            VaultToken.initialize.selector,
            IERC20(address(usdc)),
            "Vault USDC",
            "vUSDC",
            treasury,
            owner
        );
        
        // Deploy proxy apuntando a V1
        proxy = new ERC1967Proxy(address(implementationV1), initData);
        
        // Wrap proxy
        vaultTokenV1 = VaultToken(address(proxy));
        
        // Setup inicial: dar USDC a users
        usdc.transfer(user1, 100_000e6);
        usdc.transfer(user2, 100_000e6);
    }
    
    // ========== V1 FUNCTIONALITY TESTS ==========
    
    function test_V1_WorksBeforeUpgrade() public {
        assertEq(vaultTokenV1.version(), "1.0.0", "Should be V1");
        
        // Depositar en V1
        vm.startPrank(user1);
        usdc.approve(address(vaultTokenV1), 1000e6);
        uint256 shares = vaultTokenV1.deposit(1000e6, user1);
        vm.stopPrank();
        
        assertGt(shares, 0, "Should receive shares in V1");
        assertEq(vaultTokenV1.totalAssets(), 1000e6);
    }
    
    // ========== UPGRADE TESTS ==========
    
    function test_Upgrade_FromV1ToV2() public {
        // 1. Depositar algo en V1 (crear state)
        vm.startPrank(user1);
        usdc.approve(address(vaultTokenV1), 5000e6);
        uint256 sharesV1 = vaultTokenV1.deposit(5000e6, user1);
        vm.stopPrank();
        
        uint256 tvlBeforeUpgrade = vaultTokenV1.totalAssets();
        uint256 user1SharesBeforeUpgrade = vaultTokenV1.balanceOf(user1);
        
        // 2. Deploy nueva implementación V2
        implementationV2 = new VaultTokenV2();
        
        // 3. Upgrade el proxy a V2 (solo owner puede)
        vm.prank(owner);
        vaultTokenV1.upgradeToAndCall(
            address(implementationV2),
            abi.encodeWithSelector(VaultTokenV2.initializeV2.selector)
        );
        
        // 4. Ahora el proxy apunta a V2
        vaultTokenV2 = VaultTokenV2(address(proxy));
        
        // ========== VERIFICACIONES POST-UPGRADE ==========
        
        // Verificar que la versión cambió
        assertEq(vaultTokenV2.version(), "2.0.0", "Should be V2 after upgrade");
        
        // Verificar que el storage se preservó
        assertEq(vaultTokenV2.totalAssets(), tvlBeforeUpgrade, "TVL should be preserved");
        assertEq(vaultTokenV2.balanceOf(user1), user1SharesBeforeUpgrade, "User shares should be preserved");
        assertEq(vaultTokenV2.owner(), owner, "Owner should be preserved");
        assertEq(vaultTokenV2.treasury(), treasury, "Treasury should be preserved");
        assertEq(vaultTokenV2.performanceFee(), 1000, "Performance fee should be preserved");
        
        // Verificar que las nuevas variables de V2 se inicializaron
        assertEq(vaultTokenV2.currentAPY(), 0, "APY should be initialized to 0");
        assertEq(vaultTokenV2.totalProfitsGenerated(), 0, "Total profits should be 0");
        assertGt(vaultTokenV2.lastAPYUpdate(), 0, "Last APY update should be set");
    }
    
    function test_Upgrade_CannotBeCalledByNonOwner() public {
        implementationV2 = new VaultTokenV2();
        
        vm.prank(user1);
        vm.expectRevert();
        vaultTokenV1.upgradeToAndCall(address(implementationV2), "");
    }
    
    function test_Upgrade_CannotInitializeV2Twice() public {
        // Hacer upgrade
        implementationV2 = new VaultTokenV2();
        
        vm.prank(owner);
        vaultTokenV1.upgradeToAndCall(
            address(implementationV2),
            abi.encodeWithSelector(VaultTokenV2.initializeV2.selector)
        );
        
        vaultTokenV2 = VaultTokenV2(address(proxy));
        
        // Intentar inicializar V2 de nuevo
        vm.expectRevert();
        vaultTokenV2.initializeV2();
    }
    
    // ========== V2 NEW FEATURES TESTS ==========
    
    function test_V2_DepositWithDeadline() public {
        // Upgrade a V2
        _upgradeToV2();
        
        uint256 deadline = block.timestamp + 1 hours;
        
        vm.startPrank(user1);
        usdc.approve(address(vaultTokenV2), 1000e6);
        uint256 shares = vaultTokenV2.depositWithDeadline(1000e6, user1, deadline);
        vm.stopPrank();
        
        assertGt(shares, 0, "Should receive shares");
    }
    
    function test_V2_DepositWithDeadline_RevertsIfExpired() public {
        _upgradeToV2();
        
        uint256 deadline = block.timestamp - 1; // Pasado
        
        vm.startPrank(user1);
        usdc.approve(address(vaultTokenV2), 1000e6);
        
        vm.expectRevert(VaultTokenV2.DeadlineExpired.selector);
        vaultTokenV2.depositWithDeadline(1000e6, user1, deadline);
        vm.stopPrank();
    }
    
    function test_V2_EmergencyWithdraw() public {
        _upgradeToV2();
        
        // Setup: user1 deposita
        vm.startPrank(user1);
        usdc.approve(address(vaultTokenV2), 1000e6);
        vaultTokenV2.deposit(1000e6, user1);
        vm.stopPrank();
        
        // Owner habilita emergency withdraw para user1
        vm.prank(owner);
        vaultTokenV2.setEmergencyWithdrawEnabled(user1, true);
        
        // User1 hace emergency withdraw
        uint256 balanceBefore = usdc.balanceOf(user1);
        
        vm.prank(user1);
        vaultTokenV2.emergencyWithdraw(500e6, user1, user1);
        
        uint256 balanceAfter = usdc.balanceOf(user1);
        
        assertEq(balanceAfter - balanceBefore, 500e6, "Should receive withdrawn amount");
    }
    
    function test_V2_EmergencyWithdraw_RevertsIfNotEnabled() public {
        _upgradeToV2();
        
        vm.startPrank(user1);
        usdc.approve(address(vaultTokenV2), 1000e6);
        vaultTokenV2.deposit(1000e6, user1);
        
        // Intentar emergency withdraw sin estar habilitado
        vm.expectRevert(VaultTokenV2.EmergencyWithdrawNotEnabled.selector);
        vaultTokenV2.emergencyWithdraw(500e6, user1, user1);
        vm.stopPrank();
    }
    
    function test_V2_UpdateAPY() public {
        _upgradeToV2();
        
        // Depositar algo para tener TVL
        vm.startPrank(user1);
        usdc.approve(address(vaultTokenV2), 10_000e6);
        vaultTokenV2.deposit(10_000e6, user1);
        vm.stopPrank();
        
        // Simular paso de tiempo
        vm.warp(block.timestamp + 30 days);
        
        // Actualizar APY
        uint256 apy = vaultTokenV2.updateAPY();
        
        assertEq(vaultTokenV2.currentAPY(), apy, "APY should be updated");
        assertEq(vaultTokenV2.lastAPYUpdate(), block.timestamp, "Last update should be now");
    }
    
    function test_V2_GetVaultInfo() public {
        _upgradeToV2();
        
        vm.startPrank(user1);
        usdc.approve(address(vaultTokenV2), 5000e6);
        vaultTokenV2.deposit(5000e6, user1);
        vm.stopPrank();
        
        (
            uint256 tvl,
            uint256 apy,
            uint256 perfFee,
            uint256 mgmtFee,
            uint256 totalProfit,
            string memory vaultVersion
        ) = vaultTokenV2.getVaultInfo();
        
        assertEq(tvl, 5000e6, "TVL should match");
        assertEq(perfFee, 1000, "Performance fee should match");
        assertEq(mgmtFee, 100, "Management fee should match");
        assertEq(vaultVersion, "2.0.0", "Version should be 2.0.0");
    }
    
    // ========== V1 FEATURES STILL WORK IN V2 ==========
    
    function test_V2_V1DepositStillWorks() public {
        _upgradeToV2();
        
        vm.startPrank(user1);
        usdc.approve(address(vaultTokenV2), 1000e6);
        uint256 shares = vaultTokenV2.deposit(1000e6, user1);
        vm.stopPrank();
        
        assertGt(shares, 0, "V1 deposit should still work in V2");
    }
    
    function test_V2_V1WithdrawStillWorks() public {
        _upgradeToV2();
        
        vm.startPrank(user1);
        usdc.approve(address(vaultTokenV2), 1000e6);
        vaultTokenV2.deposit(1000e6, user1);
        
        vaultTokenV2.withdraw(500e6, user1, user1);
        vm.stopPrank();
        
        assertEq(vaultTokenV2.totalAssets(), 500e6, "V1 withdraw should still work");
    }
    
    function test_V2_V1AdminFunctionsStillWork() public {
        _upgradeToV2();
        
        vm.startPrank(owner);
        
        // Update fees (V1 function)
        vaultTokenV2.updateFees(1200, 150);
        assertEq(vaultTokenV2.performanceFee(), 1200);
        
        // Pause (V1 function)
        vaultTokenV2.pause();
        assertTrue(vaultTokenV2.paused());
        
        vaultTokenV2.unpause();
        assertFalse(vaultTokenV2.paused());
        
        vm.stopPrank();
    }
    
    // ========== STORAGE COLLISION TESTS ==========
    
    function test_NoStorageCollision() public {
        // Depositar en V1
        vm.startPrank(user1);
        usdc.approve(address(vaultTokenV1), 1000e6);
        vaultTokenV1.deposit(1000e6, user1);
        vm.stopPrank();
        
        // Cambiar fees en V1
        vm.prank(owner);
        vaultTokenV1.updateFees(1500, 200);
        
        uint256 perfFeeBeforeUpgrade = vaultTokenV1.performanceFee();
        uint256 mgmtFeeBeforeUpgrade = vaultTokenV1.managementFee();
        
        // Upgrade a V2
        _upgradeToV2();
        
        // Verificar que los fees NO cambiaron (no hubo storage collision)
        assertEq(vaultTokenV2.performanceFee(), perfFeeBeforeUpgrade, "Performance fee should not change");
        assertEq(vaultTokenV2.managementFee(), mgmtFeeBeforeUpgrade, "Management fee should not change");
    }
    
    // ========== HELPER FUNCTIONS ==========
    
    function _upgradeToV2() internal {
        implementationV2 = new VaultTokenV2();
        
        vm.prank(owner);
        vaultTokenV1.upgradeToAndCall(
            address(implementationV2),
            abi.encodeWithSelector(VaultTokenV2.initializeV2.selector)
        );
        
        vaultTokenV2 = VaultTokenV2(address(proxy));
    }
}


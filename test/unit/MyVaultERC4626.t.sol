// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {MyVaultERC4626} from "../../src/MyVaultERC4626.sol";
import {MyERC20} from "../../src/MyERC20.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";

contract MyVaultERC4626Test is Test {
    MyVaultERC4626 public vault;
    MyERC20 public underlying;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        // Deploy underlying token (USDC-like)
        underlying = new MyERC20("USD Coin", "USDC", 6, 1_000_000e6);

        // Deploy vault
        vault = new MyVaultERC4626(
            IERC20(address(underlying)),
            "Vault USDC",
            "vUSDC"
        );

        // Give tokens to users
        underlying.transfer(alice, 10_000e6);
        underlying.transfer(bob, 10_000e6);
        underlying.transfer(charlie, 10_000e6);

        console.log("Vault deployed");
        console.log("Underlying:", address(underlying));
    }

    // ==================== Deposit Tests ====================

    function testDeposit() public {
        uint256 depositAmount = 1000e6;

        vm.startPrank(alice);
        underlying.approve(address(vault), depositAmount);

        uint256 shares = vault.deposit(depositAmount, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), depositAmount);
        assertEq(vault.totalSupply(), shares);

        console.log("Deposited:", depositAmount / 1e6, "USDC");
        console.log("Received:", shares / 1e18, "shares");
    }

    function testFirstDeposit() public {
        // First deposit: 1:1 ratio
        uint256 depositAmount = 1000e6;

        vm.startPrank(alice);
        underlying.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);
        vm.stopPrank();

        // First depositor gets 1:1 shares
        assertEq(shares, depositAmount);
    }

    function testSubsequentDeposit() public {
        // Alice deposits first
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e6);
        vault.deposit(1000e6, alice);
        vm.stopPrank();

        // Bob deposits same amount
        vm.startPrank(bob);
        underlying.approve(address(vault), 1000e6);
        uint256 bobShares = vault.deposit(1000e6, bob);
        vm.stopPrank();

        // Both should have same shares (no yield yet)
        assertEq(vault.balanceOf(alice), vault.balanceOf(bob));
        assertEq(bobShares, 1000e6);
    }

    function testDepositEmitsEvent() public {
        uint256 amount = 1000e6;

        vm.startPrank(alice);
        underlying.approve(address(vault), amount);

        vm.expectEmit(true, true, false, true);
        emit MyVaultERC4626.Deposit(alice, alice, amount, amount);

        vault.deposit(amount, alice);
        vm.stopPrank();
    }

    // ==================== Withdraw Tests ====================

    function testWithdraw() public {
        // Deposit first
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e6);
        vault.deposit(1000e6, alice);

        // Withdraw half
        uint256 withdrawAmount = 500e6;
        uint256 sharesBurned = vault.withdraw(withdrawAmount, alice, alice);
        vm.stopPrank();

        assertEq(underlying.balanceOf(alice), 9_500e6); // Got 500 back
        assertGt(sharesBurned, 0);

        console.log("Withdrew:", withdrawAmount / 1e6, "USDC");
        console.log("Burned:", sharesBurned / 1e18, "shares");
    }

    function testWithdrawAll() public {
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e6);
        uint256 shares = vault.deposit(1000e6, alice);

        // Withdraw all
        vault.redeem(shares, alice, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(underlying.balanceOf(alice), 10_000e6); // Back to original
    }

    function testCannotWithdrawMoreThanBalance() public {
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e6);
        vault.deposit(1000e6, alice);

        vm.expectRevert();
        vault.withdraw(2000e6, alice, alice);
        vm.stopPrank();
    }

    // ==================== Redeem Tests ====================

    function testRedeem() public {
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e6);
        uint256 shares = vault.deposit(1000e6, alice);

        // Redeem half shares
        uint256 assetsReceived = vault.redeem(shares / 2, alice, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), shares / 2);
        assertGt(assetsReceived, 0);
    }

    // ==================== Mint Tests ====================

    function testMint() public {
        uint256 sharesToMint = 1000e6;

        vm.startPrank(alice);
        underlying.approve(address(vault), type(uint256).max);

        uint256 assetsDeposited = vault.mint(sharesToMint, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), sharesToMint);
        assertGt(assetsDeposited, 0);
    }

    // ==================== Conversion Tests ====================

    function testConvertToShares() public {
        // Deposit to establish ratio
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e6);
        vault.deposit(1000e6, alice);
        vm.stopPrank();

        uint256 shares = vault.convertToShares(1000e6);
        assertEq(shares, 1000e6); // 1:1 ratio (no yield)
    }

    function testConvertToAssets() public {
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e6);
        uint256 shares = vault.deposit(1000e6, alice);
        vm.stopPrank();

        uint256 assets = vault.convertToAssets(shares);
        assertEq(assets, 1000e6);
    }

    // ==================== Yield Scenario Tests ====================

    function testYieldDistribution() public {
        console.log("\n=== Yield Distribution Test ===");

        // Alice deposits 1000 USDC
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e6);
        uint256 aliceShares = vault.deposit(1000e6, alice);
        vm.stopPrank();

        console.log("Alice deposited: 1000 USDC");
        console.log("Alice shares:", aliceShares / 1e18);

        // Simulate yield: Send 100 USDC profit to vault
        underlying.transfer(address(vault), 100e6);

        console.log("\nVault earned 100 USDC yield");
        console.log("Total assets:", vault.totalAssets() / 1e6, "USDC");

        // Bob deposits 1000 USDC (after yield)
        vm.startPrank(bob);
        underlying.approve(address(vault), 1000e6);
        uint256 bobShares = vault.deposit(1000e6, bob);
        vm.stopPrank();

        console.log("\nBob deposited: 1000 USDC");
        console.log("Bob shares:", bobShares / 1e18);

        // Bob gets less shares (vault has appreciated)
        assertLt(bobShares, aliceShares);

        console.log("\nAlice got more shares (early depositor benefit)");

        // Both withdraw
        vm.prank(alice);
        uint256 aliceAssets = vault.redeem(aliceShares, alice, alice);

        vm.prank(bob);
        uint256 bobAssets = vault.redeem(bobShares, bob, bob);

        console.log("\nWithdrawal:");
        console.log("Alice got:", aliceAssets / 1e6, "USDC");
        console.log("Bob got:", bobAssets / 1e6, "USDC");

        // Alice profits from yield
        assertGt(aliceAssets, 1000e6);
        assertEq(bobAssets, 1000e6); // Bob gets what he put in
    }

    // ==================== Edge Case Tests ====================

    function testDepositZero() public {
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e6);

        vm.expectRevert(MyVaultERC4626.ZeroAssets.selector);
        vault.deposit(0, alice);
        vm.stopPrank();
    }

    function testWithdrawZero() public {
        vm.expectRevert(MyVaultERC4626.ZeroAssets.selector);
        vault.withdraw(0, alice, alice);
    }

    // ==================== Allowance Tests ====================

    function testWithdrawWithAllowance() public {
        // Alice deposits
        vm.startPrank(alice);
        underlying.approve(address(vault), 1000e6);
        vault.deposit(1000e6, alice);

        // Alice approves Bob to withdraw
        vault.approve(bob, 500e18);
        vm.stopPrank();

        // Bob withdraws on behalf of Alice
        vm.prank(bob);
        vault.withdraw(500e6, bob, alice);

        assertEq(underlying.balanceOf(bob), 10_500e6);
    }

    // ==================== Fuzz Tests ====================

    function testFuzzDeposit(uint256 amount) public {
        amount = bound(amount, 1e6, 10_000e6);

        vm.startPrank(alice);
        underlying.approve(address(vault), amount);

        uint256 shares = vault.deposit(amount, alice);

        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), amount);
        vm.stopPrank();
    }

    function testFuzzRoundTrip(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1e6, 10_000e6);

        vm.startPrank(alice);
        underlying.approve(address(vault), depositAmount);

        uint256 shares = vault.deposit(depositAmount, alice);
        uint256 assets = vault.redeem(shares, alice, alice);

        vm.stopPrank();

        // Should get back what was deposited (minus rounding)
        assertApproxEqAbs(assets, depositAmount, 1);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {MyERC20} from "../../src/MyERC20.sol";

contract MyERC20Test is Test {
    MyERC20 public token;

    // Test accounts
    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // Constants
    uint256 constant INITIAL_SUPPLY = 1_000_000e18; // 1 million tokens

    error WrongAddress();
    error InsufficientBalance();
    error InsufficientAllowance();

    // ==================== Setup ====================

    function setUp() public {
        // Deploy token
        token = new MyERC20("Test Token", "TEST", 18, INITIAL_SUPPLY);

        console.log("Token deployed at:", address(token));
        console.log("Owner balance:", token.balanceOf(owner));
    }

    // ==================== Basic Tests ====================

    function testInitialState() public view {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
    }

    // ==================== Transfer Tests ====================

    function testTransfer() public {
        uint256 amount = 100e18;

        bool success = token.transfer(alice, amount);

        assertTrue(success);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
    }

    function testTransferEmitsEvent() public {
        uint256 amount = 100e18;

        // Expect Transfer event
        vm.expectEmit(true, true, false, true);
        emit MyERC20.Transfer(owner, alice, amount);

        token.transfer(alice, amount);
    }

    function testCannotTransferToZeroAddress() public {
        vm.expectRevert(WrongAddress.selector);
        token.transfer(address(0), 100e18);
    }

    function testCannotTransferInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(InsufficientBalance.selector);
        token.transfer(bob, 1);
    }

    function testTransferFullBalance() public {
        uint256 balance = token.balanceOf(owner);

        token.transfer(alice, balance);

        assertEq(token.balanceOf(owner), 0);
        assertEq(token.balanceOf(alice), balance);
    }

    // ==================== Approval Tests ====================

    function testApprove() public {
        uint256 amount = 100e18;

        bool success = token.approve(alice, amount);

        assertTrue(success);
        assertEq(token.allowance(owner, alice), amount);
    }

    function testApproveEmitsEvent() public {
        uint256 amount = 100e18;

        vm.expectEmit(true, true, false, true);
        emit MyERC20.Approval(owner, alice, amount);

        token.approve(alice, amount);
    }

    function testCannotApproveZeroAddress() public {
        vm.expectRevert(WrongAddress.selector);
        token.approve(address(0), 100e18);
    }

    function testApproveOverwrite() public {
        // First approval
        token.approve(alice, 100e18);
        assertEq(token.allowance(owner, alice), 100e18);

        // Second approval overwrites
        token.approve(alice, 200e18);
        assertEq(token.allowance(owner, alice), 200e18);
    }

    // ==================== TransferFrom Tests ====================

    function testTransferFrom() public {
        uint256 approvalAmount = 100e18;
        uint256 transferAmount = 50e18;

        // Owner approves alice
        token.approve(alice, approvalAmount);

        // Alice transfers from owner to bob
        vm.prank(alice);
        bool success = token.transferFrom(owner, bob, transferAmount);

        assertTrue(success);
        assertEq(token.balanceOf(bob), transferAmount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
        assertEq(
            token.allowance(owner, alice),
            approvalAmount - transferAmount
        );
    }

    function testTransferFromEmitsEvent() public {
        token.approve(alice, 100e18);

        vm.expectEmit(true, true, false, true);
        emit MyERC20.Transfer(owner, bob, 50e18);

        vm.prank(alice);
        token.transferFrom(owner, bob, 50e18);
    }

    function testCannotTransferFromInsufficientAllowance() public {
        token.approve(alice, 50e18);

        vm.prank(alice);
        vm.expectRevert(InsufficientAllowance.selector);
        token.transferFrom(owner, bob, 100e18);
    }

    function testCannotTransferFromInsufficientBalance() public {
        // Alice has no balance but has allowance
        token.approve(bob, 100e18);

        vm.prank(bob);
        vm.expectRevert(InsufficientBalance.selector);
        token.transferFrom(owner, alice, INITIAL_SUPPLY + 1);
    }

    // ==================== Increase/Decrease Allowance Tests ====================

    function testIncreaseAllowance() public {
        token.approve(alice, 100e18);

        token.increaseAllowance(alice, 50e18);

        assertEq(token.allowance(owner, alice), 150e18);
    }

    function testDecreaseAllowance() public {
        token.approve(alice, 100e18);

        token.decreaseAllowance(alice, 50e18);

        assertEq(token.allowance(owner, alice), 50e18);
    }

    function testCannotDecreaseAllowanceBelowZero() public {
        token.approve(alice, 50e18);

        vm.expectRevert(InsufficientAllowance.selector);
        token.decreaseAllowance(alice, 100e18);
    }

    // ==================== Mint/Burn Tests ====================

    function testMint() public {
        uint256 mintAmount = 500e18;
        uint256 totalSupplyBefore = token.totalSupply();

        token.mint(alice, mintAmount);

        assertEq(token.balanceOf(alice), mintAmount);
        assertEq(token.totalSupply(), totalSupplyBefore + mintAmount);
    }

    function testBurn() public {
        uint256 burnAmount = 100e18;
        uint256 totalSupplyBefore = token.totalSupply();
        uint256 balanceBefore = token.balanceOf(owner);

        token.burn(burnAmount);

        assertEq(token.balanceOf(owner), balanceBefore - burnAmount);
        assertEq(token.totalSupply(), totalSupplyBefore - burnAmount);
    }

    function testBurnFrom() public {
        uint256 burnAmount = 100e18;

        // Transfer some tokens to alice
        token.transfer(alice, 200e18);

        // Alice approves owner to burn
        vm.prank(alice);
        token.approve(owner, burnAmount);

        // Owner burns from alice
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 totalSupplyBefore = token.totalSupply();

        token.burnFrom(alice, burnAmount);

        assertEq(token.balanceOf(alice), aliceBalanceBefore - burnAmount);
        assertEq(token.totalSupply(), totalSupplyBefore - burnAmount);
    }

    function testCannotBurnMoreThanBalance() public {
        vm.prank(alice); // alice has 0 balance
        vm.expectRevert(InsufficientBalance.selector);
        token.burn(1);
    }

    // ==================== Fuzz Tests ====================

    function testFuzzTransfer(address to, uint256 amount) public {
        // Assumptions
        vm.assume(to != address(0));
        vm.assume(amount <= token.balanceOf(owner));

        uint256 ownerBalanceBefore = token.balanceOf(owner);
        uint256 toBalanceBefore = token.balanceOf(to);

        token.transfer(to, amount);

        assertEq(token.balanceOf(owner), ownerBalanceBefore - amount);

        if (to == owner) {
            // Self transfer
            assertEq(token.balanceOf(to), ownerBalanceBefore);
        } else {
            assertEq(token.balanceOf(to), toBalanceBefore + amount);
        }
    }

    function testFuzzApprove(address spender, uint256 amount) public {
        vm.assume(spender != address(0));

        token.approve(spender, amount);

        assertEq(token.allowance(owner, spender), amount);
    }

    function testFuzzMint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount <= type(uint256).max - token.totalSupply());

        uint256 totalSupplyBefore = token.totalSupply();
        uint256 balanceBefore = token.balanceOf(to);

        token.mint(to, amount);

        assertEq(token.balanceOf(to), balanceBefore + amount);
        assertEq(token.totalSupply(), totalSupplyBefore + amount);
    }

    // ==================== Invariant Tests ====================

    function invariant_totalSupplyEqualsBalances() public view {
        uint256 sumOfBalances = token.balanceOf(owner) +
            token.balanceOf(alice) +
            token.balanceOf(bob) +
            token.balanceOf(charlie);

        assertLe(sumOfBalances, token.totalSupply());
    }

    // ==================== Gas Tests ====================

    function testGasTransfer() public {
        uint256 gasBefore = gasleft();
        token.transfer(alice, 100e18);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for transfer:", gasUsed);
        assertLt(gasUsed, 100000); // Should be less than 100k gas
    }
}

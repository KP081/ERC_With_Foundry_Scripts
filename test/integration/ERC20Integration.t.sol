// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {MyERC20} from "../../src/MyERC20.sol";
import {DeployERC20} from "../../script/DeployERC20.s.sol";

contract ERC20IntegrationTest is Test {
    DeployERC20 public deployer;
    MyERC20 public token;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        deployer = new DeployERC20();

        address deployerAddr = vm.addr(vm.envUint("ANVIL_PRIVATE_KEY"));
        vm.deal(deployerAddr, 10 ether);

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        DeployERC20.Deployment memory deployment = deployer.run();
        token = deployment.token;

        vm.startPrank(deployerAddr);
        token.transfer(address(this), token.totalSupply());
        vm.stopPrank();
    }

    function testComplitTransferWorkflow() public {
        uint256 aliceAmount = 1000e18;
        token.transfer(alice, aliceAmount);
        assertEq(token.balanceOf(alice), aliceAmount);

        uint256 approvalAmount = 500e18;
        vm.prank(alice);
        token.approve(bob, approvalAmount);
        assertEq(token.allowance(alice, bob), approvalAmount);

        uint256 transferAmount = 300e18;
        vm.prank(bob);
        token.transferFrom(alice, charlie, transferAmount);

        assertEq(token.balanceOf(charlie), transferAmount);
        assertEq(token.balanceOf(alice), aliceAmount - transferAmount);
        assertEq(token.allowance(alice, bob), approvalAmount - transferAmount);
    }

    function testBurnWorkflow() public {
        token.transfer(alice, 1000e18);

        uint256 totalSupplyBefore = token.totalSupply();
        uint256 aliceBalanceBefore = token.balanceOf(alice);

        uint256 burnAmount = 500e18;
        vm.prank(alice);
        token.burn(burnAmount);

        assertEq(token.totalSupply(), totalSupplyBefore - burnAmount);
        assertEq(token.balanceOf(alice), aliceBalanceBefore - burnAmount);
    }

    function testMultipleSpenderWorkflow() public {
        token.transfer(alice, 1000e18);

        vm.startPrank(alice);
        token.approve(bob, 300e18);
        token.approve(charlie, 200e18);
        vm.stopPrank();

        vm.prank(bob);
        token.transferFrom(alice, bob, 100e18);

        vm.prank(charlie);
        token.transferFrom(alice, charlie, 150e18);

        assertEq(token.balanceOf(bob), 100e18);
        assertEq(token.balanceOf(charlie), 150e18);
        assertEq(token.balanceOf(alice), 750e18);
    }

    function testSelfTransferWorkflow() public {
        token.transfer(alice, 1000e18);

        uint256 balanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        token.transfer(alice, 100e18);

        assertEq(token.balanceOf(alice), balanceBefore);
    }

    function testChainTransferFlow() public {
        uint256 amount = 1000e18;

        token.transfer(alice, amount);

        vm.prank(alice);
        token.transfer(bob, 500e18);

        vm.prank(bob);
        token.transfer(charlie, 250e18);

        vm.prank(charlie);
        token.transfer(alice, 100e18);

        assertEq(token.balanceOf(alice), 600e18);
        assertEq(token.balanceOf(bob), 250e18);
        assertEq(token.balanceOf(charlie), 150e18);
    }

    function testHighVolumeWorkflow() public {
        for (uint256 i = 0; i < 50; i++) {
            address user = address(uint160(i + 1000));
            token.transfer(user, 1000e18);
        }

        assertEq(token.balanceOf(address(1000)), 1000e18);
        assertEq(token.balanceOf(address(1049)), 1000e18);
    }

    function testComplexApprovalWorkflow() public {
        token.transfer(alice, 1000e18);

        vm.prank(alice);
        token.approve(bob, 500e18);

        vm.startPrank(alice);
        token.increaseAllowance(bob, 100e18);
        assertEq(token.allowance(alice, bob), 600e18);

        token.decreaseAllowance(bob, 200e18);
        assertEq(token.allowance(alice, bob), 400e18);
        vm.stopPrank();
    }
}

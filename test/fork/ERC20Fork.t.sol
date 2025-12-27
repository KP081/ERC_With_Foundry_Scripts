// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {MyERC20} from "../../src/MyERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20ForkTest is Test {
    MyERC20 public token;

    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address public constant WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    address public alice = makeAddr("alice");

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));

        token = new MyERC20("Fork Test Token", "FORK", 18, 1_000_000e18);

        console.log("Forked block:", block.number);
        console.log("Token deployed at:", address(token));
    }

    function testForkDeployment() public view {
        assertEq(token.totalSupply(), 1_000_000e18);
        assertEq(token.balanceOf(address(this)), 1_000_000e18);
    }

    function testForkTransfer() public {
        token.transfer(alice, 1000e18);
        assertEq(token.balanceOf(alice), 1000e18);
    }

    function testInteractionWithRealUSDC() public {
        IERC20 usdc = IERC20(USDC);

        uint256 whaleBalance = usdc.balanceOf(WHALE);
        console.log("Whale USDC:", whaleBalance / 1e6);

        // Skip test if whale doesn't have enough balance
        if (whaleBalance < 1000e6) {
            console.log("Skipping: Whale has insufficient USDC");
            return;
        }

        vm.startPrank(WHALE);
        usdc.transfer(alice, 1000e6);
        vm.stopPrank();

        assertEq(usdc.balanceOf(alice), 1000e6);
    }

    function testGasOnFork() public {
        uint256 gasBefore = gasleft();
        token.transfer(alice, 100e18);
        console.log("Gas used:", gasBefore - gasleft());
    }
}

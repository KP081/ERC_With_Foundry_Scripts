// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {MyERC1155} from "../../src/MyERC1155.sol";

contract MyERC1155Test is Test {
    MyERC1155 public token;

    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // Token IDs
    uint256 constant GOLD = 1;
    uint256 constant SILVER = 2;
    uint256 constant BRONZE = 3;
    uint256 constant LEGENDARY_SWORD = 100;

    function setUp() public {
        token = new MyERC1155("https://api.game.com/metadata/");
        console.log("ERC-1155 deployed");
    }

    function testMintSingle() public {
        token.mint(alice, GOLD, 100, "");

        assertEq(token.balanceOf(alice, GOLD), 100);
    }

    function testMintBatch() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = GOLD;
        ids[1] = SILVER;
        ids[2] = BRONZE;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;

        token.mintBatch(alice, ids, amounts, "");

        assertEq(token.balanceOf(alice, GOLD), 100);
        assertEq(token.balanceOf(alice, SILVER), 200);
        assertEq(token.balanceOf(alice, BRONZE), 300);
    }

    function testMintEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit MyERC1155.TransferSingle(owner, address(0), alice, GOLD, 100);

        token.mint(alice, GOLD, 100, "");
    }

    function testOnlyOwnerCanMint() public {
        vm.prank(alice);
        vm.expectRevert(MyERC1155.OnlyOwner.selector);
        token.mint(bob, GOLD, 100, "");
    }

    function testBalanceOf() public {
        token.mint(alice, GOLD, 100, "");
        token.mint(alice, SILVER, 50, "");

        assertEq(token.balanceOf(alice, GOLD), 100);
        assertEq(token.balanceOf(alice, SILVER), 50);
        assertEq(token.balanceOf(alice, BRONZE), 0);
    }

    function testBalanceOfBatch() public {
        token.mint(alice, GOLD, 100, "");
        token.mint(alice, SILVER, 200, "");
        token.mint(bob, GOLD, 50, "");
        token.mint(bob, BRONZE, 75, "");

        address[] memory accounts = new address[](4);
        accounts[0] = alice;
        accounts[1] = alice;
        accounts[2] = bob;
        accounts[3] = bob;

        uint256[] memory ids = new uint256[](4);
        ids[0] = GOLD;
        ids[1] = SILVER;
        ids[2] = GOLD;
        ids[3] = BRONZE;

        uint256[] memory balances = token.balanceOfBatch(accounts, ids);

        assertEq(balances[0], 100); // alice's GOLD
        assertEq(balances[1], 200); // alice's SILVER
        assertEq(balances[2], 50); // bob's GOLD
        assertEq(balances[3], 75); // bob's BRONZE
    }

    function testCannotQueryBalanceOfZeroAddress() public {
        vm.expectRevert(MyERC1155.InvalidAddress.selector);
        token.balanceOf(address(0), GOLD);
    }

    function testSafeTransferFrom() public {
        token.mint(alice, GOLD, 100, "");

        vm.prank(alice);
        token.safeTransferFrom(alice, bob, GOLD, 30, "");

        assertEq(token.balanceOf(alice, GOLD), 70);
        assertEq(token.balanceOf(bob, GOLD), 30);
    }

    function testSafeBatchTransferFrom() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = GOLD;
        ids[1] = SILVER;
        ids[2] = BRONZE;

        uint256[] memory mintAmounts = new uint256[](3);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;

        token.mintBatch(alice, ids, mintAmounts, "");

        // Transfer batch
        uint256[] memory transferAmounts = new uint256[](3);
        transferAmounts[0] = 30;
        transferAmounts[1] = 50;
        transferAmounts[2] = 70;

        vm.prank(alice);
        token.safeBatchTransferFrom(alice, bob, ids, transferAmounts, "");

        // Verify
        assertEq(token.balanceOf(alice, GOLD), 70);
        assertEq(token.balanceOf(alice, SILVER), 150);
        assertEq(token.balanceOf(alice, BRONZE), 230);

        assertEq(token.balanceOf(bob, GOLD), 30);
        assertEq(token.balanceOf(bob, SILVER), 50);
        assertEq(token.balanceOf(bob, BRONZE), 70);
    }

    function testCannotTransferInsufficientBalance() public {
        token.mint(alice, GOLD, 100, "");

        vm.prank(alice);
        vm.expectRevert(MyERC1155.InsufficientBalance.selector);
        token.safeTransferFrom(alice, bob, GOLD, 150, "");
    }

    function testCannotTransferWithoutApproval() public {
        token.mint(alice, GOLD, 100, "");

        vm.prank(bob);
        vm.expectRevert(MyERC1155.NotOwnerOrApproved.selector);
        token.safeTransferFrom(alice, charlie, GOLD, 50, "");
    }

    function testSetApprovalForAll() public {
        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        assertTrue(token.isApprovedForAll(alice, bob));
    }

    function testApprovedOperatorCanTransfer() public {
        token.mint(alice, GOLD, 100, "");

        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        // Bob can transfer alice's tokens
        vm.prank(bob);
        token.safeTransferFrom(alice, charlie, GOLD, 50, "");

        assertEq(token.balanceOf(alice, GOLD), 50);
        assertEq(token.balanceOf(charlie, GOLD), 50);
    }

    function testRevokeApproval() public {
        vm.startPrank(alice);
        token.setApprovalForAll(bob, true);
        assertTrue(token.isApprovedForAll(alice, bob));

        token.setApprovalForAll(bob, false);
        assertFalse(token.isApprovedForAll(alice, bob));
        vm.stopPrank();
    }

    function testBurn() public {
        token.mint(alice, GOLD, 100, "");

        vm.prank(alice);
        token.burn(alice, GOLD, 30);

        assertEq(token.balanceOf(alice, GOLD), 70);
    }

    function testBurnBatch() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = GOLD;
        ids[1] = SILVER;
        ids[2] = BRONZE;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;

        token.mintBatch(alice, ids, amounts, "");

        // Burn batch
        uint256[] memory burnAmounts = new uint256[](3);
        burnAmounts[0] = 30;
        burnAmounts[1] = 50;
        burnAmounts[2] = 70;

        vm.prank(alice);
        token.burnBatch(alice, ids, burnAmounts);

        assertEq(token.balanceOf(alice, GOLD), 70);
        assertEq(token.balanceOf(alice, SILVER), 150);
        assertEq(token.balanceOf(alice, BRONZE), 230);
    }

    function testApprovedOperatorCanBurn() public {
        token.mint(alice, GOLD, 100, "");

        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.prank(bob);
        token.burn(alice, GOLD, 30);

        assertEq(token.balanceOf(alice, GOLD), 70);
    }

    function testURI() public view {
        string memory tokenURI = token.uri(GOLD);
        assertEq(tokenURI, "https://api.game.com/metadata/1.json");
    }

    function testSetTokenURI() public {
        token.setTokenURI(
            LEGENDARY_SWORD,
            "https://special.com/legendary.json"
        );

        string memory tokenURI = token.uri(LEGENDARY_SWORD);
        assertEq(tokenURI, "https://special.com/legendary.json");
    }

    function testGamingScenario() public {
        console.log("\n=== Gaming Scenario ===");

        // Player gets rewards
        uint256[] memory rewardIds = new uint256[](3);
        rewardIds[0] = GOLD;
        rewardIds[1] = SILVER;
        rewardIds[2] = BRONZE;

        uint256[] memory rewardAmounts = new uint256[](3);
        rewardAmounts[0] = 50;
        rewardAmounts[1] = 100;
        rewardAmounts[2] = 200;

        token.mintBatch(alice, rewardIds, rewardAmounts, "");

        console.log("Alice got rewards:");
        console.log("  GOLD:", token.balanceOf(alice, GOLD));
        console.log("  SILVER:", token.balanceOf(alice, SILVER));
        console.log("  BRONZE:", token.balanceOf(alice, BRONZE));

        // Player trades with another player
        vm.prank(alice);
        token.safeTransferFrom(alice, bob, GOLD, 20, "");

        console.log("\nAfter trade with Bob:");
        console.log("  Alice GOLD:", token.balanceOf(alice, GOLD));
        console.log("  Bob GOLD:", token.balanceOf(bob, GOLD));

        // Player burns items for crafting
        vm.prank(alice);
        token.burn(alice, SILVER, 50);

        console.log("\nAfter crafting (burned 50 SILVER):");
        console.log("  Alice SILVER:", token.balanceOf(alice, SILVER));
    }

    function testGasSingleTransfer() public {
        token.mint(alice, GOLD, 100, "");

        vm.prank(alice);
        uint256 gasBefore = gasleft();
        token.safeTransferFrom(alice, bob, GOLD, 50, "");
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas for single transfer:", gasUsed);
    }

    function testGasBatchTransfer() public {
        uint256[] memory ids = new uint256[](5);
        uint256[] memory amounts = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            ids[i] = i + 1;
            amounts[i] = 100;
        }

        token.mintBatch(alice, ids, amounts, "");

        vm.prank(alice);
        uint256 gasBefore = gasleft();
        token.safeBatchTransferFrom(alice, bob, ids, amounts, "");
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas for batch transfer (5 tokens):", gasUsed);
    }
}

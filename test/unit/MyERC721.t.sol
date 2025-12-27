// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {MyERC721} from "../../src/MyERC721.sol";

contract MyERC721Test is Test {
    MyERC721 public nft;

    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        nft = new MyERC721("MyNFT", "MNFT");
        console.log("NFT deploy at : ", address(nft));
    }

    function testInitialState() public view {
        assertEq(nft.name(), "MyNFT");
        assertEq(nft.symbol(), "MNFT");
        assertEq(nft.totalSupply(), 0);
    }

    function testMint() public {
        uint256 tokenId = nft.mint(alice);

        assertEq(tokenId, 0);
        assertEq(nft.ownerOf(tokenId), alice);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.totalSupply(), 1);
    }

    function testMintMultiple() public {
        uint256 token1 = nft.mint(alice);
        uint256 token2 = nft.mint(alice);
        uint256 token3 = nft.mint(bob);

        assertEq(token1, 0);
        assertEq(token2, 1);
        assertEq(token3, 2);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.balanceOf(bob), 1);
    }

    function testMintEmitEvent() public {
        vm.expectEmit(true, true, true, true);
        emit MyERC721.Transfer(address(0), alice, 0);

        nft.mint(alice);
    }

    function testCanNotMintToZeroAddress() public {
        vm.expectRevert(MyERC721.InvalidAddress.selector);
        nft.mint(address(0));
    }

    function testTransferFrom() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        nft.transferFrom(alice, bob, tokenId);

        assertEq(nft.ownerOf(tokenId), bob);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
    }

    function testTransfrFromEmitsEvent() public {
        uint256 tokenId = nft.mint(alice);

        vm.expectEmit(true, true, true, true);
        emit MyERC721.Transfer(alice, bob, tokenId);

        vm.prank(alice);
        nft.transferFrom(alice, bob, tokenId);
    }

    function testCannotTransferNotOwned() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(bob);
        vm.expectRevert(MyERC721.NotOwnerOrApproved.selector);
        nft.transferFrom(alice, bob, tokenId);
    }

    function testCannotTransferToZeroAddress() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        vm.expectRevert(MyERC721.InvalidAddress.selector);
        nft.transferFrom(alice, address(0), tokenId);
    }

    function testCannotTransferNonExistentToken() public {
        vm.expectRevert(MyERC721.TokenDoesNotExist.selector);
        nft.transferFrom(alice, bob, 999);
    }

    function testApprove() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        nft.approve(bob, tokenId);

        assertEq(nft.getApproved(tokenId), bob);
    }

    function testApproveEmitsEvent() public {
        uint256 tokenId = nft.mint(alice);

        vm.expectEmit(true, true, true, true);
        emit MyERC721.Approval(alice, bob, tokenId);

        vm.prank(alice);
        nft.approve(bob, tokenId);
    }

    function testCannotApproveToOwner() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        vm.expectRevert(MyERC721.ApprovalToCurrentOwner.selector);
        nft.approve(alice, tokenId);
    }

    function testCannotApproveNotOwner() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(bob);
        vm.expectRevert(MyERC721.NotOwnerOrApproved.selector);
        nft.approve(charlie, tokenId);
    }

    function testTransferClearsApproval() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        nft.approve(bob, tokenId);

        vm.prank(alice);
        nft.transferFrom(alice, charlie, tokenId);

        assertEq(nft.getApproved(tokenId), address(0));
    }

    function testApprovedCanTransfer() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        nft.approve(bob, tokenId);

        vm.prank(bob);
        nft.transferFrom(alice, charlie, tokenId);

        assertEq(nft.ownerOf(tokenId), charlie);
    }

    function testSetApprovelForAll() public {
        vm.prank(alice);
        nft.setApprovalForAll(bob, true);

        assertTrue(nft.isApprovedForAll(alice, bob));
    }

    function testSetApprovalForAllEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit MyERC721.ApprovalForAll(alice, bob, true);

        vm.prank(alice);
        nft.setApprovalForAll(bob, true);
    }

    function testCannotSetApprovalForSelf() public {
        vm.prank(alice);
        vm.expectRevert(MyERC721.ApprovalToCurrentOwner.selector);
        nft.setApprovalForAll(alice, true);
    }

    function testOperatorCanTransferAll() public {
        uint256 token1 = nft.mint(alice);
        uint256 token2 = nft.mint(alice);

        vm.prank(alice);
        nft.setApprovalForAll(bob, true);

        vm.startPrank(bob);

        nft.transferFrom(alice, charlie, token1);
        nft.transferFrom(alice, charlie, token2);

        vm.stopPrank();

        assertEq(nft.ownerOf(token1), charlie);
        assertEq(nft.ownerOf(token2), charlie);
        assertEq(nft.balanceOf(charlie), 2);
    }

    function testRevokeApprovalForAll() public {
        vm.startPrank(alice);
        nft.setApprovalForAll(bob, true);
        assertTrue(nft.isApprovedForAll(alice, bob));

        nft.setApprovalForAll(bob, false);
        assertFalse(nft.isApprovedForAll(alice, bob));
        vm.stopPrank();
    }

    function testSafeTransferFromToEOA() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        nft.safeTransferFrom(alice, bob, tokenId, "");

        assertEq(nft.ownerOf(tokenId), bob);
    }

    function testSafeTransferFromWithData() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        nft.safeTransferFrom(alice, bob, tokenId, "test data");

        assertEq(nft.ownerOf(tokenId), bob);
    }

    function testBurn() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        nft.burn(tokenId);

        vm.expectRevert(MyERC721.TokenDoesNotExist.selector);
        nft.ownerOf(tokenId);

        assertEq(nft.balanceOf(alice), 0);
    }

    function testBurnEmitsEvent() public {
        uint256 tokenId = nft.mint(alice);

        vm.expectEmit(true, true, true, true);
        emit MyERC721.Transfer(alice, address(0), tokenId);

        vm.prank(alice);
        nft.burn(tokenId);
    }

    function testCannotBurnNotOwned() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(bob);
        vm.expectRevert(MyERC721.NotOwnerOrApproved.selector);
        nft.burn(tokenId);
    }

    function testApprovedCanBurn() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        nft.approve(bob, tokenId);

        vm.prank(bob);
        nft.burn(tokenId);

        vm.expectRevert(MyERC721.TokenDoesNotExist.selector);
        nft.ownerOf(tokenId);
    }

    function testTokenURI() public {
        nft.setBaseURI("https://example.com/metadata/");
        uint256 tokenId = nft.mint(alice);

        string memory uri = nft.tokenURI(tokenId);
        assertEq(uri, "https://example.com/metadata/0.json");
    }

    function testTokenURIMultiple() public {
        nft.setBaseURI("ipfs://QmHash/");

        nft.mint(alice);
        nft.mint(bob);
        nft.mint(charlie);

        assertEq(nft.tokenURI(0), "ipfs://QmHash/0.json");
        assertEq(nft.tokenURI(1), "ipfs://QmHash/1.json");
        assertEq(nft.tokenURI(2), "ipfs://QmHash/2.json");
    }

    function testCannotGetURIOfNonExistent() public {
        vm.expectRevert(MyERC721.TokenDoesNotExist.selector);
        nft.tokenURI(999);
    }

    function testFuzzMint(address to, uint256 count) public {
        vm.assume(to != address(0));
        vm.assume(count > 0 && count <= 100);

        for (uint i = 0; i < count; i++) {
            nft.mint(to);
        }

        assertEq(nft.balanceOf(to), count);
        assertEq(nft.totalSupply(), count);
    }

    function testFuzzTrasfer(address from, address to, uint256 tokenId) public {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(tokenId < 1000);

        nft.mintTokenId(from, tokenId);

        vm.prank(from);
        nft.transferFrom(from, to, tokenId);

        assertEq(nft.ownerOf(tokenId), to);
    }

    function testGasMint() public {
        uint256 gasBefore = gasleft();
        nft.mint(alice);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas for mint:", gasUsed);
        assertLt(gasUsed, 100000);
    }

    function testGasTransfer() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        uint256 gasBefore = gasleft();
        nft.transferFrom(alice, bob, tokenId);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas for transfer:", gasUsed);
        assertLt(gasUsed, 100000);
    }
}

contract ERC721ReceiverMock {
    bool public shouldAccept;

    constructor(bool _shouldAccept) {
        shouldAccept = _shouldAccept;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external view returns (bytes4) {
        if (shouldAccept) {
            return this.onERC721Received.selector;
        } else {
            return bytes4(0);
        }
    }
}

contract ERC721ReceiverTest is Test {
    MyERC721 public nft;
    address public alice = makeAddr("alice");

    function setUp() public {
        nft = new MyERC721("Test", "TST");
    }

    function testSafeTransferToValidReceiver() public {
        ERC721ReceiverMock receiver = new ERC721ReceiverMock(true);
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        nft.safeTransferFrom(alice, address(receiver), tokenId, "");

        assertEq(nft.ownerOf(tokenId), address(receiver));
    }

    function testCannotSafeTransferToInvalidReceiver() public {
        ERC721ReceiverMock receiver = new ERC721ReceiverMock(false);
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        vm.expectRevert(MyERC721.TransferToNonReceiver.selector);
        nft.safeTransferFrom(alice, address(receiver), tokenId, "");
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarketplace} from "../../src/NFTMarketplace.sol";
import {MyERC721WithERC2981Royalty} from "../../src/MyERC721WithERC2981Royalty.sol";
import {MyERC20} from "../../src/MyERC20.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace public marketPlace;
    MyERC721WithERC2981Royalty public nft;
    MyERC20 public paymentToken;

    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public creator = makeAddr("creator");

    uint256 public constant PLATFORM_FEE = 250;
    uint96 public constant ROYALTY_FEE = 500;

    function setUp() public {
        marketPlace = new NFTMarketplace(PLATFORM_FEE);

        nft = new MyERC721WithERC2981Royalty(
            "Test NFT",
            "TNFT",
            creator,
            ROYALTY_FEE
        );

        paymentToken = new MyERC20("USDC", "USDC", 6, 1_000_000e6);

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        paymentToken.transfer(alice, 10_000e6);
        paymentToken.transfer(bob, 10_000e6);
        paymentToken.transfer(charlie, 10_000e6);
    }

    function testListItem() public {
        vm.prank(alice);
        uint256 tokenId = nft.mint(alice);

        vm.startPrank(alice);

        nft.approve(address(marketPlace), tokenId);
        bytes32 listingId = marketPlace.listItem(
            address(nft),
            tokenId,
            1 ether,
            address(0)
        );

        vm.stopPrank();

        NFTMarketplace.Listing memory listing = marketPlace.getListing(
            listingId
        );

        assertEq(listing.seller, alice);
        assertEq(listing.price, 1 ether);
        assertTrue(listing.active);
    }

    function testCannotListWithoutApproval() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        vm.expectRevert(NFTMarketplace.NotApproved.selector);
        marketPlace.listItem(address(nft), tokenId, 1 ether, address(0));
    }

    function testCannotListNotOwned() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice);

        vm.prank(bob);
        vm.expectRevert(NFTMarketplace.NotNFTOwner.selector);
        marketPlace.listItem(address(nft), tokenId, 1 ether, address(0));
    }

    function testBuyWithETH() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice);

        vm.startPrank(alice);

        nft.approve(address(marketPlace), tokenId);
        bytes32 listingId = marketPlace.listItem(
            address(nft),
            tokenId,
            10 ether,
            address(0)
        );

        vm.stopPrank();

        uint256 aliceBefore = alice.balance;
        uint256 creatorBalBefore = creator.balance;

        vm.prank(bob);
        marketPlace.buyItem{value: 10 ether}(listingId);

        assertEq(nft.ownerOf(tokenId), bob);

        // Verify payments (10 ETH = 10,000,000,000,000,000,000 wei)
        // Royalty: 5% = 0.5 ETH
        // Platform: 2.5% = 0.25 ETH
        // Seller: 92.5% = 9.25 ETH
        assertEq(creator.balance - creatorBalBefore, 0.5 ether);
        assertEq(alice.balance - aliceBefore, 9.25 ether);
    }

    function testBuyWithERC20() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice);

        vm.startPrank(alice);

        nft.approve(address(marketPlace), tokenId);
        bytes32 listingId = marketPlace.listItem(
            address(nft),
            tokenId,
            1000e6,
            address(paymentToken)
        );

        vm.stopPrank();

        vm.startPrank(bob);

        paymentToken.approve(address(marketPlace), 1000e6);
        marketPlace.buyItem(listingId);

        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), bob);

        // Verify payments
        // Royalty: 5% = 50 USDC
        // Platform: 2.5% = 25 USDC
        // Seller: 92.5% = 925 USDC
        assertEq(paymentToken.balanceOf(creator), 50e6);
        assertEq(paymentToken.balanceOf(alice), 10_925e6);
    }

    function testCannotBuyInactiveListing() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice);

        vm.startPrank(alice);
        nft.approve(address(marketPlace), tokenId);
        bytes32 listingId = marketPlace.listItem(
            address(nft),
            tokenId,
            1 ether,
            address(0)
        );

        // Cancel listing
        marketPlace.cancelListing(listingId);
        vm.stopPrank();

        // Try to buy
        vm.prank(bob);
        vm.expectRevert(NFTMarketplace.ListingNotActive.selector);
        marketPlace.buyItem{value: 1 ether}(listingId);
    }

    function testMakeOfferETH() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice);

        vm.prank(bob);
        bytes32 offerId = marketPlace.makeOffer{value: 5 ether}(
            address(nft),
            tokenId,
            5 ether,
            address(0),
            7 days
        );

        NFTMarketplace.Offer memory offer = marketPlace.getOffer(
            address(nft),
            tokenId,
            offerId
        );

        assertEq(offer.offerer, bob);
        assertEq(offer.price, 5 ether);
        assertTrue(offer.active);
    }

    function testAcceptOffer() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice);

        // Bob makes offer
        vm.prank(bob);
        bytes32 offerId = marketPlace.makeOffer{value: 10 ether}(
            address(nft),
            tokenId,
            10 ether,
            address(0),
            7 days
        );

        // Alice accepts
        vm.startPrank(alice);
        nft.approve(address(marketPlace), tokenId);

        uint256 aliceBalBefore = alice.balance;
        marketPlace.acceptOffer(address(nft), tokenId, offerId);
        vm.stopPrank();

        // Verify NFT transferred
        assertEq(nft.ownerOf(tokenId), bob);

        // Verify alice got paid (minus fees)
        assertGt(alice.balance, aliceBalBefore);
    }

    function testCancelOffer() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice);

        vm.startPrank(bob);
        uint256 bobBalBefore = bob.balance;

        bytes32 offerId = marketPlace.makeOffer{value: 5 ether}(
            address(nft),
            tokenId,
            5 ether,
            address(0),
            7 days
        );

        // Bob cancels
        marketPlace.cancelOffer(address(nft), tokenId, offerId);
        vm.stopPrank();

        // Verify refund
        assertEq(bob.balance, bobBalBefore);
    }

    function testWithdrawEarnings() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(alice);

        vm.startPrank(alice);
        nft.approve(address(marketPlace), tokenId);
        bytes32 listingId = marketPlace.listItem(
            address(nft),
            tokenId,
            10 ether,
            address(0)
        );
        vm.stopPrank();

        vm.prank(bob);
        marketPlace.buyItem{value: 10 ether}(listingId);

        // Check platform earnings (2.5% of 10 ETH = 0.25 ETH)
        assertEq(marketPlace.platformEarnings(address(0)), 0.25 ether);

        // Owner withdraws
        uint256 ownerBalBefore = owner.balance;

        vm.startPrank(owner);

        marketPlace.withdrawEarnings(address(0));

        vm.stopPrank();

        assertEq(owner.balance - ownerBalBefore, 0.25 ether);
        assertEq(marketPlace.platformEarnings(address(0)), 0);
    }

    function testSetPlatformFee() public {
        marketPlace.setPlatformFee(300); // 3%
        assertEq(marketPlace.platformFee(), 300);
    }

    function testCannotSetFeeTooHigh() public {
        vm.expectRevert(NFTMarketplace.FeeTooHigh.selector);
        marketPlace.setPlatformFee(1001); // >10%
    }

    function testMultipleListings() public {
        // Mint multiple NFTs
        vm.prank(owner);
        uint256 token1 = nft.mint(alice);
        vm.prank(owner);
        uint256 token2 = nft.mint(alice);

        // Alice lists both
        vm.startPrank(alice);
        nft.setApprovalForAll(address(marketPlace), true);

        bytes32 listing1 = marketPlace.listItem(
            address(nft),
            token1,
            1 ether,
            address(0)
        );

        bytes32 listing2 = marketPlace.listItem(
            address(nft),
            token2,
            2 ether,
            address(0)
        );
        vm.stopPrank();

        // Both should be active
        assertTrue(marketPlace.getListing(listing1).active);
        assertTrue(marketPlace.getListing(listing2).active);
    }

    receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {MyERC721WithERC2981Royalty} from "../../src/MyERC721WithERC2981Royalty.sol";

contract MyERC721WithRoyaltyTest is Test {
    MyERC721WithERC2981Royalty public nft;

    address public creator = makeAddr("creator");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public marketplace = makeAddr("marketplace");

    uint96 public constant DEFAULT_ROYALTY = 250; // 2.5%

    function setUp() public {
        // Deploy NFT with 2.5% default royalty to creator
        nft = new MyERC721WithERC2981Royalty(
            "Royalty NFT",
            "RNFT",
            creator,
            DEFAULT_ROYALTY
        );
    }

    function testDefaultRoyaltySet() public view {
        (address receiver, uint96 royaltyFraction) = nft
            .getDefaultRoyaltyInfo();

        assertEq(receiver, creator);
        assertEq(royaltyFraction, DEFAULT_ROYALTY);
    }

    function testRoyaltyCalculationDefault() public {
        uint256 tokenId = nft.mint(alice);

        uint256 salePrice = 10 ether;
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(
            tokenId,
            salePrice
        );

        // Expected: 10 ETH * 250 / 10000 = 0.25 ETH
        assertEq(receiver, creator);
        assertEq(royaltyAmount, 0.25 ether);
    }

    function testRoyaltyCalculationVariousPrices() public {
        uint256 tokenId = nft.mint(alice);

        // Test different sale prices
        uint256[] memory prices = new uint256[](5);
        prices[0] = 1 ether;
        prices[1] = 5 ether;
        prices[2] = 10 ether;
        prices[3] = 100 ether;
        prices[4] = 0.1 ether;

        uint256[] memory expectedRoyalties = new uint256[](5);
        expectedRoyalties[0] = 0.025 ether;
        expectedRoyalties[1] = 0.125 ether;
        expectedRoyalties[2] = 0.25 ether;
        expectedRoyalties[3] = 2.5 ether;
        expectedRoyalties[4] = 0.0025 ether;

        for (uint256 i = 0; i < prices.length; i++) {
            (, uint256 royaltyAmount) = nft.royaltyInfo(tokenId, prices[i]);
            assertEq(royaltyAmount, expectedRoyalties[i]);
        }
    }

    function testDifferentRoyaltyPercentages() public {
        MyERC721WithERC2981Royalty nft5 = new MyERC721WithERC2981Royalty(
            "NFT 5%",
            "NFT5",
            creator,
            500 // 5%
        );

        uint256 tokenId = nft5.mint(alice);
        (, uint256 royalty5) = nft5.royaltyInfo(tokenId, 10 ether);
        assertEq(royalty5, 0.5 ether); // 5% of 10 ETH

        MyERC721WithERC2981Royalty nft10 = new MyERC721WithERC2981Royalty(
            "NFT 10%",
            "NFT10",
            creator,
            1000 // 10%
        );

        tokenId = nft10.mint(alice);
        (, uint256 royalty10) = nft10.royaltyInfo(tokenId, 10 ether);
        assertEq(royalty10, 1 ether); // 10% of 10 ETH

        console2.log("5% Royalty:", royalty5 / 1e18, "ETH");
        console2.log("10% Royalty:", royalty10 / 1e18, "ETH");
    }

    function testCannotSetRoyaltyTooHigh() public {
        vm.expectRevert(MyERC721WithERC2981Royalty.RoyaltyTooHigh.selector);
        new MyERC721WithERC2981Royalty(
            "Bad NFT",
            "BAD",
            creator,
            10001 // More than 100%
        );
    }

    function testCannotSetZeroAddressAsReceiver() public {
        vm.expectRevert(
            MyERC721WithERC2981Royalty.InvalidRoyaltyReceiver.selector
        );
        new MyERC721WithERC2981Royalty("Bad NFT", "BAD", address(0), 250);
    }

    function testSetTokenRoyalty() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        nft.setTokenRoyalty(tokenId, alice, 500); // 5%

        (address receiver, uint96 royaltyFraction) = nft.getTokenRoyaltyInfo(
            tokenId
        );
        assertEq(receiver, alice);
        assertEq(royaltyFraction, 500);
    }

    function testTokenRoyaltyOverridesDefault() public {
        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        nft.setTokenRoyalty(tokenId, alice, 1000); // 10%

        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(
            tokenId,
            10 ether
        );

        assertEq(receiver, alice);
        assertEq(royaltyAmount, 1 ether); // 10% of 10 ETH

        console2.log("Custom royalty:", royaltyAmount / 1e18, "ETH");
    }

    function testResetTokenRoyalty() public {
        uint256 tokenId = nft.mint(alice);

        vm.startPrank(alice);
        nft.setTokenRoyalty(tokenId, alice, 1000);

        nft.resetTokenRoyalty(tokenId);
        vm.stopPrank();

        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(
            tokenId,
            10 ether
        );
        assertEq(receiver, creator);
        assertEq(royaltyAmount, 0.25 ether); // Back to 2.5%
    }

    function testOnlyOwnerCanSetTokenRoyalty() public {
        uint256 tokenId = nft.mint(alice);

        // Bob tries to set royalty for Alice's token
        vm.prank(bob);
        vm.expectRevert(MyERC721WithERC2981Royalty.NotOwner.selector);
        nft.setTokenRoyalty(tokenId, bob, 500);
    }

    function testMarketplaceSale() public {
        uint256 tokenId = nft.mint(alice);

        // Later, Alice sells to Bob for 10 ETH on marketplace
        uint256 salePrice = 10 ether;
        (address royaltyReceiver, uint256 royaltyAmount) = nft.royaltyInfo(
            tokenId,
            salePrice
        );

        // Marketplace flow:
        vm.deal(bob, 20 ether);

        vm.startPrank(bob);

        // 1. Bob pays royalty to creator
        (bool sent1, ) = royaltyReceiver.call{value: royaltyAmount}("");
        require(sent1, "Royalty payment failed");

        // 2. Bob pays remaining to Alice
        uint256 sellerAmount = salePrice - royaltyAmount;
        (bool sent2, ) = alice.call{value: sellerAmount}("");
        require(sent2, "Seller payment failed");

        vm.stopPrank();

        // Verify payments
        assertEq(creator.balance, 0.25 ether); // 2.5% royalty
        assertEq(alice.balance, 9.75 ether); // 97.5% to seller
    }

    function testMultipleSalesWithRoyalty() public {
        uint256 tokenId = nft.mint(alice);

        // Sale 1: Alice -> Bob (10 ETH)
        (, uint256 royalty1) = nft.royaltyInfo(tokenId, 10 ether);

        // Transfer token
        vm.prank(alice);
        nft.transferFrom(alice, bob, tokenId);

        // Sale 2: Bob -> Charlie (20 ETH)
        (, uint256 royalty2) = nft.royaltyInfo(tokenId, 20 ether);

        // Creator gets royalty on both sales
        assertEq(royalty1, 0.25 ether); // 2.5% of 10 ETH
        assertEq(royalty2, 0.5 ether); // 2.5% of 20 ETH
    }

    function testBurnClearsRoyalty() public {
        uint256 tokenId = nft.mint(alice);

        vm.startPrank(alice);
        nft.setTokenRoyalty(tokenId, alice, 1000);

        // Burn token
        nft.burn(tokenId);
        vm.stopPrank();

        // Custom royalty should be cleared
        (address receiver, uint96 royaltyFraction) = nft.getTokenRoyaltyInfo(
            tokenId
        );
        assertEq(receiver, address(0));
        assertEq(royaltyFraction, 0);
    }

    function testZeroSalePrice() public {
        uint256 tokenId = nft.mint(alice);

        (, uint256 royaltyAmount) = nft.royaltyInfo(tokenId, 0);
        assertEq(royaltyAmount, 0);
    }

    function testVerySmallSalePrice() public {
        uint256 tokenId = nft.mint(alice);

        // Sale for 1 wei
        (, uint256 royaltyAmount) = nft.royaltyInfo(tokenId, 1);

        // Royalty should round down to 0
        assertEq(royaltyAmount, 0);
    }

    function testMaximumRoyalty() public {
        MyERC721WithERC2981Royalty maxNFT = new MyERC721WithERC2981Royalty(
            "Max Royalty",
            "MAX",
            creator,
            10000 // 100%
        );

        uint256 tokenId = maxNFT.mint(alice);
        (, uint256 royaltyAmount) = maxNFT.royaltyInfo(tokenId, 10 ether);

        // 100% royalty
        assertEq(royaltyAmount, 10 ether);
    }

    function testSupportsERC2981Interface() public view {
        // ERC-2981 interface ID: 0x2a55205a
        assertTrue(nft.supportsInterface(0x2a55205a));
    }

    function testSupportsERC721Interface() public view {
        // ERC-721 interface ID: 0x80ac58cd
        assertTrue(nft.supportsInterface(0x80ac58cd));
    }

    function testFuzzRoyaltyCalculation(
        uint96 royaltyFraction,
        uint256 salePrice
    ) public {
        vm.assume(royaltyFraction <= 10000); // Max 100%
        vm.assume(salePrice <= 1000 ether); // Reasonable price

        MyERC721WithERC2981Royalty fuzzNFT = new MyERC721WithERC2981Royalty(
            "Fuzz NFT",
            "FUZZ",
            creator,
            royaltyFraction
        );

        uint256 tokenId = fuzzNFT.mint(alice);
        (, uint256 royaltyAmount) = fuzzNFT.royaltyInfo(tokenId, salePrice);

        // Verify calculation
        uint256 expectedRoyalty = (salePrice * royaltyFraction) / 10000;
        assertEq(royaltyAmount, expectedRoyalty);

        // Royalty should never exceed sale price
        assertLe(royaltyAmount, salePrice);
    }

    function testFuzzTokenRoyalty(
        address receiver,
        uint96 royaltyFraction
    ) public {
        vm.assume(receiver != address(0));
        vm.assume(royaltyFraction <= 10000);

        uint256 tokenId = nft.mint(alice);

        vm.prank(alice);
        nft.setTokenRoyalty(tokenId, receiver, royaltyFraction);

        (address actualReceiver, uint96 actualFraction) = nft
            .getTokenRoyaltyInfo(tokenId);
        assertEq(actualReceiver, receiver);
        assertEq(actualFraction, royaltyFraction);
    }
}

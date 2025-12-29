// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {MyERC721WithERC2981Royalty} from "../src/MyERC721WithERC2981Royalty.sol";

contract DeployMyERC721WithERC2981Royalty is Script {
    function run() external returns (MyERC721WithERC2981Royalty) {
        uint256 deployerKey = vm.envUint("ANVIL_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);

        // Royalty settings
        address royaltyReceiver = deployer;
        uint96 royaltyPercentage = 250; // 2.5%

        vm.startBroadcast(deployerKey);

        MyERC721WithERC2981Royalty nft = new MyERC721WithERC2981Royalty(
            "Artist Collection",
            "ART",
            royaltyReceiver,
            royaltyPercentage
        );

        // Set base URI
        nft.setBaseURI("https://api.artistcollection.com/metadata/");

        // Mint first NFT
        uint256 tokenId = nft.mint(deployer);

        vm.stopBroadcast();

        console.log("\n[SUCCESS] NFT deployed at:", address(nft));
        console.log("First token minted:", tokenId);

        // Show royalty info
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(
            tokenId,
            10 ether
        );
        console.log("\nRoyalty for 10 ETH sale:");
        console.log("  Receiver:", receiver);
        console.log("  Amount:", royaltyAmount / 1e18, "ETH");

        return nft;
    }
}

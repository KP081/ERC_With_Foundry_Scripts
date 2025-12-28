// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MyERC721} from "../src/MyERC721.sol";

contract DeployERC721 is Script {
    struct Deployment {
        MyERC721 nft;
        address deployer;
    }

    function run() external returns (Deployment memory) {
        uint256 deployerKey = vm.envUint("ANVIL_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance / 1e18, "ETH");
        console.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerKey);

        MyERC721 nft = new MyERC721("MyNFT Collection", "MNFT");

        nft.setBaseURI("https://api.mynft.com/metadata/");

        nft.mint(deployer);

        vm.stopBroadcast();

        console.log("\n[SUCCESS] NFT deployed at:", address(nft));
        console.log("Total Supply:", nft.totalSupply());
        console.log("Deployer Balance:", nft.balanceOf(deployer));

        return Deployment({nft: nft, deployer: deployer});
    }
}

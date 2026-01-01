// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";
import {MyERC721WithERC2981Royalty} from "../src/MyERC721WithERC2981Royalty.sol";
import {MyERC20} from "../src/MyERC20.sol";

contract DeployMarketplace is Script {
    struct Deployment {
        NFTMarketplace marketplace;
        MyERC721WithERC2981Royalty nft;
        MyERC20 paymentToken;
        address deployer;
    }

    uint256 public constant PLATFORM_FEE = 250;
    uint96 public constant ROYALTY_FEE = 500;

    function run() external returns (Deployment memory) {
        uint256 deployerKey = vm.envUint("ANVIL_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        NFTMarketplace marketplace = new NFTMarketplace(PLATFORM_FEE);

        MyERC721WithERC2981Royalty nft = new MyERC721WithERC2981Royalty(
            "Marketplace NFT",
            "MNFT",
            deployer,
            ROYALTY_FEE
        );

        MyERC20 paymentToken = new MyERC20(
            "Marketplace USD",
            "mUSD",
            6,
            1_000_000e6
        );

        nft.setBaseURI("https://api.marketplace.com/metadata/");

        for (uint256 i = 1; i <= 3; i++) {
            nft.mint(deployer);
        }
        console.log("  Minted 3 NFTs to deployer");

        vm.stopBroadcast();

        return
            Deployment({
                marketplace: marketplace,
                nft: nft,
                paymentToken: paymentToken,
                deployer: deployer
            });
    }
}

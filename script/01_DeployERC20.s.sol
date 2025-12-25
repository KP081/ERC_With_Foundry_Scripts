// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {MyERC20} from "../src/MyERC20.sol";

contract DeployERC20 is Script {
    string constant TOKEN_NAME = "My Token";
    string constant TOKEN_SYMBOL = "MT";
    uint8 constant DECIMALS = 18;
    uint256 constant INITIAL_SUPPLY = 1_000_000e18;

    error InsufficientBalance();
    error InvalidPrivateKey();

    function run() external returns (MyERC20) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer Address:", deployer);
        console.log("Deployer Balance:", deployer.balance / 1e18, "ETH");
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);
        console.log("\nToken Details:");
        console.log("  Name:", TOKEN_NAME);
        console.log("  Symbol:", TOKEN_SYMBOL);
        console.log("  Decimals:", uint256(DECIMALS));
        console.log("  Initial Supply:", INITIAL_SUPPLY / 1e18, "tokens");

        console.log("\n--- Pre-Deployment Checks ---");

        if (deployer.balance < 0) revert InsufficientBalance();
        console.log("[OK] Sufficient balance");

        if (deployerPrivateKey == 0) revert InvalidPrivateKey();
        console.log("[OK] Valid private key");

        console.log("\n--- Starting Deployment ---\n");

        vm.startBroadcast(deployerPrivateKey);

        MyERC20 token = new MyERC20(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            DECIMALS,
            INITIAL_SUPPLY
        );

        vm.stopBroadcast();

        _saveDeploymentInfo(address(token), deployer);

        return token;
    }

    function _saveDeploymentInfo(
        address tokenAddress,
        address deployer
    ) private {
        string memory json = string.concat(
            "{",
            '"contract": "MyERC20",',
            '"address": "',
            vm.toString(tokenAddress),
            '",',
            '"deployer": "',
            vm.toString(deployer),
            '",',
            '"chainId": ',
            vm.toString(block.chainid),
            ",",
            '"blockNumber": ',
            vm.toString(block.number),
            ",",
            '"timestamp": ',
            vm.toString(block.timestamp),
            ",",
            '"name": "',
            TOKEN_NAME,
            '",',
            '"symbol": "',
            TOKEN_SYMBOL,
            '",',
            '"decimals": ',
            vm.toString(uint256(DECIMALS)),
            ",",
            '"initialSupply": ',
            vm.toString(INITIAL_SUPPLY),
            ",",
            "}"
        );

        string memory filename = string.concat(
            "deployments/",
            vm.toString(block.chainid),
            "/MyERC20_",
            vm.toString(block.timestamp),
            ".json"
        );

        vm.writeFile(filename, json);

        console.log("\nDeployment info saved to:", filename);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {MyERC20} from "../src/MyERC20.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployERC20 is Script {
    struct Deployment {
        MyERC20 token;
        HelperConfig helperConfig;
    }

    error MainnetDeploymentNotAllowed();
    error InsufficientBalance();
    error InvalidPrivateKey();

    function run() external returns (Deployment memory) {
        HelperConfig helperConfig = new HelperConfig(
            "My Token",
            "MT",
            100_000_000e18
        );
        HelperConfig.NetworkConfig memory config = helperConfig
            .getActiveNetworkConfig();

        _preDeploymentChecks(config, helperConfig);

        vm.startBroadcast(config.deployerKey);

        MyERC20 token = new MyERC20(
            helperConfig.TOKEN_NAME(),
            helperConfig.TOKEN_SYMBOL(),
            18,
            helperConfig.INITIAL_SUPPLY()
        );

        vm.stopBroadcast();

        return Deployment({token: token, helperConfig: helperConfig});
    }

    function _preDeploymentChecks(
        HelperConfig.NetworkConfig memory config,
        HelperConfig helperConfig
    ) private view {
        address deployer = vm.addr(config.deployerKey);

        if (
            helperConfig.isMainnet() ||
            helperConfig.isArbitrum() ||
            helperConfig.isPolygon()
        ) {
            if (!(vm.envOr("ALLOW_MAINNET_DEPLOY", false))) {
                revert MainnetDeploymentNotAllowed();
            }
            console.log("[WARNING] Deploying to MAINNET!");
        }

        if (deployer.balance < 0.01 ether) revert InsufficientBalance();

        if (config.deployerKey == 0) revert InvalidPrivateKey();
    }
}

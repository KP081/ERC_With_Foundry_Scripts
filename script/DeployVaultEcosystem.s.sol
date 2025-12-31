// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {MyERC20} from "../src/MyERC20.sol";
import {VaultWithStrategy} from "../src/VaultWithStrategy.sol";

contract DeployVaultEcosystem is Script {
    error InitialDepositFailed();
    error SharesMismatch();
    error MainnetNotAllowed();
    error InsufficientBalance();

    struct Deployment {
        MyERC20 underlying;
        VaultWithStrategy vault;
        address deployer;
    }

    function run() external returns (Deployment memory) {
        uint256 deployerKey = vm.envUint("ANVIL_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        _preDeploymentChecks(deployer);

        vm.startBroadcast(deployerKey);

        MyERC20 underlying = new MyERC20("Mock USDC", "mUSDC", 6, 10_000_000e6);

        VaultWithStrategy vault = new VaultWithStrategy(
            IERC20(address(underlying)),
            "Vault USDC",
            "vUSDC"
        );

        uint256 initialDeposit = 100_000e6; // 100k USDC
        underlying.approve(address(vault), initialDeposit);
        uint256 shares = vault.deposit(initialDeposit, deployer);

        if (vault.totalAssets() != initialDeposit)
            revert InitialDepositFailed();
        if (vault.balanceOf(deployer) != shares) revert SharesMismatch();

        vm.stopBroadcast();

        return
            Deployment({
                underlying: underlying,
                vault: vault,
                deployer: deployer
            });
    }

    function _preDeploymentChecks(address deployer) private view {
        if (deployer.balance < 0.01 ether) revert InsufficientBalance();

        if (
            block.chainid == 1 || block.chainid == 42161 || block.chainid == 137
        ) {
            if (!vm.envOr("ALLOW_MAINNET_DEPLOY", false))
                revert MainnetNotAllowed();
        }
    }
}

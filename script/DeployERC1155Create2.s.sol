// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {MyERC1155} from "../src/MyERC1155.sol";

contract DeployERC1155SimpleCreate2 is Script {
    error AddressMismatch();

    function run() external returns (MyERC1155) {
        uint256 deployerKey = vm.envUint("ANVIL_PRIVATE_KEY");

        bytes32 salt = bytes32(uint256(vm.envUint("SALT"))); // salt like 12345

        bytes memory creationCode = type(MyERC1155).creationCode;
        bytes memory args = abi.encode("https://api.multitoken.com/");
        bytes memory bytecode = abi.encodePacked(creationCode, args);

        address predicted = vm.computeCreate2Address(salt, keccak256(bytecode));

        console.log("Predicted Address:", predicted);
        console.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerKey);

        // Deploy with CREATE2
        MyERC1155 token = new MyERC1155{salt: salt}(
            "https://api.multitoken.com/"
        );

        vm.stopBroadcast();

        console.log("Deployed Address:", address(token));

        if (address(token) != predicted) {
            revert AddressMismatch();
        }

        return token;
    }
}

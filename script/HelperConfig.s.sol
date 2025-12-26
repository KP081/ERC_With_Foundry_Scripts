// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 deployerKey;
        address existingTokenAddress;
    }

    NetworkConfig public activeNetworkConfig;

    uint256 constant MAINNET_CHAIN_ID = 1;
    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ARBITRUM_CHAIN_ID = 42161;
    uint256 constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    uint256 constant POLYGON_CHAIN_ID = 137;
    uint256 constant ANVIL_CHAIN_ID = 31337;

    string public TOKEN_NAME;
    string public TOKEN_SYMBOL;
    uint256 public immutable INITIAL_SUPPLY;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply
    ) {

        TOKEN_NAME = _name;
        TOKEN_SYMBOL = _symbol;
        INITIAL_SUPPLY = _initialSupply;

        if (block.chainid == MAINNET_CHAIN_ID) {
            activeNetworkConfig = getMainnetConfig();
        } else if (block.chainid == SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaConfig();
        } else if (block.chainid == ARBITRUM_CHAIN_ID) {
            activeNetworkConfig = getArbitrumConfig();
        } else if (block.chainid == ARBITRUM_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getArbitrumSepoliaConfig();
        } else if (block.chainid == POLYGON_CHAIN_ID) {
            activeNetworkConfig = getPolygonConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getMainnetConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                deployerKey: vm.envUint("MAINNET_PRIVATE_KEY"),
                existingTokenAddress: vm.envOr("TOKEN_ADDRESS" , address(0)) // production address if exists
            });
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY"),
                existingTokenAddress: vm.envOr("TOKEN_ADDRESS" , address(0))
            });
    }

    function getArbitrumConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                deployerKey: vm.envUint("ARBITRUM_PRIVATE_KEY"),
                existingTokenAddress: vm.envOr("TOKEN_ADDRESS" , address(0))
            });
    }

    function getArbitrumSepoliaConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                deployerKey: vm.envUint("ARBITRUM_SEPOLIA_PRIVATE_KEY"),
                existingTokenAddress: vm.envOr("TOKEN_ADDRESS" , address(0))
            });
    }

    function getPolygonConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                deployerKey: vm.envUint("POLYGON_PRIVATE_KEY"),
                existingTokenAddress: vm.envOr("TOKEN_ADDRESS" , address(0))
            });
    }

    function getOrCreateAnvilConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                deployerKey: vm.envUint("ANVIL_PRIVATE_KEY"),
                existingTokenAddress: vm.envOr("TOKEN_ADDRESS" , address(0))
            });
    }

    function getActiveNetworkConfig()
        external
        view
        returns (NetworkConfig memory)
    {
        return activeNetworkConfig;
    }

    function isMainnet() public view returns (bool) {
        return block.chainid == MAINNET_CHAIN_ID;
    }

    function isSepolia() public view returns (bool) {
        return block.chainid == SEPOLIA_CHAIN_ID;
    }

    function isArbitrum() public view returns (bool) {
        return block.chainid == ARBITRUM_CHAIN_ID;
    }

    function isArbitrumSepolia() public view returns (bool) {
        return block.chainid == ARBITRUM_SEPOLIA_CHAIN_ID;
    }

    function isPolygon() public view returns (bool) {
        return block.chainid == POLYGON_CHAIN_ID;
    }

    function isLocalChain() public view returns (bool) {
        return block.chainid == ANVIL_CHAIN_ID;
    }
}

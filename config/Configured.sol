// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { StdChains, VmSafe } from "@forge-std/StdChains.sol";

import { Config, ConfigLib } from "config/ConfigLib.sol";

contract Configured is StdChains {
    using ConfigLib for Config;

    VmSafe private constant vm = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    Chain internal chain;
    Config internal config;

    string internal configFilePath;

    address internal vaultAddress;
    address internal usdcAddress;
    address internal metaAddress;
    address internal feeProtocolAddress;

    function _network() internal virtual returns (string memory) {
        Chain memory currentChain = getChain(block.chainid);
        return currentChain.chainAlias;
    }

    function _initConfig() internal returns (Config storage) {
        if (bytes(config.json).length == 0) {
            string memory root = vm.projectRoot();
            configFilePath = string.concat(root, "/config/", _network(), ".json");

            config.json = vm.readFile(configFilePath);
        }

        return config;
    }

    function _loadConfig() internal virtual {
        string memory rpcAlias = config.getRpcAlias();

        chain = getChain(rpcAlias);

        vaultAddress = config.getVaultAddress();
        usdcAddress = config.getUsdcAddress();
        metaAddress = config.getMetaAddress();
        feeProtocolAddress = config.getFeeProtocolAddress();
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { stdJson } from "@forge-std/StdJson.sol";

struct Config {
    string json;
}

library ConfigLib {
    using stdJson for string;

    string internal constant RPC_ALIAS = "$.rpcAlias";
    string internal constant IS_TESTNET = "$.isTestnet";
    string internal constant VAUL_ADDRESS = "$.vaultAddress";
    string internal constant USDC_ADDRESS = "$.usdcAddress";
    string internal constant META_ADDRESS = "$.metaAddress";
    string internal constant FEE_PROTOCOL_ADDRESS = "$.feeProtocolAddress";

    function getAddress(Config storage config, string memory key) internal view returns (address) {
        return config.json.readAddress(string.concat("$.", key));
    }

    function getAddressArray(
        Config storage config,
        string[] memory keys
    )
        internal
        view
        returns (address[] memory addresses)
    {
        addresses = new address[](keys.length);

        for (uint256 i; i < keys.length; ++i) {
            addresses[i] = getAddress(config, keys[i]);
        }
    }

    function getIsTestnet(Config storage config) internal view returns (bool) {
        return config.json.readBool(IS_TESTNET);
    }

    function getRpcAlias(Config storage config) internal view returns (string memory) {
        return config.json.readString(RPC_ALIAS);
    }

    function getVaultAddress(Config storage config) internal view returns (address) {
        return getAddress(config, VAUL_ADDRESS);
    }

    function getUsdcAddress(Config storage config) internal view returns (address) {
        return getAddress(config, USDC_ADDRESS);
    }

    function getMetaAddress(Config storage config) internal view returns (address) {
        return getAddress(config, META_ADDRESS);
    }

    function getFeeProtocolAddress(Config storage config) internal view returns (address) {
        return getAddress(config, FEE_PROTOCOL_ADDRESS);
    }
}

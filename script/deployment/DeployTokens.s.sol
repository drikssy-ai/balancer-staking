// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseScript } from "script/Base.s.sol";
import { console } from "@forge-std/console.sol";
import { TestToken } from "src/init/TestToken.sol";

contract DeployTokens is BaseScript {
    function run() public virtual broadcast {
        (address usdc, address meta) = _deployTokens();
        console.log("usdc deployed at address:", usdc);
        console.log("meta deployed at address:", meta);
    }

    function _deployTokens() internal returns (address usdc, address meta) {
        TestToken USDC = new TestToken("USDC TEST", "USDC TEST", 6);
        TestToken META = new TestToken("META TEST", "META TEST", 18);
        USDC.mint(broadcaster, 10 ether);
        META.mint(broadcaster, 10 ether);

        usdc = address(USDC);
        meta = address(META);
    }
}

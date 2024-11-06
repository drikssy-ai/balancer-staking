// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "@forge-std/Script.sol";
import { console } from "@forge-std/console.sol";
import { IWeightedPoolFactory } from "src/init/balancer/IWeightedPoolFactory.sol";
import { IERC20 } from "src/interfaces/IERC20.sol";
import { IRateProvider } from "src/init/balancer/IRateProvider.sol";

contract DeployWeightPool is Script {
    address broadcaster;

    modifier broadcast() {
        uint256 deployerKey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(deployerKey);
        broadcaster = vm.addr(deployerKey);
        _;
        vm.stopBroadcast();
    }

    function run() public virtual broadcast {
        address pool = _deployVault();
        console.log("pool deployed at address:", pool);
    }

    function _deployVault() internal returns (address poolCreated) {
        IERC20 META = IERC20(0x98a4F6E377460F1B109c20CFE3f3f7265C11F94d);
        IERC20 USDC = IERC20(0xf8a9E63FaB95041C7Eae633073Fdbd82D41Ec764);
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = META;
        tokens[1] = USDC;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 0.8 ether;
        weights[1] = 0.2 ether;

        IRateProvider[] memory rateProviders = new IRateProvider[](2);
        rateProviders[0] = IRateProvider(0x0000000000000000000000000000000000000000);
        rateProviders[1] = IRateProvider(0x0000000000000000000000000000000000000000);

        uint256 swapFeePercentage = 0.1 ether;
        address owner = address(0xBA1BA1ba1BA1bA1bA1Ba1BA1ba1BA1bA1ba1ba1B);

        IWeightedPoolFactory factory = IWeightedPoolFactory(address(0x7920BFa1b2041911b354747CA7A6cDD2dfC50Cfd));
        poolCreated = factory.create(
            "META_80/USDC_20", "META_80/USDC_20", tokens, weights, rateProviders, swapFeePercentage, owner, bytes32(0)
        );
    }
}

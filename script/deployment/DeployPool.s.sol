// // SPDX-License-Identifier: MIT
// pragma solidity ^0.7.0;
// pragma experimental ABIEncoderV2;

// import { Script } from "@forge-std/Script.sol";
// import { BasicWeightedPool } from "@balancer/contracts/weighted-pool/BasicWeightedPool.sol";
// import { IERC20 } from "@balancer/contracts/interfaces/solidity-utils/openzeppelin/IERC20.sol";
// import { IRateProvider } from "@balancer/contracts/interfaces/pool-utils/IRateProvider.sol";
// import { IVault } from "@balancer/contracts/interfaces/vault/IVault.sol";
// import { IProtocolFeePercentagesProvider } from
//     "@balancer/contracts/interfaces/standalone-utils/IProtocolFeePercentagesProvider.sol";

// import { console } from "@forge-std/console.sol";

// contract DeployPool is Script {
//     address broadcaster;
//     address usdcAddress = vm.addr(1);
//     address metaAddress = vm.addr(2);
//     address vaultAddress = vm.addr(3);
//     address feeProtocolAddress = vm.addr(4);

//     modifier broadcast() {
//         uint256 deployerKey = vm.envUint("DEPLOYER_KEY");
//         vm.startBroadcast(deployerKey);
//         broadcaster = vm.addr(deployerKey);
//         _;
//         vm.stopBroadcast();
//     }

//     function run() public virtual broadcast {
//         address pool = _deployPool();
//         console.log("pool deployed at address:", pool);
//     }

//     function _deployPool() internal returns (address) {
//         IERC20[] memory tokens = new IERC20[](2);
//         uint256[] memory weights = new uint256[](2);
//         tokens[0] = IERC20(usdcAddress);
//         tokens[1] = IERC20(metaAddress);
//         weights[0] = 0.8 ether;
//         weights[1] = 0.2 ether;

//         BasicWeightedPool.NewPoolParams memory params = BasicWeightedPool.NewPoolParams({
//             name: "META_80/USDC_20",
//             symbol: "META_80/USDC_20",
//             tokens: tokens,
//             normalizedWeights: weights,
//             rateProviders: new IRateProvider[](2),
//             assetManagers: new address[](2),
//             swapFeePercentage: 0.1 ether
//         });

//         BasicWeightedPool pool = new BasicWeightedPool(
//             params,
//             IVault(vaultAddress),
//             IProtocolFeePercentagesProvider(feeProtocolAddress),
//             90 days,
//             30 days,
//             broadcaster
//         );

//         return address(pool);
//     }
// }

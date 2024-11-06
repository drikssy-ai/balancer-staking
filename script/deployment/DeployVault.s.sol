// // SPDX-License-Identifier: MIT
// pragma solidity ^0.7.0;

// import { Script } from "@forge-std/Script.sol";
// import { MockAuthorizerAdaptorEntrypoint } from "@balancer/v2-vault/contracts/test/MockAuthorizerAdaptorEntrypoint.sol";
// import { TimelockAuthorizer } from "@balancer/vault/contracts/authorizer/TimelockAuthorizer.sol";
// import { Vault } from "@balancer/vault/contracts/Vault.sol";
// import { IWETH } from "@balancer/interfaces/contracts/solidity-utils/misc/IWETH.sol";
// import { IAuthorizerAdaptorEntrypoint } from
//     "@balancer/interfaces/contracts/liquidity-mining/IAuthorizerAdaptorEntrypoint.sol";
// import { ProtocolFeePercentagesProvider } from "@balancer/standalone-utils/contracts/ProtocolFeePercentagesProvider.sol";

// import { console } from "@forge-std/console.sol";

// contract DeployVault is Script {
//     address broadcaster;

//     modifier broadcast() {
//         uint256 deployerKey = vm.envUint("DEPLOYER_KEY");
//         vm.startBroadcast(deployerKey);
//         broadcaster = vm.addr(deployerKey);
//         _;
//         vm.stopBroadcast();
//     }

//     function run() public virtual broadcast {
//         (address vAddrr, address feeProt) = _deployVault();
//         console.log("vault deployed at address:", vAddrr);
//         console.log("fee provider deployed at address:", feeProt);
//     }

//     function _deployVault() internal returns (address vault, address feeProviderAddress) {
//         MockAuthorizerAdaptorEntrypoint entrypoint = new MockAuthorizerAdaptorEntrypoint();
//         TimelockAuthorizer authorizer =
//             new TimelockAuthorizer(broadcaster, address(0), IAuthorizerAdaptorEntrypoint(address(entrypoint)), 30 days);
//         Vault v = new Vault(authorizer, IWETH(payable(address(0x4200000000000000000000000000000000000006))), 0,0);
//         // ProtocolFeePercentagesProvider f = new ProtocolFeePercentagesProvider(v, 0.8 ether, 0.2 ether);

//         vault = address(v);
//         feeProviderAddress = address(0);
//     }
// }

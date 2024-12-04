// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { Test } from "@forge-std/Test.sol";

/// @notice Common logic needed by all fork tests.
abstract contract Fork_Test is Test {
    function setUp() public virtual {
        // Fork Polygon Mainnet at a specific block number.
        vm.createSelectFork({ blockNumber: 7_202_999, urlOrAlias: "sepolia" });
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { EpochStaking } from "src/EpochStaking.sol";
import { RewardToken } from "src/RewardToken.sol";
import { Deploys } from "test/staking/Deploys.t.sol";

contract EpochStakingTest is Deploys {
    uint256 internal constant BLOCK_TIME = 12;
    address staker = makeAddr("staker");
    address randomCaller = makeAddr("randomCaller");

    function setUp() public virtual override {
        super.setUp();
    }

    function _forwardByTimestamp(uint256 timestamp) internal {
        vm.warp(uint64(block.timestamp) + timestamp);
        vm.roll(block.number + timestamp / BLOCK_TIME);
    }
}

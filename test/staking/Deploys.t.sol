// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "@forge-std/Test.sol";
import { MockStakingTest } from "test/MockStaking.t.sol";
import { RewardToken } from "src/RewardToken.sol";

contract Deploys is Test {
    MockStakingTest epochStaking;
    address CS;
    RewardToken rewardToken;
    address orchestrator = makeAddr("orchestrator");

    function setUp() public virtual {
        CS = makeAddr("CS");
        vm.prank(CS);
        rewardToken = new RewardToken();
        epochStaking = new MockStakingTest(address(rewardToken), CS);

        vm.prank(CS);
        rewardToken.approve(address(epochStaking), type(uint256).max);
    }
}

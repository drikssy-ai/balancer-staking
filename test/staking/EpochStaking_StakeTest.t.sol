// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { EpochStakingTest } from "test/staking/EpochStakingTest.t.sol";
import { EpochStaking } from "src/EpochStaking.sol";
import { console } from "@forge-std/console.sol";

uint256 constant STAKING_AMOUNT = 100;

contract EpochStaking_StakeTest is EpochStakingTest {
    // function testRevert_epochStaking_stake_whenCallerNotAuthorized() public {
    //     vm.expectRevert(abi.encodeWithSelector(EpochStaking.NotAuthorized.selector, randomCaller));
    //     vm.prank(randomCaller);
    //     epochStaking.stake(staker, STAKING_AMOUNT);
    // }

    function testRevert_epochStaking_stake_whenAmountIsZero() public {
        vm.expectRevert(EpochStaking.StakingAmountIsZero.selector);
        vm.prank(orchestrator);
        epochStaking.stake(staker, 0);
    }

    function test_epochStaking_stake() public {
        EpochStaking.Stake memory userStakeBefore = epochStaking.getUserStake(staker);
        EpochStaking.EpochInfo memory epochInfoBefore = epochStaking.getEpochInfo(epochStaking.currentEpoch());

        vm.prank(orchestrator);
        epochStaking.stake(staker, STAKING_AMOUNT);

        EpochStaking.Stake memory userStakeAfter = epochStaking.getUserStake(staker);
        EpochStaking.EpochInfo memory epochInfoAfter = epochStaking.getEpochInfo(epochStaking.currentEpoch());

        assertEq(userStakeBefore.amount + STAKING_AMOUNT, userStakeAfter.amount);
        assertEq(epochInfoBefore.totalStaked + STAKING_AMOUNT, epochInfoAfter.totalStaked);
    }

    function test_epochStaking_restakeSameEpoch() public {
        vm.prank(orchestrator);
        epochStaking.stake(staker, STAKING_AMOUNT);

        EpochStaking.Stake memory userStakeBefore = epochStaking.getUserStake(staker);
        EpochStaking.EpochInfo memory epochInfoBefore = epochStaking.getEpochInfo(epochStaking.currentEpoch());

        vm.prank(orchestrator);
        epochStaking.stake(staker, STAKING_AMOUNT);

        EpochStaking.Stake memory userStakeAfter = epochStaking.getUserStake(staker);
        EpochStaking.EpochInfo memory epochInfoAfter = epochStaking.getEpochInfo(epochStaking.currentEpoch());

        assertEq(userStakeBefore.amount + STAKING_AMOUNT, userStakeAfter.amount);
        assertEq(STAKING_AMOUNT * 2, userStakeAfter.amount);
        assertEq(epochInfoBefore.totalStaked + STAKING_AMOUNT, epochInfoAfter.totalStaked);
        assertEq(STAKING_AMOUNT * 2, epochInfoAfter.totalStaked);
    }

    function test_epochStaking_restakeDifferentEpoch() public {
        vm.prank(orchestrator);
        epochStaking.stake(staker, STAKING_AMOUNT);

        uint8 decimals = rewardToken.decimals();
        vm.prank(CS);
        epochStaking.setRewards(1000 * 10 ** decimals);

        vm.prank(CS);
        epochStaking.setRewards(1000 * 10 ** decimals);

        vm.prank(orchestrator);
        epochStaking.stake(staker, STAKING_AMOUNT);

        EpochStaking.Stake memory userStakeAfter = epochStaking.getUserStake(staker);
        EpochStaking.EpochInfo memory epochInfoAfter = epochStaking.getEpochInfo(epochStaking.currentEpoch());
        uint256 pendingRewards = epochStaking.pendingRewards(staker);

        assertEq(userStakeAfter.amount, STAKING_AMOUNT * 2);
        assertEq(epochInfoAfter.totalStaked, STAKING_AMOUNT * 2);
        assertEq(pendingRewards, (1000 * 10 ** decimals));
    }
}

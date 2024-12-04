// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { EpochStaking } from "src/EpochStaking.sol";

contract MockStakingTest is EpochStaking {
    constructor(address _rewardToken, address _cs) EpochStaking(_rewardToken, _cs) { }

    function stake(address _staker, uint256 _amount) public {
        _stake(_staker, _amount);
    }

    function unstake(address _staker) public {
        _unstake(_staker);
    }
}

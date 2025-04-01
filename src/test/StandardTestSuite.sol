// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {Staker} from "../Staker.sol";
import {StakerTestBase} from "./StakerTestBase.sol";

abstract contract Constructor is StakerTestBase {}

// After deployment test that a stake event can occurj
abstract contract Stake is StakerTestBase {
  function testForkFuzz_CorrectlyStakeAndEarnRewardsAfterDuration(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _percentDuration
  ) public virtual {
    vm.assume(_depositor != address(0) && _delegatee != address(0) && _amount != 0);
    vm.assume(_depositor != address(staker));
    _mintGovToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 1, 100);
    // _delegatee = _validateDelegatee(_delegatee);

     Staker.DepositIdentifier _depositId = _stake(_depositor, _amount, _delegatee);
    _mintTransferAndNotifyReward(_rewardAmount);
	_jumpAheadByPercentOfRewardDuration(bound(_percentDuration, 0, 100));

    uint256 unclaimedRewards = staker.unclaimedReward(_depositId);

	// TODO: Calculate rewards based on earning power compared to total earning power and duration.

    assertEq(unclaimedRewards, 0, "Should earn some rewards");
  }
}
// Repeat Stake for stakeMore?
// Bump earning power for other earning power calculator

// abstract contract ClaimReward is StakerTestBase {}
//
// abstract contract Unstake is StakerTestBase {}
//
// abstract contract Withdraw is StakerTestBase {}
//
// // Delegatee

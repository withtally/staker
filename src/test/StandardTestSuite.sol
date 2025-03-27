// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {Staker} from "../Staker.sol";
import {StakerTestBase} from "./StakerTestBase.sol";

abstract contract Constructor is StakerTestBase {}

// abstract contract Stake is StakerTestBase {
//   function testForkFuzz_CorrectlyStakeAndEarnRewardsAfterDuration(
//     address _depositor,
//     uint96 _amount,
//     address _delegatee,
//     uint256 _rewardAmount,
//     uint256 _percentDuration
//   ) public {
//     vm.assume(_depositor != address(0) && _delegatee != address(0) && _amount != 0);
//     vm.assume(_depositor != address(staker));
//     (_amount,) = _mintGovToken(_depositor, _amount);
//     _rewardAmount = _boundToRealisticReward(_rewardAmount);
//     _percentDuration = bound(_percentDuration, 1, 100);
//     // _delegatee = _validateDelegatee(_delegatee);
//
//     // Staker.DepositIdentifier _depositId = _approveAndStake(_depositor, _amount, _delegatee);
//     // _addRewardsAndAdvanceTime(_rewardAmount, _percentDuration);
//
//     // uint256 unclaimedRewards = testStaker.unclaimedReward(_depositId);
//
//     // assertGt(unclaimedRewards, 0, "Should earn some rewards");
//   }
// }
//
// abstract contract Unstake is StakerTestBase {}
//
// abstract contract Withdraw is StakerTestBase {}
//
// // Delegatee

// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, stdError} from "forge-std/Test.sol";
import {Staker} from "../Staker.sol";
import {StakerTestBase} from "./StakerTestBase.sol";

abstract contract Constructor is StakerTestBase {}

// After deployment test that a stake event can occurj
abstract contract StakeBase is StakerTestBase {
  // TODO: Maybe verify balances
  function testForkFuzz_CorrectlyStakeAndEarnRewardsAfterDuration(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _percentDuration
  ) public virtual {
    vm.assume(_depositor != address(0) && _delegatee != address(0) && _amount != 0);
    vm.assume(_depositor != address(staker));
    _mintStakeToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 1, 100);

    Staker.DepositIdentifier _depositId = _stake(_depositor, _amount, _delegatee);
    _notifyRewardAmount(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(bound(_percentDuration, 0, 100));

    uint256 unclaimedRewards = staker.unclaimedReward(_depositId);
    Staker.Deposit memory _deposit = _fetchDeposit(_depositId);

    uint256 _earnedRewards =
      _calculateEarnedRewards(_deposit.earningPower, _rewardAmount, _percentDuration);

    assertLteWithinOneUnit(unclaimedRewards, _earnedRewards);
  }
}

abstract contract WithdrawBase is StakerTestBase {
  function testForkFuzz_CorrectlyUnstakeAfterDuration(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _withdrawAmount,
    uint256 _percentDuration
  ) public {
    vm.assume(_depositor != address(0) && _delegatee != address(0) && _amount != 0);
    vm.assume(_depositor != address(staker));

    _amount = uint96(_boundMintAmount(_amount));
    _mintStakeToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 1, 100);

    Staker.DepositIdentifier _depositId = _stake(_depositor, _amount, _delegatee);
    _notifyRewardAmount(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 initialRewards = staker.unclaimedReward(_depositId);

    _withdrawAmount = bound(_withdrawAmount, 0, _amount);
    _withdraw(_depositor, _depositId, _withdrawAmount);

    uint256 _balance = STAKE_TOKEN.balanceOf(_depositor);

    // If we have rewards accrued, check that they're consistent after withdrawal
    uint256 currentRewards = staker.unclaimedReward(_depositId);
    assertLteWithinOneUnit(currentRewards, initialRewards);
    assertEq(_balance, _withdrawAmount);
  }
}

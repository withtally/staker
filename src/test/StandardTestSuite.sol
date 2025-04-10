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

  function testFuzz_WithdrawTwoUsersAfterDuration(
    address _depositor1,
    address _depositor2,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _withdrawAmount1,
    uint256 _withdrawAmount2,
    uint256 _percentDuration1,
    uint256 _percentDuration2
  ) public {
    vm.assume(_depositor1 != address(0) && _depositor2 != address(0) && _depositor1 != _depositor2);
    vm.assume(_depositor1 != address(staker) && _depositor2 != address(staker));
    vm.assume(_delegatee != address(0));
    vm.assume(_percentDuration1 != _percentDuration2);

    _amount = uint96(_boundMintAmount(_amount));
    vm.assume(_amount != 0);

    _mintStakeToken(_depositor1, _amount);
    _mintStakeToken(_depositor2, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration1 = bound(_percentDuration1, 1, 100);
    _percentDuration2 = bound(_percentDuration2, 0, 100 - _percentDuration1);

    Staker.DepositIdentifier _depositId1 = _stake(_depositor1, _amount, _delegatee);
    Staker.DepositIdentifier _depositId2 = _stake(_depositor2, _amount, _delegatee);

    _notifyRewardAmount(_rewardAmount);

    _jumpAheadByPercentOfRewardDuration(_percentDuration1);
    uint256 initialRewards1 = staker.unclaimedReward(_depositId1);
    _withdrawAmount1 = bound(_withdrawAmount1, 0, _amount);
    _withdraw(_depositor1, _depositId1, _withdrawAmount1);
    assertLteWithinOneUnit(staker.unclaimedReward(_depositId1), initialRewards1);

    _jumpAheadByPercentOfRewardDuration(_percentDuration2);
    uint256 initialRewards2 = staker.unclaimedReward(_depositId2);
    _withdrawAmount2 = bound(_withdrawAmount2, 0, _amount);
    _withdraw(_depositor2, _depositId2, _withdrawAmount2);
    assertLteWithinOneUnit(staker.unclaimedReward(_depositId2), initialRewards2);

    assertEq(STAKE_TOKEN.balanceOf(_depositor1), _withdrawAmount1);
    assertEq(STAKE_TOKEN.balanceOf(_depositor2), _withdrawAmount2);
  }

  function testForkFuzz_ClaimRewardAndWithdrawAfterDuration(
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
    uint256 initialRewardBalance = REWARD_TOKEN.balanceOf(_depositor);

    vm.prank(_depositor);
    staker.claimReward(_depositId);

    uint256 rewardsReceived = REWARD_TOKEN.balanceOf(_depositor) - initialRewardBalance;
    assertEq(staker.unclaimedReward(_depositId), 0);
    assertEq(rewardsReceived, initialRewards);

    _withdrawAmount = bound(_withdrawAmount, 0, _amount);
    _withdraw(_depositor, _depositId, _withdrawAmount);

    uint256 _balance = STAKE_TOKEN.balanceOf(_depositor);
    assertEq(_balance, _withdrawAmount);
  }
}

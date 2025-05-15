// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {BinaryEligibilityOracleEarningPowerCalculator} from
  "../calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";
import {MintRewardNotifier} from "../notifiers/MintRewardNotifier.sol";
import {StakerTestBase} from "./StakerTestBase.sol";
import {Staker} from "../Staker.sol";

abstract contract StakedBinaryEligibilityOracleEarningPowerCalculatorTestBase is StakerTestBase {
  BinaryEligibilityOracleEarningPowerCalculator calculator;
  MintRewardNotifier mintRewardNotifier;

  function _notifyRewardAmount(uint256 _amount) public override {
    address _owner = mintRewardNotifier.owner();

    vm.prank(_owner);
    mintRewardNotifier.setRewardAmount(_amount);

    mintRewardNotifier.notify();
  }

  /// !Fix Natspec
  /// @notice Helper to set a delegatee's score above threshold
  /// @dev This should be called after a delegatee is known but before checking their earning power
  function _setDelegateeScoreAboveThreshold(address delegatee) internal {
    vm.startPrank(calculator.scoreOracle());
    calculator.updateDelegateeScore(delegatee, calculator.delegateeEligibilityThresholdScore() + 1);
    vm.stopPrank();
  }

  /// @notice Helper to set a delegatee's score below threshold
  function _setDelegateeScoreBelowThreshold(address delegatee) internal {
    vm.startPrank(calculator.scoreOracle());
    calculator.updateDelegateeScore(delegatee, calculator.delegateeEligibilityThresholdScore() - 1);
    vm.stopPrank();
  }

  /// @notice Bound the mint amount to a realistic value.
  /// @param _amount The unbounded mint amount.
  /// @return The bounded mint amount.
  function _boundMintAmount(uint256 _amount) internal pure virtual override returns (uint256) {
    return bound(_amount, 1, 100_000_000e18);
  }

  function _stake(address _depositor, uint256 _amount, address _delegatee)
    internal
    virtual
    override
    returns (Staker.DepositIdentifier _depositId)
  {
    vm.assume(_delegatee != address(0));

    vm.startPrank(_depositor);
    STAKE_TOKEN.approve(address(staker), _amount);
    _depositId = staker.stake(_amount, _delegatee);
    vm.stopPrank();

    // Called after the stake so the surrogate will exist
    _assumeSafeDepositorAndSurrogate(_depositor, _delegatee);

    if (calculator.delegateeScores(_delegatee) < calculator.delegateeEligibilityThresholdScore()) {
      _setDelegateeScoreAboveThreshold(_delegatee);
      vm.startPrank(_depositor);
      staker.bumpEarningPower(_depositId, _depositor, 0);
      vm.stopPrank();
    }
  }
}

abstract contract StakeBase is StakerTestBase {
  function testFuzz_StakerEarnsZeroRewardsWhenDelegateeScoreIsBelowThreshold(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _percentDuration
  ) public {
    _assumeNotZeroAddressOrStaker(_depositor);
    vm.assume(_delegatee != address(0) && _amount != 0);

    _mintStakeToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 1, 100);

    Staker.DepositIdentifier _depositId = _stakeZeroEarningPower(_depositor, _amount, _delegatee);

    _notifyRewardAmount(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 unclaimedRewards = staker.unclaimedReward(_depositId);

    assertEq(unclaimedRewards, 0);
  }
}

abstract contract WithdrawBase is StakerTestBase {
  function testFuzz_OnlyStakeWithEligibleEarningPowerClaimsRewardAfterDuration(
    address _depositor1,
    address _depositor2,
    uint96 _amount1,
    uint96 _amount2,
    address _delegatee1,
    address _delegatee2,
    uint256 _rewardAmount,
    uint256 _percentDuration
  ) public {
    _assumeNotZeroAddressOrStaker(_depositor1);
    _assumeNotZeroAddressOrStaker(_depositor2);
    vm.assume(_depositor1 != _depositor2);
    vm.assume(_delegatee1 != address(0) && _delegatee2 != address(0) && _delegatee1 != _delegatee2);

    _amount1 = uint96(_boundMintAmount(_amount1));
    _amount2 = uint96(_boundMintAmount(_amount2));
    vm.assume(_amount1 != 0 && _amount2 != 0);

    _mintStakeToken(_depositor1, _amount1);
    _mintStakeToken(_depositor2, _amount2);

    Staker.DepositIdentifier _depositId1 =
    _stakeZeroEarningPower(_depositor1, _amount1, _delegatee1);
    Staker.DepositIdentifier _depositId2 = _stake(_depositor2, _amount2, _delegatee2);

    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _notifyRewardAmount(_rewardAmount);
    _percentDuration = bound(_percentDuration, 1, 100);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    Staker.Deposit memory _deposit2 = _fetchDeposit(_depositId2);
    uint256 _calculatedRewards2 =
      _calculateEarnedRewards(_deposit2.earningPower, _rewardAmount, _percentDuration);

    _withdraw(_depositor1, _depositId1, _amount1);
    _withdraw(_depositor2, _depositId2, _amount2);

    vm.prank(_depositor1);
    uint256 _actualReward1 = staker.claimReward(_depositId1);

    vm.prank(_depositor2);
    uint256 _actualReward2 = staker.claimReward(_depositId2);

    assertEq(0, _actualReward1);
    assertApproxEqAbs(_calculatedRewards2, _actualReward2, 1);
  }
}

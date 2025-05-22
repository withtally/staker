// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {BinaryEligibilityOracleEarningPowerCalculator} from
  "../calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";
import {StakerTestBase} from "./StakerTestBase.sol";
import {Staker} from "../Staker.sol";
import {BinaryEligibilityOracleEarningPowerCalculatorTestBase} from
  "./BinaryEligibilityOracleEarningPowerCalculatorTestBase.sol";

/// @title StakedBinaryEligibilityOracleEarningPowerCalculatorTestSuite
/// @author [ScopeLift](https://scopelift.co)
/// @notice The base contract for testing BinaryEligibilityOracleEarningPowerCalculator. Contains
/// test setup and helper functions for testing the calculator's behavior when delegatees are below
/// the eligibility threshold. This contract is designed to be used in conjunction with the
/// deployment scripts in
/// `src/script/calculators/DeployBinaryEligibilityOracleEarningPowerCalculator.sol`.
abstract contract StakedBinaryEligibilityOracleEarningPowerCalculatorTestBase is
  BinaryEligibilityOracleEarningPowerCalculatorTestBase
{
  /// @notice Helper to set a delegatee's score below threshold.
  /// @param delegatee The address of the delegatee whose score will be set below threshold.
  function _setDelegateeScoreBelowThreshold(address delegatee) internal {
    vm.startPrank(calculator.scoreOracle());
    calculator.updateDelegateeScore(delegatee, calculator.delegateeEligibilityThresholdScore() - 1);
    vm.stopPrank();
  }

  /// @notice A test helper that wraps calling the `stake` function and ensures proper earning power
  /// adjustment when delegatee scores are below threshold.
  /// @param _depositor The address of the depositor.
  /// @param _amount The amount to stake.
  /// @param _delegatee The address to which the delegation surrogate is delegating voting power.
  /// @return _depositId The id of the created deposit.
  function _stakeBelowThreshold(address _depositor, uint256 _amount, address _delegatee)
    internal
    virtual
    returns (Staker.DepositIdentifier _depositId)
  {
    _depositId = StakerTestBase._stake(_depositor, _amount, _delegatee);
    _setDelegateeScoreBelowThreshold(_delegatee);
  }

  /// @notice A test helper that wraps calling the `stake` function and ensures proper earning power
  /// adjustment when delegatee scores are above threshold.
  /// @param _depositor The address of the depositor.
  /// @param _amount The amount to stake.
  /// @param _delegatee The address to which the delegation surrogate is delegating voting power.
  /// @return _depositId The id of the created deposit.
  function _stakeAboveThreshold(address _depositor, uint256 _amount, address _delegatee)
    internal
    virtual
    returns (Staker.DepositIdentifier _depositId)
  {
    _depositId = StakerTestBase._stake(_depositor, _amount, _delegatee);

    _setDelegateeScoreAboveThreshold(_delegatee);
    vm.startPrank(_depositor);
    staker.bumpEarningPower(_depositId, _depositor, 0);
    vm.stopPrank();
  }
}

abstract contract StakeBase is StakedBinaryEligibilityOracleEarningPowerCalculatorTestBase {
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

    Staker.DepositIdentifier _depositId = _stakeBelowThreshold(_depositor, _amount, _delegatee);

    _notifyRewardAmount(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 unclaimedRewards = staker.unclaimedReward(_depositId);

    assertEq(unclaimedRewards, 0);
  }
}

abstract contract WithdrawBase is StakedBinaryEligibilityOracleEarningPowerCalculatorTestBase {
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

    Staker.DepositIdentifier _depositId1 = _stakeBelowThreshold(_depositor1, _amount1, _delegatee1);
    Staker.DepositIdentifier _depositId2 = _stakeAboveThreshold(_depositor2, _amount2, _delegatee2);

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

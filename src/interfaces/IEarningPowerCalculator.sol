// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

/// @title IEarningPowerCalculator
/// @author [ScopeLift](https://scopelift.co)
/// @notice Interface to which Earning Power Calculators must conform in order to provide earning
/// power updates to an instance of Staker. Well behaving earning power calculators should:
///
/// 1. Be deterministic, i.e. produce the same output for the same input at a given time.
/// 2. Return values that are in the same order of magnitude as reasonable stake token amounts.
///    Avoid returning values that are dramatically detached from the staked amount.
/// 3. Avoid too much "churn" on earning power values, in particular, avoid returning "true" for
///    the `getNewEarningPower` method's `_isQualifiedForBump` too frequently, as such an earning
///    calculator would result in repeated bumps on a user's deposit, requiring excessive
///    monitoring on their behalf to avoid eating into their rewards.
interface IEarningPowerCalculator {
  /// @notice Returns the current earning power for a given staker, delegatee and staking amount.
  /// @param _amountStaked The amount of tokens staked.
  /// @param _staker The address of the staker.
  /// @param _delegatee The address of their chosen delegatee.
  /// @return _earningPower The calculated earning power.
  function getEarningPower(uint256 _amountStaked, address _staker, address _delegatee)
    external
    view
    returns (uint256 _earningPower);

  /// @notice Returns the current earning power for a given staker, delegatee, staking amount, and
  /// old earning power, along with a flag denoting whether the change in earning power warrants
  /// "bumping." Bumping means paying a third party a bit of the rewards to update the deposit's
  /// earning power on the depositor's behalf.
  /// @param _amountStaked The amount of tokens staked.
  /// @param _staker The address of the staker.
  /// @param _delegatee The address of their chosen delegatee.
  /// @param _oldEarningPower The earning power currently assigned to the deposit for which new
  /// earning power is being calculated.
  /// @return _newEarningPower The calculated earning power.
  /// @return _isQualifiedForBump A flag indicating whether or not this new earning power qualifies
  /// the deposit for having its earning power bumped.
  /// @dev Earning Power calculators should only "qualify" a bump when the difference warrants a
  /// forced update by a third party. This could be, for example, to reduce a deposit's earning
  /// power because their delegatee has become inactive. Even in these cases, a calculator should
  /// avoid qualifying for a bump too frequently. A calculator implementer may, for example, want
  /// to implement a grace period or a threshold difference before qualifying a deposit for a bump.
  function getNewEarningPower(
    uint256 _amountStaked,
    address _staker,
    address _delegatee,
    uint256 _oldEarningPower
  ) external view returns (uint256 _newEarningPower, bool _isQualifiedForBump);
}

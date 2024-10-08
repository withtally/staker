// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

interface IEarningPowerCalculator {
  /// @notice Calculates the earning power for a given delegate and staking amount.
  /// @param _amountStaked The amount of tokens staked.
  /// @param _staker The address of the staker.
  /// @param _delegatee The address of the delegatee.
  /// @return _earningPower The calculated earning power.
  function getEarningPower(uint256 _amountStaked, address _staker, address _delegatee)
    external
    view
    returns (uint256 _earningPower);

  /// @notice Calculates the new earning power and determines if it qualifies for an update.
  /// @param _amountStaked The amount of tokens staked.
  /// @param _staker The address of the staker.
  /// @param _delegatee The address of the delegatee.
  /// @param _oldEarningPower The previous earning power value.
  /// @return _newEarningPower The newly calculated earning power.
  /// @return _isQualifiedForUpdate Indicating if the new earning power qualifies for an
  /// update.
  function getNewEarningPower(
    uint256 _amountStaked,
    address _staker,
    address _delegatee,
    uint256 _oldEarningPower
  ) external view returns (uint256 _newEarningPower, bool _isQualifiedForUpdate);
}

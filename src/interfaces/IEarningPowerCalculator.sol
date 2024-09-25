// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

interface IEarningPowerCalculator {
  function getEarningPower(uint256 _amountStaked, address _staker, address _delegatee)
    external
    view
    returns (uint256 _earningPower);

  function getNewEarningPower(
    uint256 _amountStaked,
    address _staker,
    address _delegatee,
    uint256 _oldEarningPower
  ) external view returns (uint256 _newEarningPower, bool _isQualifiedForUpdate);
}

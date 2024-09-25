// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IEarningPowerCalculator} from "src/interfaces/IEarningPowerCalculator.sol";

contract MockFullEarningPowerCalculator is IEarningPowerCalculator {
  function getEarningPower(
    uint256 _amountStaked,
    address, // _staker
    address // _delegatee
  ) external pure returns (uint256 _earningPower) {
    return _amountStaked;
  }

  function getNewEarningPower(
    uint256 _amountStaked,
    address, // _staker
    address, // _delegatee
    uint256 // _oldEarningPower
  ) external pure returns (uint256 _newEarningPower, bool _isQualifiedForUpdate) {
    return (_amountStaked, true);
  }
}

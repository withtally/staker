// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IEarningPowerCalculator} from "src/interfaces/IEarningPowerCalculator.sol";

contract MockFullEarningPowerCalculator is IEarningPowerCalculator {
  struct StoredEarningPower {
    uint256 earningPower;
    bool isOverride;
  }

  mapping(address delegatee => StoredEarningPower earningPower) public earningPowerOverrides;

  // Methods implementing the IEarningPowerCalculator interface.

  function getEarningPower(
    uint256 _amountStaked,
    address, // _staker
    address _delegatee
  ) external view returns (uint256 _earningPower) {
    return __getEarningPower(_amountStaked, _delegatee);
  }

  function getNewEarningPower(
    uint256 _amountStaked,
    address, // _staker
    address _delegatee,
    uint256 // _oldEarningPower
  ) external view returns (uint256 _newEarningPower, bool _isQualifiedForUpdate) {
    return (__getEarningPower(_amountStaked, _delegatee), true);
  }

  // Methods used for configuring the mock during testing.

  function __setEarningPowerForDelegatee(address _delegatee, uint256 _earningPower) external {
    earningPowerOverrides[_delegatee] =
      StoredEarningPower({earningPower: _earningPower, isOverride: true});
  }

  function __getEarningPower(uint256 _amountStaked, address _delegatee)
    internal
    view
    returns (uint256 _earningPower)
  {
    StoredEarningPower memory _storedEarningPower = earningPowerOverrides[_delegatee];

    if (_storedEarningPower.isOverride) return _storedEarningPower.earningPower;
    else return _amountStaked;
  }
}

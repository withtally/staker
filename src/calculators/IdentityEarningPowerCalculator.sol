// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IEarningPowerCalculator} from "src/interfaces/IEarningPowerCalculator.sol";

/// @title IdentityEarningPowerCalculator
/// @author [ScopeLift](https://scopelift.co)
/// @notice A simple earning power calculator that maps earning power directly to staked amount in
/// a 1:1 ratio. This implementation is suitable when all stakers should earn rewards proportional
/// to their stake without any adjustments or weights.
///
/// The calculator does not modify earning power based on the staker or delegatee, and is never
/// qualified for bumping since the earning power calculation is a pure identity function of the
/// staked amount.
contract IdentityEarningPowerCalculator is IEarningPowerCalculator {
  /// @notice Returns earning power equal to the staked amount.
  /// @param _amountStaked The amount of tokens staked.
  /// @return The earning power, equal to _amountStaked.
  function getEarningPower(uint256 _amountStaked, address, /* _staker */ address /* _delegatee */ )
    external
    pure
    returns (uint256)
  {
    return _amountStaked;
  }

  /// @notice Returns earning power equal to the staked amount and always indicates no
  /// qualification for bumping.
  /// @param _amountStaked The amount of tokens staked.
  /// @return The earning power value, equal to _amountStaked.
  /// @return Always false since this implementation never qualifies for bumping.
  function getNewEarningPower(
    uint256 _amountStaked,
    address, /* _staker */
    address, /* _delegatee */
    uint256 /* _oldEarningPower */
  ) external pure returns (uint256, bool) {
    return (_amountStaked, false);
  }
}

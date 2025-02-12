// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

/// @notice An interface that contains the necessary `IVotes` functions for the governance staking
/// system.
interface IDelegates {
  /// @notice Method which assigns voting weight from the sender to delegatee.
  function delegate(address _delegatee) external;

  /// @notice Method which returns the delegatee to which the account's voting weight is currently
  /// delegated.
  function delegates(address _account) external view returns (address);
}

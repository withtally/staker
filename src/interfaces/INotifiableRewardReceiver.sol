// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

/// @title INotifiableRewardReceiver
/// @author [ScopeLift](https://scopelift.co)
/// @notice The communication interface between contracts that distribute rewards and the
/// Staker contract. In particular, said contracts only need to know the staker
/// implements the specified method in order to forward payouts to the staker contract. The
/// Staker contract receives the rewards and abstracts the distribution mechanics.
interface INotifiableRewardReceiver {
  /// @notice Method called to notify a reward receiver it has received a reward.
  /// @param _amount The amount of reward.
  function notifyRewardAmount(uint256 _amount) external;
}

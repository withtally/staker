// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title INotifiableRewardReceiver
/// @author [ScopeLift](https://scopelift.co)
/// @notice The communication interface between contracts that distribute rewards and the
/// Staker contract. In particular, said contracts only need to know the staker
/// implements the specified methods in order to forward payouts to the staker contract. The
/// Staker contract receives the rewards and abstracts the distribution mechanics.
interface INotifiableRewardReceiver {
  /// @notice ERC20 token in which rewards are denominated and distributed.
  function REWARD_TOKEN() external view returns (IERC20);

  /// @notice Method called to notify a reward receiver it has received a reward.
  /// @param _amount The amount of reward.
  function notifyRewardAmount(uint256 _amount) external;
}

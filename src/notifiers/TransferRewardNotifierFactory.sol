// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {TransferRewardNotifier} from "./TransferRewardNotifier.sol";
import {INotifiableRewardReceiver} from "../interfaces/INotifiableRewardReceiver.sol";

/// @title TransferRewardNotifierFactory
/// @notice Factory contract for creating TransferRewardNotifier instances
/// @dev This factory simplifies the deployment of TransferRewardNotifier contracts that use
/// ERC20 transfer to move tokens from the notifier's balance to the Staker
contract TransferRewardNotifierFactory {
  /// @notice Emitted when a new TransferRewardNotifier is deployed
  /// @param notifier The address of the newly created notifier
  /// @param receiver The address of the staker that will receive rewards
  /// @param rewardToken The token being distributed as rewards
  /// @param initialRewardAmount The amount of tokens distributed per notification
  /// @param initialRewardInterval The time between reward distributions
  /// @param owner The address with administrative control of the notifier
  event TransferRewardNotifierCreated(
    address indexed notifier,
    address indexed receiver,
    address indexed rewardToken,
    uint256 initialRewardAmount,
    uint256 initialRewardInterval,
    address owner
  );

  /// @notice Track all notifiers created by this factory
  address[] public allNotifiers;

  /// @notice Returns the number of notifiers created by this factory
  /// @return The total count of notifiers
  function allNotifiersLength() external view returns (uint256) {
    return allNotifiers.length;
  }

  /// @notice Creates a new TransferRewardNotifier instance
  /// @param receiver The staker contract that will receive rewards
  /// @param initialRewardAmount Amount of tokens to distribute each notification period
  /// @param initialRewardInterval Time that must elapse between notifications
  /// @param owner The address that will have administrative control of the notifier
  /// @return notifier The address of the newly created notifier
  function createTransferRewardNotifier(
    INotifiableRewardReceiver receiver,
    uint256 initialRewardAmount,
    uint256 initialRewardInterval,
    address owner
  ) external returns (address notifier) {
    // Deploy the notifier
    TransferRewardNotifier newNotifier =
      new TransferRewardNotifier(receiver, initialRewardAmount, initialRewardInterval, owner);

    notifier = address(newNotifier);

    // Record the new notifier
    allNotifiers.push(notifier);

    // Emit creation event
    emit TransferRewardNotifierCreated(
      notifier,
      address(receiver),
      address(receiver.REWARD_TOKEN()),
      initialRewardAmount,
      initialRewardInterval,
      owner
    );
  }
}

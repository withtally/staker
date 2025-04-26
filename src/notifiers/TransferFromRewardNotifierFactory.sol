// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {TransferFromRewardNotifier} from "./TransferFromRewardNotifier.sol";
import {INotifiableRewardReceiver} from "../interfaces/INotifiableRewardReceiver.sol";

/// @title TransferFromRewardNotifierFactory
/// @notice Factory contract for creating TransferFromRewardNotifier instances
/// @dev This factory simplifies the deployment of TransferFromRewardNotifier contracts that use
/// ERC20 transferFrom to move tokens from a designated source address to the Staker
contract TransferFromRewardNotifierFactory {
  /// @notice Emitted when a new TransferFromRewardNotifier is deployed
  /// @param notifier The address of the newly created notifier
  /// @param receiver The address of the staker that will receive rewards
  /// @param rewardToken The token being distributed as rewards
  /// @param initialRewardAmount The amount of tokens distributed per notification
  /// @param initialRewardInterval The time between reward distributions
  /// @param owner The address with administrative control of the notifier
  /// @param initialRewardSource The address from which rewards will be transferred
  event TransferFromRewardNotifierCreated(
    address indexed notifier,
    address indexed receiver,
    address indexed rewardToken,
    uint256 initialRewardAmount,
    uint256 initialRewardInterval,
    address owner,
    address initialRewardSource
  );

  /// @notice Track all notifiers created by this factory
  address[] public allNotifiers;

  /// @notice Returns the number of notifiers created by this factory
  /// @return The total count of notifiers
  function allNotifiersLength() external view returns (uint256) {
    return allNotifiers.length;
  }

  /// @notice Creates a new TransferFromRewardNotifier instance
  /// @param receiver The staker contract that will receive rewards
  /// @param initialRewardAmount Amount of tokens to distribute each notification period
  /// @param initialRewardInterval Time that must elapse between notifications
  /// @param owner The address that will have administrative control of the notifier
  /// @param initialRewardSource The address from which rewards will be transferred
  /// @return notifier The address of the newly created notifier
  function createTransferFromRewardNotifier(
    INotifiableRewardReceiver receiver,
    uint256 initialRewardAmount,
    uint256 initialRewardInterval,
    address owner,
    address initialRewardSource
  ) external returns (address notifier) {
    // Deploy the notifier
    TransferFromRewardNotifier newNotifier = new TransferFromRewardNotifier(
      receiver, initialRewardAmount, initialRewardInterval, owner, initialRewardSource
    );

    notifier = address(newNotifier);

    // Record the new notifier
    allNotifiers.push(notifier);

    // Emit creation event
    emit TransferFromRewardNotifierCreated(
      notifier,
      address(receiver),
      address(receiver.REWARD_TOKEN()),
      initialRewardAmount,
      initialRewardInterval,
      owner,
      initialRewardSource
    );
  }
}

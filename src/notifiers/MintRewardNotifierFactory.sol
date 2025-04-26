// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {MintRewardNotifier} from "./MintRewardNotifier.sol";
import {IMintable} from "../interfaces/IMintable.sol";
import {INotifiableRewardReceiver} from "../interfaces/INotifiableRewardReceiver.sol";

/// @title MintRewardNotifierFactory
/// @notice Factory contract for creating MintRewardNotifier instances
/// @dev This factory simplifies the deployment of MintRewardNotifier contracts that use
/// a minting mechanism to create new reward tokens and send them to the Staker
contract MintRewardNotifierFactory {
  /// @notice Emitted when a new MintRewardNotifier is deployed
  /// @param notifier The address of the newly created notifier
  /// @param receiver The address of the staker that will receive rewards
  /// @param rewardToken The token being distributed as rewards
  /// @param initialRewardAmount The amount of tokens distributed per notification
  /// @param initialRewardInterval The time between reward distributions
  /// @param owner The address with administrative control of the notifier
  /// @param minter The contract authorized to mint reward tokens
  event MintRewardNotifierCreated(
    address indexed notifier,
    address indexed receiver,
    address indexed rewardToken,
    uint256 initialRewardAmount,
    uint256 initialRewardInterval,
    address owner,
    address minter
  );

  /// @notice Track all notifiers created by this factory
  address[] public allNotifiers;

  /// @notice Returns the number of notifiers created by this factory
  /// @return The total count of notifiers
  function allNotifiersLength() external view returns (uint256) {
    return allNotifiers.length;
  }

  /// @notice Creates a new MintRewardNotifier instance
  /// @param receiver The staker contract that will receive rewards
  /// @param initialRewardAmount Amount of tokens to distribute each notification period
  /// @param initialRewardInterval Time that must elapse between notifications
  /// @param owner The address that will have administrative control of the notifier
  /// @param minter The contract authorized to mint reward tokens
  /// @return notifier The address of the newly created notifier
  function createMintRewardNotifier(
    INotifiableRewardReceiver receiver,
    uint256 initialRewardAmount,
    uint256 initialRewardInterval,
    address owner,
    IMintable minter
  ) external returns (address notifier) {
    // Deploy the notifier
    MintRewardNotifier newNotifier =
      new MintRewardNotifier(receiver, initialRewardAmount, initialRewardInterval, owner, minter);

    notifier = address(newNotifier);

    // Record the new notifier
    allNotifiers.push(notifier);

    // Emit creation event
    emit MintRewardNotifierCreated(
      notifier,
      address(receiver),
      address(receiver.REWARD_TOKEN()),
      initialRewardAmount,
      initialRewardInterval,
      owner,
      address(minter)
    );
  }
}

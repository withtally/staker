// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver} from "../../interfaces/INotifiableRewardReceiver.sol";
import {IMintable} from "../../interfaces/IMintable.sol";
import {DeployBase} from "../DeployBase.sol";
import {MintRewardNotifier} from "../../notifiers/MintRewardNotifier.sol";
import {Staker} from "../../Staker.sol";

/// @title DeployMintRewardNotifer
/// @author [ScopeLift](https://scopelift.co)
/// @notice An abstract contract that has the interface and logic necessary to
/// deploy a `MintRewardNotifier` contract. This contract is part of our modular deployment system
/// and can be combined with other script contracts in order to deploy an entire Staker
/// system.
abstract contract DeployMintRewardNotifier is DeployBase {
  /// @notice The configuration for the mint reward notifier.
  /// @param _receiver The contract that will receive reward notifications, typically an instance
  /// of Staker.
  /// @param _initialRewardAmount The initial amount of reward tokens to be distributed per
  /// notification.
  /// @param _initialRewardInterval The initial minimum time that must elapse between
  /// notifications.
  /// @param _initialOwner The address that will have permission to update contract parameters.
  /// @param _minter The initial contract authorized to mint reward tokens.
  struct MintRewardNotifierConfiguration {
    uint256 initialRewardAmount;
    uint256 initialRewardInterval;
    address initialOwner;
    IMintable minter;
  }

  /// @notice An interface method that returns the configuration for the mint reward notifier.
  function _mintRewardNotifierConfiguration()
    internal
    virtual
    returns (MintRewardNotifierConfiguration memory);

  /// @notice Deploys a mint reward notifier.
  /// @inheritdoc DeployBase
  /// @dev When this method is overridden make sure to call super so it is added to the reward
  /// notifiers array.
  function _deployRewardNotifiers(Staker _staker) internal virtual override {
    MintRewardNotifierConfiguration memory _config = _mintRewardNotifierConfiguration();
    MintRewardNotifier _notifier = new MintRewardNotifier(
      INotifiableRewardReceiver(address(_staker)),
      _config.initialRewardAmount,
      _config.initialRewardInterval,
      _config.initialOwner,
      _config.minter
    );
    rewardNotifiers.push(address(_notifier));
  }
}

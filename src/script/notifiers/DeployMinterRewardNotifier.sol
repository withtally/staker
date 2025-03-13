// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver} from "../../interfaces/INotifiableRewardReceiver.sol";
import {IMintable} from "../../interfaces/IMintable.sol";
import {DeployBase} from "../DeployBase.sol";
import {MintRewardNotifier} from "../../notifiers/MintRewardNotifier.sol";
import {Staker} from "../../Staker.sol";

abstract contract DeployMinterRewardNotifier is DeployBase {
  /// @notice The configuration for the minter reward notifier.
  /// @param _receiver The contract that will receive reward notifications, typically an instance
  /// of Staker.
  /// @param _initialRewardAmount The initial amount of reward tokens to be distributed per
  /// notification.
  /// @param _initialRewardInterval The initial minimum time that must elapse between
  /// notifications.
  /// @param _initialOwner The address that will have permission to update contract parameters.
  /// @param _minter The initial contract authorized to mint reward tokens.
  struct MinterRewardNotifierConfiguration {
    uint256 initialRewardAmount;
    uint256 initialRewardInterval;
    address initialOwner;
    IMintable minter;
  }

  /// @notice An interface method that returns the configuration for the minter reward notifier.
  function _deployMinterRewardNotifierConfiguration()
    internal
    virtual
    returns (MinterRewardNotifierConfiguration memory);

  /// @notice Deploys a minter reward notifier.
  /// @inheritdoc DeployBase
  /// @dev When this method is overridden make sure to call super so it is added to the reward
  /// notifiers array.
  function _deployRewardNotifiers(Staker _staker) internal virtual override {
    MinterRewardNotifierConfiguration memory _config = _deployMinterRewardNotifierConfiguration();
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

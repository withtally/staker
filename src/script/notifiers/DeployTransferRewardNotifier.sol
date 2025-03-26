// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver, IERC20} from "../../interfaces/INotifiableRewardReceiver.sol";
import {TransferRewardNotifier} from "../../notifiers/TransferRewardNotifier.sol";
import {DeployBase} from "../DeployBase.sol";
import {Staker} from "../../Staker.sol";

abstract contract DeployTransferRewardNotifier is DeployBase {
  /// @notice The configuration for the transfer reward notifier.
  /// @param _initialRewardAmount The initial amount of reward tokens to be distributed per
  /// notification.
  /// @param _initialRewardInterval The initial minimum time that must elapse between
  /// notifications.
  /// @param _initialOwner The address that will have permission to update contract parameters.
  struct TransferRewardNotifierConfiguration {
    uint256 initialRewardAmount;
    uint256 initialRewardInterval;
    address initialOwner;
  }

  /// @notice An interface method that returns the configuration for the transfer reward
  /// notifier.
  function _transferRewardNotifierConfiguration()
    internal
    virtual
    returns (TransferRewardNotifierConfiguration memory);

  /// @notice Deploys a transfer reward notifier.
  /// @inheritdoc DeployBase
  /// @dev When this method is overridden make sure to call super so it is added to the reward
  /// notifiers array.
  function _deployRewardNotifiers(Staker _staker) internal virtual override {
    TransferRewardNotifierConfiguration memory _config = _transferRewardNotifierConfiguration();
    TransferRewardNotifier _notifier = new TransferRewardNotifier(
      INotifiableRewardReceiver(address(_staker)),
      _config.initialRewardAmount,
      _config.initialRewardInterval,
      _config.initialOwner
    );
    rewardNotifiers.push(address(_notifier));
  }
}

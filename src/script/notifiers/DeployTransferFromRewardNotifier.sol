// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver, IERC20} from "../../interfaces/INotifiableRewardReceiver.sol";
import {TransferFromRewardNotifier} from "../../notifiers/TransferFromRewardNotifier.sol";
import {DeployBase} from "../DeployBase.sol";
import {Staker} from "../../Staker.sol";

abstract contract DeployTransferFromRewardNotifier is DeployBase {
  /// @notice The configuration for the transferFrom reward notifier.
  /// @param initialRewardAmount The initial amount of reward tokens to be distributed per
  /// notification.
  /// @param initialRewardInterval The initial minimum time that must elapse between
  /// notifications.
  /// @param initialOwner The address that will have permission to update contract parameters.
  /// @param initialRewardSource The initial source of reward tokens.
  struct TransferFromRewardNotifierConfiguration {
    uint256 initialRewardAmount;
    uint256 initialRewardInterval;
    address initialOwner;
    address initialRewardSource;
  }

  /// @notice An interface method that returns the configuration for the transferFrom reward
  /// notifier.
  function _transferFromRewardNotifierConfiguration()
    internal
    virtual
    returns (TransferFromRewardNotifierConfiguration memory);

  /// @notice Deploys a transferFrom reward notifier.
  /// @inheritdoc DeployBase
  /// @dev When this method is overridden make sure to call super so it is added to the reward
  /// notifiers array.
  function _deployRewardNotifiers(Staker _staker) internal virtual override {
    TransferFromRewardNotifierConfiguration memory _config =
      _transferFromRewardNotifierConfiguration();
    TransferFromRewardNotifier _notifier = new TransferFromRewardNotifier(
      INotifiableRewardReceiver(address(_staker)),
      _config.initialRewardAmount,
      _config.initialRewardInterval,
      _config.initialOwner,
      _config.initialRewardSource
    );
    rewardNotifiers.push(address(_notifier));
  }
}

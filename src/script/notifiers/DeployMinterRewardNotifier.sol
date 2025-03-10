// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver} from "../../interfaces/INotifiableRewardReceiver.sol";
import {IMintable} from "../../interfaces/IMintable.sol";
import {DeployBase} from "../DeployBase.sol";
import {MintRewardNotifier} from "../../notifiers/MintRewardNotifier.sol";

abstract contract DeployMinterRewardNotifier is DeployBase {
  struct MinterRewardNotifierConfiguration {
    INotifiableRewardReceiver receiver;
    uint256 initialRewardAmount;
    uint256 initialRewardInterval;
    address initialOwner;
    IMintable minter;
  }

  function _deployMinterRewardNotifierConfiguration()
    internal
    virtual
    returns (MinterRewardNotifierConfiguration memory);

  function _deployRewardNotifiers() internal virtual override {
    MinterRewardNotifierConfiguration memory _config = _deployMinterRewardNotifierConfiguration();
    MintRewardNotifier _notifier = new MintRewardNotifier(
      _config.receiver,
      _config.initialRewardAmount,
      _config.initialRewardInterval,
      _config.initialOwner,
      _config.minter
    );
    rewardNotifiers[rewardNotifiers.length] =
      RewardNotifier({rewardNotifier: address(_notifier), isEnabled: true});
  }
}

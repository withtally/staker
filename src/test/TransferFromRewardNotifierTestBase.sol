// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.23;

import {TransferFromRewardNotifier} from "../notifiers/TransferFromRewardNotifier.sol";
import {IMintable} from "../interfaces/IMintable.sol";
import {StakerTestBase} from "./StakerTestBase.sol";

/// @title TransferFromRewardNotifierTestBase
/// @author [ScopeLift](https://scopelift.co)
/// @notice Base contract for testing a staker contract with a single `TransferFromRewardNotifier`.
/// Extends `StakerTestBase` and implements the reward notification logic.
/// @dev This contract requires an initialized instance of `TransferFromRewardNotifier`.
/// Initialization is typically handled by a deployment script such as
/// `src/script/notifiers/DeployTransferFromRewardNotifier.sol`
abstract contract TransferFromRewardNotifierTestBase is StakerTestBase {
  TransferFromRewardNotifier transferFromRewardNotifier;

  /// @notice Sets the reward amount, then prepares for and executes `notify` on
  /// `TransferFromRewardNotifier`. Preparation involves minting tokens to `rewardSource` and
  /// `rewardSource` approving them for `transferFromRewardNotifier`. The `notify` execution then
  /// triggers the token transfer and reward distribution.
  function _notifyRewardAmount(uint256 _amount) public override {
    address _owner = transferFromRewardNotifier.owner();
    address _source = transferFromRewardNotifier.rewardSource();

    vm.prank(_owner);
    transferFromRewardNotifier.setRewardAmount(_amount);

    vm.startPrank(_source);
    IMintable(address(REWARD_TOKEN)).mint(_source, _amount);
    REWARD_TOKEN.approve(address(transferFromRewardNotifier), _amount);
    vm.stopPrank();

    transferFromRewardNotifier.notify();
  }
}

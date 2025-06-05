// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.23;

import {TransferRewardNotifier} from "../notifiers/TransferRewardNotifier.sol";
import {IMintable} from "src/interfaces/IMintable.sol";
import {StakerTestBase} from "./StakerTestBase.sol";

/// @title TransferRewardNotifierTestBase
/// @author [ScopeLift](https://scopelift.co)
/// @notice Base contract for testing a staker contract with a single `TransferRewardNotifier`.
/// Extends `StakerTestBase` and implements the reward notification logic.
/// @dev This contract requires an initialized instance of `TransferRewardNotifier`. Initialization
/// is typically handled by a deployment script such as
/// `src/script/notifiers/DeployTransferRewardNotifier.sol`
abstract contract TransferRewardNotifierTestBase is StakerTestBase {
  TransferRewardNotifier transferRewardNotifier;

  /// @notice Sets the reward amount, then prepares for and executes `notify` on
  /// `TransferRewardNotifier`. Preparation involves minting tokens to `transferRewardNotifier`. The
  /// `notify` execution then triggers the token transfer and reward distribution.
  function _notifyRewardAmount(uint256 _amount) public override {
    address _owner = transferRewardNotifier.owner();

    vm.prank(_owner);
    transferRewardNotifier.setRewardAmount(_amount);

    IMintable(address(REWARD_TOKEN)).mint(address(transferRewardNotifier), _amount);
    transferRewardNotifier.notify();
  }
}

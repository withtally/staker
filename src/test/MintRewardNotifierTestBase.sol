// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.23;

import {MintRewardNotifier} from "../notifiers/MintRewardNotifier.sol";
import {StakerTestBase} from "./StakerTestBase.sol";

/// @title MintRewardNotifierTestBase
/// @author [ScopeLift](https://scopelift.co)
/// @notice Base contract for testing a staker contract with a single `MintRewardNotifier`. Extends
/// `StakerTestBase` and implements the reward notification logic.
/// @dev This contract requires an initialized instance of `MintRewardNotifier`. Initialization is
/// typically handled by a deployment script such as
/// `src/script/notifiers/DeployMintRewardNotifier.sol`
abstract contract MintRewardNotifierTestBase is StakerTestBase {
  /// @notice The mint reward notifier to test.
  MintRewardNotifier mintRewardNotifier;

  /// @notice Sets the reward amount, then calls the `notify` function that triggers token minting
  /// and reward distribution.
  /// @param _amount The amount of reward to notify the staker contract.
  function _notifyRewardAmount(uint256 _amount) public override {
    address _owner = mintRewardNotifier.owner();

    vm.prank(_owner);
    mintRewardNotifier.setRewardAmount(_amount);

    mintRewardNotifier.notify();
  }
}

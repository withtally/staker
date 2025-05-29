// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.23;

import {MintRewardNotifier} from "../notifiers/MintRewardNotifier.sol";
import {StakerTestBase} from "./StakerTestBase.sol";

/// @title MintRewardNotifierTestBase
/// @author [ScopeLift](https://scopelift.co)
/// @notice Base contract for testing `MintRewardNotifier` functionality. Extends `StakerTestBase`
/// and provides the necessary setup for the `notify` on `MintRewardNotifier`.
/// @dev This contract is designed to be used in conjunction with the deployment scripts in
/// `src/script/notifiers/DeployMintRewardNotifier.sol`.
abstract contract MintRewardNotifierTestBase is StakerTestBase {
  MintRewardNotifier mintRewardNotifier;

  /// @notice Sets the reward amount, then calls the `notify` function that triggers token minting
  /// and reward distribution.
  function _notifyRewardAmount(uint256 _amount) public override {
    address _owner = mintRewardNotifier.owner();

    vm.prank(_owner);
    mintRewardNotifier.setRewardAmount(_amount);

    mintRewardNotifier.notify();
  }
}

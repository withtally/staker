// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {MintRewardNotifier} from "../notifiers/MintRewardNotifier.sol";
import {StakerTestBase} from "./StakerTestBase.sol";

/// @notice Base contract for testing MintRewardNotifier functionality.
/// @dev Extends StakerTestBase and provides reward notification testing utilities.
/// Simulates calling notify function on MintRewardNotifier.
abstract contract MintRewardNotifierTestBase is StakerTestBase {
  MintRewardNotifier mintRewardNotifier;

  function _notifyRewardAmount(uint256 _amount) public override {
    address _owner = mintRewardNotifier.owner();

    vm.prank(_owner);
    mintRewardNotifier.setRewardAmount(_amount);

    mintRewardNotifier.notify();
  }
}

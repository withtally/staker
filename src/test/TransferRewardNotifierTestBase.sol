// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {TransferRewardNotifier} from "../notifiers/TransferRewardNotifier.sol";
import {IMintable} from "src/interfaces/IMintable.sol";
import {StakerTestBase} from "./StakerTestBase.sol";

/// @title TransferRewardNotifierTestBase
/// @author [ScopeLift](https://scopelift.co)
/// @notice Base contract for testing TransferRewardNotifier functionality. Extends StakerTestBase
/// and simulates calling notify function on TransferRewardNotifier. This contract is designed to be
/// used in conjunction with the deployment scripts in
/// `src/script/notifiers/DeployTransferRewardNotifier.sol`.
abstract contract TransferRewardNotifierTestBase is StakerTestBase {
  TransferRewardNotifier transferRewardNotifier;

  function _notifyRewardAmount(uint256 _amount) public override {
    address _owner = transferRewardNotifier.owner();

    vm.prank(_owner);
    transferRewardNotifier.setRewardAmount(_amount);

    IMintable(address(REWARD_TOKEN)).mint(address(transferRewardNotifier), _amount);
    transferRewardNotifier.notify();
  }
}

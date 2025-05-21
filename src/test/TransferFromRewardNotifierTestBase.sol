// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {TransferFromRewardNotifier} from "../notifiers/TransferFromRewardNotifier.sol";
import {IMintable} from "src/interfaces/IMintable.sol";
import {StakerTestBase} from "./StakerTestBase.sol";

/// @notice Base contract for testing TransferFromRewardNotifier functionality.
/// @dev Extends StakerTestBase and simulates calling notify function on TransferFromRewardNotifier.
/// This contract is designed to be used in conjunction with the deployment scripts in
/// `src/script/notifiers/DeployTransferFromRewardNotifier.sol`.
abstract contract TransferFromRewardNotifierTestBase is StakerTestBase {
  TransferFromRewardNotifier transferFromRewardNotifier;

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

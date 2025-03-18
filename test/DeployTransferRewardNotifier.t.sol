// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Staker} from "../src/Staker.sol";
import {IEarningPowerCalculator} from "../src/interfaces/IEarningPowerCalculator.sol";
import {INotifiableRewardReceiver} from "../src/interfaces/INotifiableRewardReceiver.sol";
import {TransferRewardNotifier} from "../src/notifiers/TransferRewardNotifier.sol";
import {DeployTransferRewardNotifierHarness} from
  "./harnesses/DeployTransferRewardNotifierHarness.sol";
import {ERC20Fake} from "./fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "./mocks/MockERC20Votes.sol";

contract DeployTransferRewardNotifierTest is Test {
  ERC20Fake rewardToken;
  ERC20VotesMock govToken;
  DeployTransferRewardNotifierHarness deployScript;

  function setUp() public {
    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Reward Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");

    deployScript = new DeployTransferRewardNotifierHarness(rewardToken, govToken);
  }
}

contract run is DeployTransferRewardNotifierTest {
  function test_DeployTransferRewardNotifier() public {
    (, Staker _staker, address[] memory _notifiers) = deployScript.run();

    TransferRewardNotifier _transferNotifier = TransferRewardNotifier(_notifiers[0]);
    assertEq(address(_staker), address(_transferNotifier.RECEIVER()));
    assertEq(10e18, _transferNotifier.rewardAmount());
    assertEq(30 days, _transferNotifier.rewardInterval());
    assertEq(deployScript.notifierOwner(), _transferNotifier.owner());
  }
}
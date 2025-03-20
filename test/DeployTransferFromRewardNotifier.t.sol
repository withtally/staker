// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Staker} from "../src/Staker.sol";
import {IEarningPowerCalculator} from "../src/interfaces/IEarningPowerCalculator.sol";
import {INotifiableRewardReceiver} from "../src/interfaces/INotifiableRewardReceiver.sol";
import {TransferFromRewardNotifier} from "../src/notifiers/TransferFromRewardNotifier.sol";
import {FakeDeployTransferFromRewardNotifier} from
  "./fakes/FakeDeployTransferFromRewardNotifier.sol";
import {ERC20Fake} from "./fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "./mocks/MockERC20Votes.sol";

contract DeployTransferFromRewardNotifierTest is Test {
  ERC20Fake rewardToken;
  ERC20VotesMock govToken;
  FakeDeployTransferFromRewardNotifier deployScript;

  function setUp() public {
    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Reward Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");

    deployScript = new FakeDeployTransferFromRewardNotifier(rewardToken, govToken);
  }
}

contract run is DeployTransferFromRewardNotifierTest {
  function test_DeployTransferFromRewardNotifier() public {
    (, Staker _staker, address[] memory _notifiers) = deployScript.run();

    TransferFromRewardNotifier _transferFromNotifier = TransferFromRewardNotifier(_notifiers[0]);
    assertEq(address(_staker), address(_transferFromNotifier.RECEIVER()));
    assertEq(10e18, _transferFromNotifier.rewardAmount());
    assertEq(30 days, _transferFromNotifier.rewardInterval());
    assertEq(deployScript.notifierOwner(), _transferFromNotifier.owner());
    assertEq(
      address(deployScript.notifierRewardSource()), address(_transferFromNotifier.rewardSource())
    );
  }
}

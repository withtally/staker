// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Staker} from "../src/Staker.sol";
import {TransferFromRewardNotifier} from "../src/notifiers/TransferFromRewardNotifier.sol";
import {DeployTransferFromRewardNotifierFake} from
  "./fakes/DeployTransferFromRewardNotifierFake.sol";
import {ERC20Fake} from "./fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "./mocks/MockERC20Votes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DeployTransferFromRewardNotifierTest is Test {
  ERC20Fake rewardToken;
  ERC20VotesMock govToken;
  DeployTransferFromRewardNotifierFake deployScript;

  function setUp() public {
    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Reward Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");

    deployScript = new DeployTransferFromRewardNotifierFake(rewardToken, govToken);
  }
}

contract Run is DeployTransferFromRewardNotifierTest {
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

contract SetRewardSource is DeployTransferFromRewardNotifierTest {
  function testFuzz_UpdatesTheRewardSource(address _newRewardSource) public {
    (,, address[] memory _notifiers) = deployScript.run();
    TransferFromRewardNotifier _transferFromNotifier = TransferFromRewardNotifier(_notifiers[0]);
    address owner = deployScript.notifierOwner();

    vm.prank(owner);
    _transferFromNotifier.setRewardSource(_newRewardSource);

    assertEq(_transferFromNotifier.rewardSource(), _newRewardSource);
  }

  function testFuzz_EmitsAnEventForSettingTheRewardSource(address _newRewardSource) public {
    (,, address[] memory _notifiers) = deployScript.run();
    TransferFromRewardNotifier _transferFromNotifier = TransferFromRewardNotifier(_notifiers[0]);
    address owner = deployScript.notifierOwner();
    address _oldRewardSource = deployScript.notifierRewardSource();

    vm.expectEmit();
    emit TransferFromRewardNotifier.RewardSourceSet(_oldRewardSource, _newRewardSource);
    vm.prank(owner);
    _transferFromNotifier.setRewardSource(_newRewardSource);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(address _newRewardSource, address _notOwner) public {
    (,, address[] memory _notifiers) = deployScript.run();
    TransferFromRewardNotifier _transferFromNotifier = TransferFromRewardNotifier(_notifiers[0]);
    address owner = deployScript.notifierOwner();

    vm.assume(_notOwner != owner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    vm.prank(_notOwner);
    _transferFromNotifier.setRewardSource(_newRewardSource);
  }
}

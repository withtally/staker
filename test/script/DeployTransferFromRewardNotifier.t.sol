// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Staker} from "../../src/Staker.sol";
import {TransferFromRewardNotifier} from "../../src/notifiers/TransferFromRewardNotifier.sol";
import {DeployTransferFromRewardNotifierFake} from
  "../fakes/DeployTransferFromRewardNotifierFake.sol";
import {ERC20Fake} from "../fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "../mocks/MockERC20Votes.sol";

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
  function test_DeployedNotifierHasCorrectConfig() public {
    (, Staker _staker, address[] memory _notifiers) = deployScript.run();

    TransferFromRewardNotifier _transferFromNotifier = TransferFromRewardNotifier(_notifiers[0]);
    assertEq(address(_staker), address(_transferFromNotifier.RECEIVER()));
    assertEq(deployScript.initialRewardAmount(), _transferFromNotifier.rewardAmount());
    assertEq(deployScript.initialRewardInterval(), _transferFromNotifier.rewardInterval());
    assertEq(deployScript.notifierOwner(), _transferFromNotifier.owner());
    assertEq(
      address(deployScript.notifierRewardSource()), address(_transferFromNotifier.rewardSource())
    );
  }

  function test_DeployedNotifierMatchesExpectedBytecode() public {
    (, Staker _staker, address[] memory _notifiers) = deployScript.run();
    address deployedNotifier = _notifiers[0];

    // Encode constructor arguments with the same value as Fake
    bytes memory args = abi.encode(
      _staker, // receiver
      deployScript.initialRewardAmount(), // reward amount
      deployScript.initialRewardInterval(), // reward interval
      deployScript.notifierOwner(), // owner
      deployScript.notifierRewardSource() // reward source
    );

    // Get creation bytecode and append constructor args
    bytes memory bytecode = abi.encodePacked(
      vm.getCode("TransferFromRewardNotifier.sol:TransferFromRewardNotifier"), args
    );

    address expectedNotifier;
    assembly {
      expectedNotifier := create(0, add(bytecode, 0x20), mload(bytecode))
    }

    assertEq(deployedNotifier.code, expectedNotifier.code);
  }
}

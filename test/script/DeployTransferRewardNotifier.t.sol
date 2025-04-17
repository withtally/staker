// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Staker} from "../../src/Staker.sol";
import {TransferRewardNotifier} from "../../src/notifiers/TransferRewardNotifier.sol";
import {DeployTransferRewardNotifierFake} from "../fakes/DeployTransferRewardNotifierFake.sol";
import {ERC20Fake} from "../fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "../mocks/MockERC20Votes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DeployTransferRewardNotifierTest is Test {
  ERC20Fake rewardToken;
  ERC20VotesMock govToken;
  DeployTransferRewardNotifierFake deployScript;

  function setUp() public {
    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Reward Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");

    deployScript = new DeployTransferRewardNotifierFake(rewardToken, govToken);
  }
}

contract Run is DeployTransferRewardNotifierTest {
  function test_DeployTransferRewardNotifier() public {
    (, Staker _staker, address[] memory _notifiers) = deployScript.run();
    address deployedNotifier = _notifiers[0];

    // Encode constructor arguments with the same value as Fake
    bytes memory args = abi.encode(
      _staker, // receiver
      10e18, // reward amount
      30 days, // reward interval
      deployScript.notifierOwner() // owner
    );

    // Get creation bytecode and append constructor args
    bytes memory bytecode =
      abi.encodePacked(vm.getCode("TransferRewardNotifier.sol:TransferRewardNotifier"), args);

    address expectedNotifier;
    assembly {
      expectedNotifier := create(0, add(bytecode, 0x20), mload(bytecode))
    }

    assertEq(deployedNotifier.code, expectedNotifier.code);
  }
}

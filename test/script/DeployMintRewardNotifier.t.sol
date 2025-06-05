// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Staker} from "../../src/Staker.sol";
import {MintRewardNotifier} from "../../src/notifiers/MintRewardNotifier.sol";
import {DeployBaseFake} from "../fakes/DeployBaseFake.sol";
import {ERC20Fake} from "../fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "../mocks/MockERC20Votes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DeployMintRewardNotifierTest is Test {
  ERC20Fake rewardToken;
  ERC20VotesMock govToken;
  DeployBaseFake deployScript;

  function setUp() public {
    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Reward Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");

    deployScript = new DeployBaseFake(rewardToken, govToken);
  }
}

contract Run is DeployMintRewardNotifierTest {
  function test_DeployedNotifierHasCorrectConfig() public {
    (, Staker _staker, address[] memory _notifiers) = deployScript.run();

    MintRewardNotifier _transferFromNotifier = MintRewardNotifier(_notifiers[0]);
    assertEq(address(_staker), address(_transferFromNotifier.RECEIVER()));
    assertEq(deployScript.initialRewardAmount(), _transferFromNotifier.rewardAmount());
    assertEq(deployScript.initialRewardInterval(), _transferFromNotifier.rewardInterval());
    assertEq(deployScript.notifierOwner(), _transferFromNotifier.owner());
    assertEq(address(deployScript.notifierMinter()), address(_transferFromNotifier.minter()));
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
      deployScript.notifierMinter() // minter
    );

    // Get creation bytecode and append constructor args
    bytes memory bytecode =
      abi.encodePacked(vm.getCode("MintRewardNotifier.sol:MintRewardNotifier"), args);

    address expectedNotifier;
    assembly {
      expectedNotifier := create(0, add(bytecode, 0x20), mload(bytecode))
    }

    assertEq(deployedNotifier.code, expectedNotifier.code);
  }
}

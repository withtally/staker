// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Staker} from "../src/Staker.sol";
import {TransferRewardNotifier} from "../src/notifiers/TransferRewardNotifier.sol";
import {DeployTransferRewardNotifierFake} from "./fakes/DeployTransferRewardNotifierFake.sol";
import {ERC20Fake} from "./fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "./mocks/MockERC20Votes.sol";
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
    TransferRewardNotifier _transferNotifier = TransferRewardNotifier(_notifiers[0]);

    assertEq(address(_staker), address(_transferNotifier.RECEIVER()));
    assertEq(10e18, _transferNotifier.rewardAmount());
    assertEq(30 days, _transferNotifier.rewardInterval());
    assertEq(deployScript.notifierOwner(), _transferNotifier.owner());
  }
}

contract Approve is DeployTransferRewardNotifierTest {
  function testFuzz_ApprovesTheSpenderForTheAmount(address _spender, uint256 _amount) public {
    vm.assume(_spender != address(0));

    (,, address[] memory _notifiers) = deployScript.run();
    TransferRewardNotifier _transferNotifier = TransferRewardNotifier(_notifiers[0]);
    address owner = deployScript.notifierOwner();

    vm.prank(owner);
    _transferNotifier.approve(_spender, _amount);

    assertEq(rewardToken.allowance(address(_transferNotifier), _spender), _amount);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(address _spender, uint256 _amount, address _notOwner)
    public
  {
    vm.assume(_spender != address(0));

    (,, address[] memory _notifiers) = deployScript.run();
    TransferRewardNotifier _transferNotifier = TransferRewardNotifier(_notifiers[0]);
    address owner = deployScript.notifierOwner();

    vm.assume(_notOwner != owner);

    vm.prank(_notOwner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    _transferNotifier.approve(_spender, _amount);
  }
}

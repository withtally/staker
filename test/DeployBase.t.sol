// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IEarningPowerCalculator} from "../src/interfaces/IEarningPowerCalculator.sol";
import {MintRewardNotifier} from "../src/notifiers/MintRewardNotifier.sol";
import {TransferRewardNotifier} from "../src/notifiers/TransferRewardNotifier.sol";
import {Staker} from "../src/Staker.sol";
import {DeployBaseFake} from "./fakes/DeployBaseFake.sol";
import {DeployMultipleRewardNotifiersFake} from "./fakes/DeployMultipleRewardNotifiersFake.sol";
import {ERC20Fake} from "./fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "./mocks/MockERC20Votes.sol";

contract DeployBaseTest is Test {
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

contract Run is DeployBaseTest {
  function test_StakingSystemDeploy() public {
    (IEarningPowerCalculator _calculator, Staker _staker, address[] memory _notifiers) =
      deployScript.run();
    MintRewardNotifier _mintNotifier = MintRewardNotifier(_notifiers[0]);
    assertEq(address(_staker), address(_mintNotifier.RECEIVER()));
    assertEq(10e18, _mintNotifier.rewardAmount());
    assertEq(30 days, _mintNotifier.rewardInterval());
    assertEq(deployScript.notifierOwner(), _mintNotifier.owner());
    assertEq(address(deployScript.notifierMinter()), address(_mintNotifier.minter()));

    // Staker params
    assertTrue(_staker.isRewardNotifier(_notifiers[0]));
    assertEq(address(_calculator), address(_staker.earningPowerCalculator()));
    assertEq(address(rewardToken), address(_staker.REWARD_TOKEN()));
    assertEq(address(govToken), address(_staker.STAKE_TOKEN()));
    assertEq(address(deployScript.admin()), _staker.admin());
  }

  function test_StakingSystemMultipleRewardNotifiersDeploy() public {
    DeployMultipleRewardNotifiersFake _deployScript = new DeployMultipleRewardNotifiersFake(rewardToken, govToken);
    (IEarningPowerCalculator _calculator, Staker _staker, address[] memory _notifiers) =
      _deployScript.run();
    MintRewardNotifier _mintNotifier = MintRewardNotifier(_notifiers[0]);
    assertEq(address(_staker), address(_mintNotifier.RECEIVER()));
    assertEq(10e18, _mintNotifier.rewardAmount());
    assertEq(30 days, _mintNotifier.rewardInterval());
    assertEq(deployScript.notifierOwner(), _mintNotifier.owner());
    assertEq(address(deployScript.notifierMinter()), address(_mintNotifier.minter()));

    TransferRewardNotifier _transferNotifier = TransferRewardNotifier(_notifiers[0]);
    assertEq(address(_staker), address(_transferNotifier.RECEIVER()));
    assertEq(10e18, _transferNotifier.rewardAmount());
    assertEq(30 days, _transferNotifier.rewardInterval());
    assertEq(deployScript.notifierOwner(), _transferNotifier.owner());

    // Staker params
    assertTrue(_staker.isRewardNotifier(_notifiers[0]));
    assertTrue(_staker.isRewardNotifier(_notifiers[1]));
    assertEq(address(_calculator), address(_staker.earningPowerCalculator()));
    assertEq(address(rewardToken), address(_staker.REWARD_TOKEN()));
    assertEq(address(govToken), address(_staker.STAKE_TOKEN()));
    assertEq(address(deployScript.admin()), _staker.admin());

  }
}

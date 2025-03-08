// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IEarningPowerCalculator} from "../../src/interfaces/IEarningPowerCalculator.sol";
import {MintRewardNotifier} from "../../src/notifiers/MintRewardNotifier.sol";
import {TransferRewardNotifier} from "../../src/notifiers/TransferRewardNotifier.sol";
import {Staker} from "../../src/Staker.sol";
import {DeployBase} from "../../src/script/DeployBase.sol";
import {DeployBaseFake} from "../fakes/DeployBaseFake.sol";
import {DeployMultipleRewardNotifiersFake} from "../fakes/DeployMultipleRewardNotifiersFake.sol";
import {DeployBaseInvalidStakerAdminFake} from "../fakes/DeployBaseInvalidStakerAdminFake.sol";
import {ERC20Fake} from "../fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "../mocks/MockERC20Votes.sol";

contract DeployBaseTest is Test {
  ERC20Fake rewardToken;
  ERC20VotesMock govToken;

  function setUp() public {
    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Reward Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");
  }
}

contract Run is DeployBaseTest {
  function test_StakingSystemDeploy() public {
    DeployBaseFake _deployScript = new DeployBaseFake(rewardToken, govToken);
    (IEarningPowerCalculator _calculator, Staker _staker, address[] memory _notifiers) =
      _deployScript.run();
    MintRewardNotifier _mintNotifier = MintRewardNotifier(_notifiers[0]);
    assertEq(address(_staker), address(_mintNotifier.RECEIVER()));
    assertEq(_deployScript.initialRewardAmount(), _mintNotifier.rewardAmount());
    assertEq(_deployScript.initialRewardInterval(), _mintNotifier.rewardInterval());
    assertEq(_deployScript.notifierOwner(), _mintNotifier.owner());
    assertEq(address(_deployScript.notifierMinter()), address(_mintNotifier.minter()));

    // Staker params
    assertTrue(_staker.isRewardNotifier(_notifiers[0]));
    assertEq(address(_calculator), address(_staker.earningPowerCalculator()));
    assertEq(address(rewardToken), address(_staker.REWARD_TOKEN()));
    assertEq(address(govToken), address(_staker.STAKE_TOKEN()));
    assertEq(address(_deployScript.admin()), _staker.admin());
  }

  function test_StakingSystemMultipleRewardNotifiersDeploy() public {
    DeployMultipleRewardNotifiersFake _deployScript =
      new DeployMultipleRewardNotifiersFake(rewardToken, govToken);
    (IEarningPowerCalculator _calculator, Staker _staker, address[] memory _notifiers) =
      _deployScript.run();
    MintRewardNotifier _mintNotifier = MintRewardNotifier(_notifiers[0]);
    assertEq(address(_staker), address(_mintNotifier.RECEIVER()));
    assertEq(_deployScript.initialRewardAmount(), _mintNotifier.rewardAmount());
    assertEq(_deployScript.initialRewardInterval(), _mintNotifier.rewardInterval());
    assertEq(_deployScript.notifierOwner(), _mintNotifier.owner());
    assertEq(address(_deployScript.notifierMinter()), address(_mintNotifier.minter()));

    TransferRewardNotifier _transferNotifier = TransferRewardNotifier(_notifiers[1]);
    assertEq(address(_staker), address(_transferNotifier.RECEIVER()));
    assertEq(_deployScript.initialRewardAmount(), _transferNotifier.rewardAmount());
    assertEq(_deployScript.initialRewardInterval(), _transferNotifier.rewardInterval());
    assertEq(_deployScript.notifierOwner(), _transferNotifier.owner());

    // Staker params
    assertTrue(_staker.isRewardNotifier(_notifiers[0]));
    assertTrue(_staker.isRewardNotifier(_notifiers[1]));
    assertEq(address(_calculator), address(_staker.earningPowerCalculator()));
    assertEq(address(rewardToken), address(_staker.REWARD_TOKEN()));
    assertEq(address(govToken), address(_staker.STAKE_TOKEN()));
    assertEq(address(_deployScript.admin()), _staker.admin());
  }

  function test_RevertIf_StakerAdminIsNotTheDeployer() public {
    DeployBaseInvalidStakerAdminFake _deployScript =
      new DeployBaseInvalidStakerAdminFake(rewardToken, govToken);
    vm.expectRevert(DeployBase.DeployBase__InvalidInitialStakerAdmin.selector);
    _deployScript.run();
  }
}

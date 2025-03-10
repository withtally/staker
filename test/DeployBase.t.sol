// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IEarningPowerCalculator} from "../src/interfaces/IEarningPowerCalculator.sol";
import {DeployBase} from "../src/script/DeployBase.sol";
import {Staker} from "../../src/Staker.sol";
import {DeployBaseHarness} from "./harnesses/DeployBaseHarness.sol";
import {ERC20Fake} from "./fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "./mocks/MockERC20Votes.sol";

// Setup harness
contract DeployBaseTest is Test {
  ERC20Fake rewardToken;
  ERC20VotesMock govToken;
  DeployBaseHarness deployScript;

  function setUp() public {
    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Reward Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");

    deployScript = new DeployBaseHarness(rewardToken, govToken);
  }
}

// test run, mock configuration that is fuzzed
// check byte code matches

contract Run is DeployBaseTest {
  function test_StakingSystemDeploy() public {
    (IEarningPowerCalculator _calculator, Staker _staker, DeployBase.RewardNotifier[] memory _notifiers) = deployScript.run();
	assertEq(address(_calculator), address(_staker.earningPowerCalculator()));
	assertTrue(_staker.isRewardNotifier(_notifiers[0].rewardNotifier));
	assertEq(address(rewardToken), address(_staker.REWARD_TOKEN()));
	assertEq(address(govToken), address(_staker.STAKE_TOKEN()));
	assertEq(address(govToken), _staker.admin());


    // staker
    // earning power calculator
    // reward notifiers
  }
}

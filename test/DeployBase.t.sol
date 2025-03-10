// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
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
				deployScript.run();
				// staker
				// earning power calculator
				// reward notifiers
		
		}
}

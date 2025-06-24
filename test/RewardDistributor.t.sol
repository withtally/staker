// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, stdError} from "forge-std/Test.sol";
import {RewardDistributorHarness} from "../test/harnesses/RewardDistributorHarness.sol";
import {BinaryVotingPowerEarningPowerCalculator} from "../../src/calculators/BinaryVotingPowerEarningPowerCalculator.sol";

contract RewardDistributorBase is Test {}

contract RewardDistributor is RewardDistributorBase {
		function testFuzz_testEndToEnd() public {
				// fork test
				address _owner = makeAddr("Earning power owner");
				address _scoreOracle = makeAddr("scoreOracle");

				RewardDistributorHarness _distributor = new RewardDistributorHarness();
				BinaryVotingPowerEarningPowerCalculator _voting_power_distributor = new BinaryVotingPowerEarningPowerCalculator(_owner, _scoreOracle);
				// initialize delegate
		}

}

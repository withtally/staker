// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Staker} from "../src/Staker.sol";
import {DeployBinaryEligibilityOracleEarningPowerCalculatorFake} from
  "./fakes/DeployBinaryEligibilityOracleEarningPowerCalculatorFake.sol";
import {IEarningPowerCalculator} from "../src/interfaces/IEarningPowerCalculator.sol";
import {ERC20Fake} from "./fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "./mocks/MockERC20Votes.sol";

import {BinaryEligibilityOracleEarningPowerCalculator} from
  "../src/calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";

contract DeployBinaryEligibilityOracleEarningPowerCalculatorTest is Test {
  ERC20Fake rewardToken;
  ERC20VotesMock govToken;
  DeployBinaryEligibilityOracleEarningPowerCalculatorFake deployScript;

  function setUp() public {
    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Reward Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");

    deployScript =
      new DeployBinaryEligibilityOracleEarningPowerCalculatorFake(rewardToken, govToken);
  }
}

contract run is DeployBinaryEligibilityOracleEarningPowerCalculatorTest {
  function test_DeployBinaryEligibilityOracleEarningPowerCalculatorHarness() public {
    (IEarningPowerCalculator _calculator, Staker _staker,) = deployScript.run();
    BinaryEligibilityOracleEarningPowerCalculator _binaryEligibilityOracleCalculator =
      BinaryEligibilityOracleEarningPowerCalculator(address(_calculator));
    assertEq(address(_calculator), address(_staker.earningPowerCalculator()));
    assertEq(address(_binaryEligibilityOracleCalculator.owner()), makeAddr("owner"));
    assertEq(address(_binaryEligibilityOracleCalculator.scoreOracle()), makeAddr("scoreOracle"));
    assertEq(_binaryEligibilityOracleCalculator.STALE_ORACLE_WINDOW(), 7 days);
    assertEq(
      address(_binaryEligibilityOracleCalculator.oraclePauseGuardian()),
      makeAddr("oraclePauseGuardian")
    );
    assertEq(_binaryEligibilityOracleCalculator.delegateeEligibilityThresholdScore(), 50);
    assertEq(_binaryEligibilityOracleCalculator.updateEligibilityDelay(), 7 days);
  }
}

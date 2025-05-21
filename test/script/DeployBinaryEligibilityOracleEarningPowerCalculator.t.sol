// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Staker} from "../../src/Staker.sol";
import {DeployBinaryEligibilityOracleEarningPowerCalculatorFake} from
  "../fakes/DeployBinaryEligibilityOracleEarningPowerCalculatorFake.sol";
import {IEarningPowerCalculator} from "../../src/interfaces/IEarningPowerCalculator.sol";
import {ERC20Fake} from "../fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "../mocks/MockERC20Votes.sol";

import {BinaryEligibilityOracleEarningPowerCalculator} from
  "../../src/calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";

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

contract Run is DeployBinaryEligibilityOracleEarningPowerCalculatorTest {
  function test_DeployedCalculatorHasCorrectConfig() public {
    (IEarningPowerCalculator _calculator, Staker _staker,) = deployScript.run();
    BinaryEligibilityOracleEarningPowerCalculator _binaryEligibilityOracleCalculator =
      BinaryEligibilityOracleEarningPowerCalculator(address(_calculator));

    assertEq(address(_calculator), address(_staker.earningPowerCalculator()));
    assertEq(address(_binaryEligibilityOracleCalculator.owner()), deployScript.owner());
    assertEq(address(_binaryEligibilityOracleCalculator.scoreOracle()), deployScript.scoreOracle());
    assertEq(
      _binaryEligibilityOracleCalculator.STALE_ORACLE_WINDOW(), deployScript.staleOracleWindow()
    );
    assertEq(
      address(_binaryEligibilityOracleCalculator.oraclePauseGuardian()),
      deployScript.oraclePauseGuardian()
    );
    assertEq(
      _binaryEligibilityOracleCalculator.delegateeEligibilityThresholdScore(),
      deployScript.delegateeScoreEligibilityThreshold()
    );
    assertEq(
      _binaryEligibilityOracleCalculator.updateEligibilityDelay(),
      deployScript.upgradeEligibilityDelay()
    );
  }

  function test_DeployedCalculatorMatchesExpectedBytecode() public {
    (IEarningPowerCalculator _calculator,,) = deployScript.run();
    address deployedPowerCalculator = address(_calculator);

    // Encode constructor arguments with the same value as Harness
    bytes memory args = abi.encode(
      deployScript.owner(), // owner
      deployScript.scoreOracle(), // scoreOracle
      uint256(deployScript.staleOracleWindow()), // staleOracleWindow
      deployScript.oraclePauseGuardian(), // oraclePauseGuardian
      uint256(deployScript.delegateeScoreEligibilityThreshold()), // delegateeScoreEligibilityThreshold
      uint256(deployScript.upgradeEligibilityDelay()) // updateEligibilityDelay
    );

    // Get creation bytecode and append constructor args
    bytes memory bytecode = abi.encodePacked(
      vm.getCode(
        "BinaryEligibilityOracleEarningPowerCalculator.sol:BinaryEligibilityOracleEarningPowerCalculator"
      ),
      args
    );

    address expectedPowerCalculator;
    assembly {
      expectedPowerCalculator := create(0, add(bytecode, 0x20), mload(bytecode))
    }

    assertEq(deployedPowerCalculator.code, expectedPowerCalculator.code);
  }
}

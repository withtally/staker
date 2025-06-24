// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, stdError} from "forge-std/Test.sol";
import {RewardDistributorHarness} from "../test/harnesses/RewardDistributorHarness.sol";
import {BinaryVotingPowerEarningPowerCalculator} from
  "../../src/calculators/BinaryVotingPowerEarningPowerCalculator.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RewardDistributorBase is Test {}

contract RewardDistributor is RewardDistributorBase {
  function testFuzz_testEndToEnd() public {
    // fork test
    address _owner = makeAddr("Earning power owner");
    address _scoreOracle = makeAddr("scoreOracle");
    uint256 _staleOracleWindow = 7 days;
    address _oraclePauseGuardian = makeAddr("oraclePauseGuardian");
    uint256 _delegateeScoreEligibilityThreshold = 50;
    uint256 _updateEligibilityDelay = 7 days;
    uint48 _votingPowerUpdateFrequency = 3 days;
    address _votingPowerToken = 0x0B010000b7624eb9B3DfBC279673C76E9D29D5F7;
    uint256 _maxBumpTip = 1e18;
    address _admin = makeAddr("admin");
    address _scopeliftDelegate = 0x7C4b6f39D62Ca59ED3a4EFD4c347E23417ec5d5f;

    vm.createSelectFork(vm.rpcUrl("mainnet"), 22_773_964); // this needs to be changed
    BinaryVotingPowerEarningPowerCalculator _votingPowerDistributor = new BinaryVotingPowerEarningPowerCalculator(
      _owner,
      _scoreOracle,
      _staleOracleWindow,
      _oraclePauseGuardian,
      _delegateeScoreEligibilityThreshold,
      _updateEligibilityDelay,
      _votingPowerUpdateFrequency,
      _votingPowerToken
    );
    RewardDistributorHarness _distributor = new RewardDistributorHarness(
      IERC20(_votingPowerToken), _votingPowerDistributor, _maxBumpTip, _admin
    );
	vm.roll(22_773_964 + 10);
    // initialize delegate
    _distributor.initializeDelegateReward(_scopeliftDelegate);
  }
}

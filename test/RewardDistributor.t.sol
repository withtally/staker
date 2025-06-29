// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, stdError} from "forge-std/Test.sol";
import {RewardDistributorHarness} from "../test/harnesses/RewardDistributorHarness.sol";
import {BinaryVotingPowerEarningPowerCalculator} from
  "../../src/calculators/BinaryVotingPowerEarningPowerCalculator.sol";
import {BinaryEligibilityOracleEarningPowerCalculator} from
  "../../src/calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";
import {RewardDistributor} from "../../src/RewardDistributor.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Mint} from "./helpers/interfaces/IERC20Mint.sol";
import {PercentAssertions} from "./helpers/PercentAssertions.sol";

contract RewardDistributorBase is Test, PercentAssertions {
  address rewardNotifier = 0x9669C5D0eEC243366B570CE150caBE9e257049a5;
  address _votingPowerToken = 0x0B010000b7624eb9B3DfBC279673C76E9D29D5F7;
  IERC20Mint rewardToken = IERC20Mint(_votingPowerToken);
  RewardDistributorHarness distributor;

  function _mintTransferAndNotifyReward(uint256 _amount) public {
    vm.startPrank(rewardNotifier);
    rewardToken.transfer(address(distributor), _amount);
    distributor.notifyRewardAmount(_amount);
    vm.stopPrank();
  }
}

contract RewardDistributorTest is RewardDistributorBase {
  function testFuzz_testEndToEnd() public {
    // fork test
    address _owner = makeAddr("Earning power owner");
    address _scoreOracle = makeAddr("scoreOracle");
    uint256 _staleOracleWindow = 7 days;
    address _oraclePauseGuardian = makeAddr("oraclePauseGuardian");
    uint256 _delegateeScoreEligibilityThreshold = 0;
    uint256 _updateEligibilityDelay = 7 days;
    uint48 _votingPowerUpdateFrequency = 3 days;
    uint256 _maxBumpTip = 1e18;
    address _admin = makeAddr("admin");
    address _scopeliftDelegate = 0x7C4b6f39D62Ca59ED3a4EFD4c347E23417ec5d5f;

    vm.createSelectFork(vm.rpcUrl("mainnet"), 22_773_964); // this needs to be changed
    BinaryEligibilityOracleEarningPowerCalculator _binaryEarningPowerCalculator = new BinaryEligibilityOracleEarningPowerCalculator(
      _owner,
      _scoreOracle,
      _staleOracleWindow,
      _oraclePauseGuardian,
      _delegateeScoreEligibilityThreshold,
      _updateEligibilityDelay
    );

    BinaryVotingPowerEarningPowerCalculator _votingPowerDistributor = new BinaryVotingPowerEarningPowerCalculator(
      _owner, address(_binaryEarningPowerCalculator), _votingPowerToken, _votingPowerUpdateFrequency
    );

    distributor = new RewardDistributorHarness(
      IERC20(_votingPowerToken), _votingPowerDistributor, _maxBumpTip, _admin
    );
    vm.roll(22_773_964 + 10);
    // initialize delegate
    vm.prank(_admin);
    distributor.setRewardNotifier(rewardNotifier, true);

    // _notify reward
    _mintTransferAndNotifyReward(100e18);

    RewardDistributor.DepositIdentifier _depositId =
      distributor.initializeDelegateReward(_scopeliftDelegate);

    // Go through period
    vm.warp(block.timestamp + distributor.REWARD_DURATION());
    distributor.delegateRewards(_depositId);
    // Check that rewrd was earned
    assertLteWithinOneUnit(distributor.unclaimedReward(_depositId), 100e18);
  }
}

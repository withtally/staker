// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, stdError} from "forge-std/Test.sol";
import {DelegateCompensationStakerHarness} from
  "../test/harnesses/DelegateCompensationStakerHarness.sol";
import {BinaryVotingPowerEarningPowerCalculator} from
  "../../src/calculators/BinaryVotingPowerEarningPowerCalculator.sol";
import {BinaryEligibilityOracleEarningPowerCalculator} from
  "../../src/calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";
import {Staker} from "../../src/Staker.sol";
import {DelegateCompensationStaker} from "../../src/DelegateCompensationStaker.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Mint} from "./helpers/interfaces/IERC20Mint.sol";
import {PercentAssertions} from "./helpers/PercentAssertions.sol";

contract DelegateCompensationStakerBase is Test, PercentAssertions {
  address rewardNotifier = 0x9669C5D0eEC243366B570CE150caBE9e257049a5;
  address _votingPowerToken = 0x0B010000b7624eb9B3DfBC279673C76E9D29D5F7;
  IERC20Mint rewardToken = IERC20Mint(_votingPowerToken);
  DelegateCompensationStakerHarness delegateCompensation;

  function _mintTransferAndNotifyReward(uint256 _amount) public {
    vm.startPrank(rewardNotifier);
    rewardToken.transfer(address(delegateCompensation), _amount);
    delegateCompensation.notifyRewardAmount(_amount);
    vm.stopPrank();
  }
}

contract DelegateCompensationStakerBaseTest is DelegateCompensationStakerBase {
  function testFuzz_singleRewardDistributed() public {
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
    delegateCompensation = new DelegateCompensationStakerHarness(
      IERC20(_votingPowerToken), _votingPowerDistributor, _maxBumpTip, _admin
    );
    vm.roll(22_773_964 + 10);
    // initialize delegate
    vm.prank(_admin);
    delegateCompensation.setRewardNotifier(rewardNotifier, true);

    // _notify reward
    _mintTransferAndNotifyReward(100e18);

    Staker.DepositIdentifier _depositId =
      delegateCompensation.initializeDelegateReward(_scopeliftDelegate);

    // Go through period
    vm.warp(block.timestamp + delegateCompensation.REWARD_DURATION());
    // Check that rewrd was earned
    assertLteWithinOneUnit(delegateCompensation.unclaimedReward(_depositId), 100e18);
  }
}

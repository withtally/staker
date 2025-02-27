// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, stdError} from "forge-std/Test.sol";
import {GasReport} from "../../test/lib/GasReport.sol";
import {Staker} from "../../src/Staker.sol";
import {StakerTest} from "../../test/Staker.t.sol";

contract StakerGasReport is StakerTest, GasReport {
  function setUp() public override {
    super.setUp();
  }

  function REPORT_NAME() public pure override returns (string memory) {
    return "gov-staker";
  }

  function touchSlots() public override {
    // Touch the global variable slots by doing an initial stake.
    // This ensures all reported numbers, including the first one, are representative of what
    // a "real" use is likely to experience when interacting with a governance staker.
    _boundMintAndStake(makeAddr("Slot Warmer"), 100e18, makeAddr("Slot Warmer"));
  }

  function runScenarios() public override {
    address _staker;
    address _delegatee;
    Staker.DepositIdentifier _depositId;
    uint256 _rewardAmount;

    startScenario("First stake to a new delegatee");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      _staker = makeScenarioAddr("Initializer");
      _mintGovToken(_staker, 100e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 100e18);

      vm.startPrank(_staker);
      govStaker.stake(100e18, _delegatee);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Second stake to a existing delegatee");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      _staker = makeScenarioAddr("Initializer");
      _mintGovToken(_staker, 200e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 200e18);

      vm.startPrank(_staker);
      govStaker.stake(100e18, _delegatee);
      govStaker.stake(100e18, _delegatee);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Second stake to a new delegatee");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      address _delegatee2 = makeScenarioAddr("Delegatee 2");
      _staker = makeScenarioAddr("Initializer");
      _mintGovToken(_staker, 200e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 200e18);

      vm.startPrank(_staker);
      govStaker.stake(100e18, _delegatee);

      govStaker.stake(100e18, _delegatee2);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Stake more after initial stake");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      _staker = makeScenarioAddr("Initializer");
      _mintGovToken(_staker, 200e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 200e18);

      vm.startPrank(_staker);
      _depositId = govStaker.stake(100e18, _delegatee);

      govStaker.stakeMore(_depositId, 100e18);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Alter delegatee with new delegatee");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      address _delegatee2 = makeScenarioAddr("Delegatee 2");
      _staker = makeScenarioAddr("Initializer");
      _mintGovToken(_staker, 200e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 200e18);

      vm.startPrank(_staker);
      _depositId = govStaker.stake(100e18, _delegatee);

      govStaker.alterDelegatee(_depositId, _delegatee2);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Alter delegatee with existing delegatee");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      address _delegatee2 = makeScenarioAddr("Delegatee 2");
      _staker = makeScenarioAddr("Initializer");
      _mintGovToken(_staker, 200e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 200e18);

      vm.startPrank(_staker);
      _depositId = govStaker.stake(100e18, _delegatee);
      govStaker.stake(100e18, _delegatee2);

      govStaker.alterDelegatee(_depositId, _delegatee2);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Alter claimer to a new address");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      address _newClaimer = makeScenarioAddr("New Claimer");
      _staker = makeScenarioAddr("Initializer");
      _mintGovToken(_staker, 200e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 200e18);

      vm.startPrank(_staker);
      _depositId = govStaker.stake(100e18, _delegatee);

      govStaker.alterClaimer(_depositId, _newClaimer);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Withdraw full stake");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      _staker = makeScenarioAddr("Initializer");
      _mintGovToken(_staker, 100e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 100e18);

      vm.startPrank(_staker);
      _depositId = govStaker.stake(100e18, _delegatee);

      govStaker.withdraw(_depositId, 100e18);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Withdraw partial stake");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      _staker = makeScenarioAddr("Initializer");
      _mintGovToken(_staker, 100e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 100e18);

      vm.startPrank(_staker);
      _depositId = govStaker.stake(100e18, _delegatee);

      govStaker.withdraw(_depositId, 50e18);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Claim reward when no reward");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      _staker = makeScenarioAddr("Initializer");
      _mintGovToken(_staker, 100e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 100e18);

      vm.startPrank(_staker);
      _depositId = govStaker.stake(100e18, _delegatee);

      govStaker.claimReward(_depositId);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Claim reward when reward");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      _staker = makeScenarioAddr("Initializer");
      _mintGovToken(_staker, 100e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 100e18);

      vm.startPrank(_staker);
      _depositId = govStaker.stake(100e18, _delegatee);

      vm.startPrank(rewardNotifier);
      _rewardAmount = 10_000_000e18;
      // notify rewards
      rewardToken.mint(rewardNotifier, _rewardAmount);

      rewardToken.transfer(address(govStaker), _rewardAmount);
      govStaker.notifyRewardAmount(_rewardAmount);
      vm.stopPrank();

      vm.startPrank(_staker);
      vm.warp(block.timestamp + govStaker.REWARD_DURATION());
      govStaker.claimReward(_depositId);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Notify reward");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      _staker = makeScenarioAddr("Initializer");

      vm.startPrank(rewardNotifier);
      _rewardAmount = 10_000_000e18;
      rewardToken.mint(rewardNotifier, _rewardAmount);

      rewardToken.transfer(address(govStaker), _rewardAmount);
      govStaker.notifyRewardAmount(_rewardAmount);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Second notify reward");
    {
      vm.startPrank(rewardNotifier);
      _rewardAmount = 10_000_000e18;
      rewardToken.mint(rewardNotifier, _rewardAmount * 2);

      rewardToken.transfer(address(govStaker), _rewardAmount * 2);
      govStaker.notifyRewardAmount(_rewardAmount);

      govStaker.notifyRewardAmount(_rewardAmount);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Bump earning power up no reward");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      _staker = makeScenarioAddr("Initializer");
      address _bumper = makeScenarioAddr("Bumper");
      _mintGovToken(_staker, 100e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 100e18);

      vm.prank(_staker);
      _depositId = govStaker.stake(100e18, _delegatee);

      vm.startPrank(_bumper);
      earningPowerCalculator.__setEarningPowerForDelegatee(_delegatee, 200e18);

      govStaker.bumpEarningPower(_depositId, _bumper, 0);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Bump earning power down with reward");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      _staker = makeScenarioAddr("Initializer");
      address _bumper = makeScenarioAddr("Bumper");
      _mintGovToken(_staker, 100_000e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 100_000e18);

      vm.prank(_staker);
      _depositId = govStaker.stake(100_000e18, _delegatee);

      vm.startPrank(rewardNotifier);
      _rewardAmount = 10_000_000e18;
      // notify rewards
      rewardToken.mint(rewardNotifier, _rewardAmount);

      rewardToken.transfer(address(govStaker), _rewardAmount);
      govStaker.notifyRewardAmount(_rewardAmount);
      vm.stopPrank();
      vm.warp(block.timestamp + govStaker.REWARD_DURATION());
      console2.logUint(govStaker.unclaimedReward(_depositId));

      vm.startPrank(_bumper);
      earningPowerCalculator.__setEarningPowerForDelegatee(_delegatee, 50e18);

      govStaker.bumpEarningPower(_depositId, _bumper, 0);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    startScenario("Bump earning power up with reward");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      _staker = makeScenarioAddr("Initializer");
      address _bumper = makeScenarioAddr("Bumper");
      _mintGovToken(_staker, 100_000e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 100_000e18);

      vm.prank(_staker);
      _depositId = govStaker.stake(100_000e18, _delegatee);

      vm.startPrank(rewardNotifier);
      _rewardAmount = 10_000_000e18;
      // notify rewards
      rewardToken.mint(rewardNotifier, _rewardAmount);

      rewardToken.transfer(address(govStaker), _rewardAmount);
      govStaker.notifyRewardAmount(_rewardAmount);
      vm.stopPrank();
      vm.warp(block.timestamp + govStaker.REWARD_DURATION());
      console2.logUint(govStaker.unclaimedReward(_depositId));

      vm.startPrank(_bumper);
      earningPowerCalculator.__setEarningPowerForDelegatee(_delegatee, 150e18);

      govStaker.bumpEarningPower(_depositId, _bumper, 0);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();
  }
}

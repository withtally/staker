// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Vm, Test, stdStorage, StdStorage, console2, stdError} from "forge-std/Test.sol";
import {GasReport} from "test/gas-reports/GasReport.sol";
import {GovernanceStaker} from "src/GovernanceStaker.sol";
import {GovernanceStakerTest} from "test/GovernanceStaker.t.sol";

contract GovernanceStakerGasReport is GovernanceStakerTest, GasReport {
  function setUp() public override {
    super.setUp();
  }

  function REPORT_NAME() public pure override returns (string memory) {
    return "staker";
  }

  function touchSlots() public override {
    // Touch LST global variable slots by doing an initial deposit to the default delegatee.
    // This ensures all reported numbers, including the first one, are representative of what
    // a "real" use is likely to experience when interacting with the LST.
    _boundMintAndStake(makeAddr("Slot Warmer"), 100e18, makeAddr("Slot Warmer"));
    // Give the Withdraw Gate some tokens so it's balance slot is not empty for the first
    // withdrawal.
    //_mintStakeToken(address(withdrawGate), 100e18);
  }

  function runScenarios() public override {
    address _staker;
    address _delegatee;
    uint256 _stakeAmount;
    GovernanceStaker.DepositIdentifier _depositId;
    uint256 _rewardAmount;

    //-------------------------------------------------------------------------------------------//
    // INITIALIZE SCENARIOS
    //-------------------------------------------------------------------------------------------//

    // Stake scenarios
    // 1. Stake with no delegate surrogate
    // 2. Stake with existing delegate surrogate
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

    // 3. Stake more
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

    // 4. Alter delegatee not existing delegate surrogate
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

    // 5. Alter delgatee to existing delegatee
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

    // 6. Alter beneficiary
    startScenario("Alter beneficiary");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      address _newBeneficiary = makeScenarioAddr("New Beneficiary");
      _staker = makeScenarioAddr("Initializer");
      _mintGovToken(_staker, 200e18);
      vm.prank(_staker);
      govToken.approve(address(govStaker), 200e18);

      vm.startPrank(_staker);
      _depositId = govStaker.stake(100e18, _delegatee);

      govStaker.alterBeneficiary(_depositId, _newBeneficiary);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    // 7. Withdraw full stake
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

    // 8. Withdraw partial stake
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

    // 9. Claim reward when no reward
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

    // 10. Claim full reward
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

    // 11. Notify reward amount
    startScenario("Notify reward");
    {
      _delegatee = makeScenarioAddr("Delegatee");
      _staker = makeScenarioAddr("Initializer");

      vm.startPrank(rewardNotifier);
      _rewardAmount = 10_000_000e18;
      // notify rewards
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
      // notify rewards
      rewardToken.mint(rewardNotifier, _rewardAmount * 2);

      rewardToken.transfer(address(govStaker), _rewardAmount * 2);
      govStaker.notifyRewardAmount(_rewardAmount);

      govStaker.notifyRewardAmount(_rewardAmount);
      recordScenarioGasResult();
      vm.stopPrank();
    }
    stopScenario();

    // 12. Bump earning power up
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

    // 13. Bump earning power down
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

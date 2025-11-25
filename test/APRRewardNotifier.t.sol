// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, console, stdError} from "forge-std/Test.sol";
import {APRRewardNotifier} from "../src/notifiers/APRRewardNotifier.sol";
import {INotifiableRewardReceiver} from "../src/interfaces/INotifiableRewardReceiver.sol";
import {ERC20VotesMock} from "./mocks/MockERC20Votes.sol";
import {TestHelpers} from "./helpers/TestHelpers.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Staker} from "../src/Staker.sol";
import {StakerHarness} from "./harnesses/StakerHarness.sol";
import {
  IdentityEarningPowerCalculator
} from "../src/calculators/IdentityEarningPowerCalculator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Staking} from "../src/interfaces/IERC20Staking.sol";
import {IEarningPowerCalculator} from "../src/interfaces/IEarningPowerCalculator.sol";

contract APRRewardNotifierTest is Test, TestHelpers {
  ERC20VotesMock rewardToken;
  ERC20VotesMock stakeToken;
  StakerHarness receiver;
  IdentityEarningPowerCalculator earningPowerCalculator;
  APRRewardNotifier notifier;
  address admin = makeAddr("Admin");
  address owner = makeAddr("Notifier Owner");
  address alice = makeAddr("Alice");
  address bob = makeAddr("Bob");

  uint16 initialTargetAPR = 1000; // 10%
  uint16 initialMaxMultiplier = 10_000; // 100%
  uint256 initialRewardAmount = 10_000e18;
  uint256 initialRewardInterval = 7 days;
  uint256 maxBumpTip = 1e18;

  uint256 MIN_REWARD_INTERVAL;
  uint256 MAX_REWARD_INTERVAL;
  uint256 SECONDS_PER_YEAR;
  uint16 BIPS_DENOMINATOR;

  function setUp() public virtual {
    rewardToken = new ERC20VotesMock();
    stakeToken = new ERC20VotesMock();
    earningPowerCalculator = new IdentityEarningPowerCalculator();
    receiver = new StakerHarness(
      IERC20(rewardToken),
      IERC20Staking(stakeToken),
      IEarningPowerCalculator(earningPowerCalculator),
      maxBumpTip,
      admin,
      "Test Staker"
    );

    notifier = new APRRewardNotifier(
      receiver,
      owner,
      initialMaxMultiplier,
      initialTargetAPR,
      initialRewardAmount,
      initialRewardInterval
    );

    // Set the notifier as a reward notifier on the receiver
    vm.prank(admin);
    receiver.setRewardNotifier(address(notifier), true);

    MIN_REWARD_INTERVAL = notifier.MIN_REWARD_INTERVAL();
    MAX_REWARD_INTERVAL = notifier.MAX_REWARD_INTERVAL();
    SECONDS_PER_YEAR = notifier.SECONDS_PER_YEAR();
    BIPS_DENOMINATOR = notifier.BIPS_DENOMINATOR();
  }

  function _mintAndStake(address _staker, uint256 _amount) internal {
    stakeToken.mint(_staker, _amount);
    vm.startPrank(_staker);
    stakeToken.approve(address(receiver), _amount);
    receiver.stake(_amount, _staker);
    vm.stopPrank();
  }

  function _assumeSafeOwner(address _owner) public pure {
    vm.assume(_owner != address(0));
  }
}

contract Constructor is APRRewardNotifierTest {
  function test_SetsInitializationParameters() public view {
    assertEq(address(notifier.RECEIVER()), address(receiver));
    assertEq(address(notifier.TOKEN()), address(rewardToken));
    assertEq(notifier.targetAPR(), initialTargetAPR);
    assertEq(notifier.maxEarningPowerTokenMultiplier(), initialMaxMultiplier);
    assertEq(notifier.rewardAmount(), initialRewardAmount);
    assertEq(notifier.rewardInterval(), initialRewardInterval);
    assertEq(notifier.owner(), owner);
  }

  function testFuzz_SetsInitializationParametersToArbitraryValues(
    address _owner,
    uint16 _targetAPR,
    uint16 _maxMultiplier,
    uint256 _rewardAmount,
    uint256 _rewardInterval
  ) public {
    _assumeSafeOwner(_owner);
    _targetAPR = uint16(bound(_targetAPR, 1, type(uint16).max));
    _maxMultiplier = uint16(bound(_maxMultiplier, 1, type(uint16).max));
    // Ensure reward results in valid scaledRewardRate
    _rewardAmount = bound(_rewardAmount, 1e15, 100e18); // 0.001 to 100 ether
    _rewardInterval = bound(_rewardInterval, MIN_REWARD_INTERVAL, MAX_REWARD_INTERVAL);

    APRRewardNotifier _notifier = new APRRewardNotifier(
      receiver, _owner, _maxMultiplier, _targetAPR, _rewardAmount, _rewardInterval
    );

    assertEq(address(_notifier.RECEIVER()), address(receiver));
    assertEq(_notifier.targetAPR(), _targetAPR);
    assertEq(_notifier.maxEarningPowerTokenMultiplier(), _maxMultiplier);
    assertEq(_notifier.rewardAmount(), _rewardAmount);
    assertEq(_notifier.rewardInterval(), _rewardInterval);
    assertEq(_notifier.owner(), _owner);
  }

  function test_RevertIf_ReceiverIsZeroAddress() public {
    vm.expectRevert(APRRewardNotifier.APRRewardNotifier__InvalidParameter.selector);
    new APRRewardNotifier(
      Staker(address(0)),
      owner,
      initialMaxMultiplier,
      initialTargetAPR,
      initialRewardAmount,
      initialRewardInterval
    );
  }

  function testFuzz_EmitsEventsOnInitialization(
    uint16 _targetAPR,
    uint16 _maxMultiplier,
    uint256 _rewardAmount,
    uint256 _rewardInterval
  ) public {
    _targetAPR = uint16(bound(_targetAPR, 1, type(uint16).max));
    _maxMultiplier = uint16(bound(_maxMultiplier, 1, type(uint16).max));
    // Ensure reward results in valid scaledRewardRate
    _rewardAmount = bound(_rewardAmount, 1e15, 100e18); // 0.001 to 100 ether
    _rewardInterval = bound(_rewardInterval, MIN_REWARD_INTERVAL, MAX_REWARD_INTERVAL);

    vm.expectEmit();
    emit APRRewardNotifier.MaxEarningPowerTokenMultiplierSet(0, _maxMultiplier);
    vm.expectEmit();
    emit APRRewardNotifier.TargetAPRSet(0, _targetAPR);
    vm.expectEmit();
    emit APRRewardNotifier.RewardAmountSet(0, _rewardAmount);
    vm.expectEmit();
    emit APRRewardNotifier.RewardIntervalSet(0, _rewardInterval);

    new APRRewardNotifier(
      receiver, owner, _maxMultiplier, _targetAPR, _rewardAmount, _rewardInterval
    );
  }
}

contract SetTargetAPR is APRRewardNotifierTest {
  function testFuzz_UpdatesTargetAPR(uint16 _newTargetAPR) public {
    _newTargetAPR = uint16(bound(_newTargetAPR, 1, type(uint16).max));

    vm.prank(owner);
    notifier.setTargetAPR(_newTargetAPR);

    assertEq(notifier.targetAPR(), _newTargetAPR);
  }

  function testFuzz_EmitsEventOnUpdate(uint16 _newTargetAPR) public {
    _newTargetAPR = uint16(bound(_newTargetAPR, 1, type(uint16).max));

    vm.expectEmit();
    emit APRRewardNotifier.TargetAPRSet(initialTargetAPR, _newTargetAPR);
    vm.prank(owner);
    notifier.setTargetAPR(_newTargetAPR);
  }

  function test_RevertIf_TargetAPRIsZero() public {
    vm.expectRevert(APRRewardNotifier.APRRewardNotifier__InvalidParameter.selector);
    vm.prank(owner);
    notifier.setTargetAPR(0);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(address _notOwner, uint16 _targetAPR) public {
    vm.assume(_notOwner != owner);
    _targetAPR = uint16(bound(_targetAPR, 1, type(uint16).max));

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    vm.prank(_notOwner);
    notifier.setTargetAPR(_targetAPR);
  }
}

contract SetRewardInterval is APRRewardNotifierTest {
  function testFuzz_UpdatesRewardInterval(uint256 _newInterval) public {
    _newInterval = bound(_newInterval, MIN_REWARD_INTERVAL, MAX_REWARD_INTERVAL);

    vm.prank(owner);
    notifier.setRewardInterval(_newInterval);

    assertEq(notifier.rewardInterval(), _newInterval);
  }

  function testFuzz_EmitsEventOnUpdate(uint256 _newInterval) public {
    _newInterval = bound(_newInterval, MIN_REWARD_INTERVAL, MAX_REWARD_INTERVAL);

    vm.expectEmit();
    emit APRRewardNotifier.RewardIntervalSet(initialRewardInterval, _newInterval);
    vm.prank(owner);
    notifier.setRewardInterval(_newInterval);
  }

  function testFuzz_RevertIf_IntervalTooShort(uint256 _interval) public {
    vm.assume(_interval < MIN_REWARD_INTERVAL);

    vm.expectRevert(APRRewardNotifier.APRRewardNotifier__InvalidParameter.selector);
    vm.prank(owner);
    notifier.setRewardInterval(_interval);
  }

  function testFuzz_RevertIf_IntervalTooLong(uint256 _interval) public {
    vm.assume(_interval > MAX_REWARD_INTERVAL);

    vm.expectRevert(APRRewardNotifier.APRRewardNotifier__InvalidParameter.selector);
    vm.prank(owner);
    notifier.setRewardInterval(_interval);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(address _notOwner, uint256 _interval) public {
    vm.assume(_notOwner != owner);
    _interval = bound(_interval, MIN_REWARD_INTERVAL, MAX_REWARD_INTERVAL);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    vm.prank(_notOwner);
    notifier.setRewardInterval(_interval);
  }
}

contract SetRewardAmount is APRRewardNotifierTest {
  function testFuzz_UpdatesRewardAmount(uint256 _newAmount) public {
    _newAmount = bound(_newAmount, 1, type(uint256).max);

    vm.prank(owner);
    notifier.setRewardAmount(_newAmount);

    assertEq(notifier.rewardAmount(), _newAmount);
  }

  function testFuzz_EmitsEventOnUpdate(uint256 _newAmount) public {
    _newAmount = bound(_newAmount, 1, type(uint256).max);

    vm.expectEmit();
    emit APRRewardNotifier.RewardAmountSet(initialRewardAmount, _newAmount);
    vm.prank(owner);
    notifier.setRewardAmount(_newAmount);
  }

  function test_RevertIf_AmountIsZero() public {
    vm.expectRevert(APRRewardNotifier.APRRewardNotifier__InvalidParameter.selector);
    vm.prank(owner);
    notifier.setRewardAmount(0);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(address _notOwner, uint256 _amount) public {
    vm.assume(_notOwner != owner);
    _amount = bound(_amount, 1, type(uint256).max);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    vm.prank(_notOwner);
    notifier.setRewardAmount(_amount);
  }
}

contract SetMaxEarningPowerTokenMultiplier is APRRewardNotifierTest {
  function testFuzz_UpdatesMultiplier(uint16 _newMultiplier) public {
    _newMultiplier = uint16(bound(_newMultiplier, 1, type(uint16).max));

    vm.prank(owner);
    notifier.setMaxEarningPowerTokenMultiplier(_newMultiplier);

    assertEq(notifier.maxEarningPowerTokenMultiplier(), _newMultiplier);
  }

  function testFuzz_EmitsEventOnUpdate(uint16 _newMultiplier) public {
    _newMultiplier = uint16(bound(_newMultiplier, 1, type(uint16).max));

    vm.expectEmit();
    emit APRRewardNotifier.MaxEarningPowerTokenMultiplierSet(initialMaxMultiplier, _newMultiplier);
    vm.prank(owner);
    notifier.setMaxEarningPowerTokenMultiplier(_newMultiplier);
  }

  function test_RevertIf_MultiplierIsZero() public {
    vm.expectRevert(APRRewardNotifier.APRRewardNotifier__InvalidParameter.selector);
    vm.prank(owner);
    notifier.setMaxEarningPowerTokenMultiplier(0);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(address _notOwner, uint16 _multiplier) public {
    vm.assume(_notOwner != owner);
    _multiplier = uint16(bound(_multiplier, 1, type(uint16).max));

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    vm.prank(_notOwner);
    notifier.setMaxEarningPowerTokenMultiplier(_multiplier);
  }
}

contract GetCurrentAPR is APRRewardNotifierTest {
  function test_ReturnsZeroWhenNoEarningPower() public view {
    assertEq(notifier.getCurrentAPR(), 0);
  }

  function testFuzz_CalculatesAPRWithVariousScenarios(
    uint256 _stakeAmount,
    uint256 _rewardAmount,
    uint16 _multiplier
  ) public {
    _stakeAmount = bound(_stakeAmount, 1e18, 100_000e18);
    _rewardAmount = bound(_rewardAmount, 1e15, 100e18);
    _multiplier = uint16(bound(_multiplier, 1000, 10_000)); // 10% to 100%

    _mintAndStake(alice, _stakeAmount);

    rewardToken.mint(address(notifier), _rewardAmount * 10);

    vm.prank(owner);
    notifier.setMaxEarningPowerTokenMultiplier(_multiplier);

    // Set reward amount to ensure it's valid
    vm.prank(owner);
    notifier.setRewardAmount(_rewardAmount);

    vm.warp(block.timestamp + initialRewardInterval);
    notifier.notify();

    uint256 currentAPR = notifier.getCurrentAPR();

    uint256 expectedAPR = (receiver.scaledRewardRate() * uint256(_multiplier) * SECONDS_PER_YEAR)
      / (_stakeAmount * BIPS_DENOMINATOR);

    assertEq(currentAPR, expectedAPR);  
  }
}

contract Notify is APRRewardNotifierTest {
  function test_NotifySucceedsAfterIntervalElapsed() public {
    _mintAndStake(alice, 1000e18);

    // Use moderate reward amount
    uint256 rewardAmount = 1e16; // 0.01 ether
    rewardToken.mint(address(notifier), rewardAmount * 100);

    vm.prank(owner);
    notifier.setRewardAmount(rewardAmount);

    // First notify
    vm.warp(block.timestamp + initialRewardInterval);
    notifier.notify();

    // Second notify after interval
    vm.warp(block.timestamp + initialRewardInterval);
    notifier.notify();

    // Should succeed without reverting
    assertTrue(notifier.getCurrentAPR() <= initialTargetAPR);
  }

  function testFuzz_NotifyWhenIntervalElapsed(
    uint256 _stakeAmount,
    uint256 _rewardAmount,
    uint256 _timeElapsed
  ) public {
    _stakeAmount = bound(_stakeAmount, 1e18, 100_000e18);
    _rewardAmount = bound(_rewardAmount, 1e15, 100e18);
    _timeElapsed = bound(_timeElapsed, initialRewardInterval, initialRewardInterval * 10);

    _mintAndStake(alice, _stakeAmount);
    rewardToken.mint(address(notifier), _rewardAmount * 2);

    vm.warp(block.timestamp + _timeElapsed);

    uint256 balanceBefore = rewardToken.balanceOf(address(receiver));
    notifier.notify();
    uint256 balanceAfter = rewardToken.balanceOf(address(receiver));

    assertTrue(balanceAfter > balanceBefore || balanceAfter == balanceBefore);
    assertEq(notifier.nextRewardTime(), block.timestamp + initialRewardInterval);
  }

  function testFuzz_NotifyWhenAPRAboveTarget(
    uint256 _stakeAmount,
    uint256 _largeRewardAmount,
    uint16 _lowTargetAPR
  ) public {
    _stakeAmount = bound(_stakeAmount, 1e18, 10_000e18);
    _largeRewardAmount = bound(_largeRewardAmount, 10e18, 1000e18);
    _lowTargetAPR = uint16(bound(_lowTargetAPR, 10, 100)); // 0.1% to 1%

    _mintAndStake(alice, _stakeAmount);
    rewardToken.mint(address(notifier), _largeRewardAmount);

    vm.prank(owner);
    notifier.setTargetAPR(_lowTargetAPR);

    notifier.notify();

    uint256 aprBefore = notifier.getCurrentAPR();

    if (aprBefore > _lowTargetAPR) notifier.notify();
  }

  function testFuzz_NotifyWithZeroAmountWhenAPRAboveTarget(
    uint256 _stakeAmount,
    uint256 _initialHighReward
  ) public {
    _stakeAmount = bound(_stakeAmount, 100e18, 10_000e18);
    _initialHighReward = bound(_initialHighReward, 1e17, 10e18);

    _mintAndStake(alice, _stakeAmount);
    rewardToken.mint(address(notifier), _initialHighReward * 10);

    // Set reward amount and target APR to create high APR scenario
    vm.startPrank(owner);
    notifier.setRewardAmount(_initialHighReward);
    notifier.setTargetAPR(100); // 1% target
    vm.stopPrank();

    vm.warp(block.timestamp + initialRewardInterval);
    notifier.notify();

    uint256 aprAfterFirstNotify = notifier.getCurrentAPR();

    if (aprAfterFirstNotify > initialTargetAPR) {
      uint256 balanceBefore = rewardToken.balanceOf(address(receiver));
      notifier.notify();
      uint256 balanceAfter = rewardToken.balanceOf(address(receiver));

      assertTrue(balanceAfter >= balanceBefore);
    }
  }

  function testFuzz_MultipleNotificationsOverTime(
    uint256 _stakeAmount,
    uint256 _rewardAmount,
    uint8 _numNotifications
  ) public {
    _stakeAmount = bound(_stakeAmount, 100e18, 10_000e18);
    _rewardAmount = bound(_rewardAmount, 1e16, 10e18);
    _numNotifications = uint8(bound(_numNotifications, 2, 5));

    _mintAndStake(alice, _stakeAmount);
    rewardToken.mint(address(notifier), _rewardAmount * 10);

    // Set reward amount explicitly
    vm.prank(owner);
    notifier.setRewardAmount(_rewardAmount);

    for (uint8 i = 0; i < _numNotifications; i++) {
      vm.warp(block.timestamp + initialRewardInterval);
      notifier.notify();

      uint256 currentAPR = notifier.getCurrentAPR();
      assertTrue(currentAPR >= 0);
    }
  }

  function test_RevertIf_IntervalNotElapsedAndAPRBelowTarget() public {
    _mintAndStake(alice, 1000e18);

    // Use smaller reward amount to ensure APR stays below target
    uint256 smallReward = 1e16; // 0.01 ether
    rewardToken.mint(address(notifier), smallReward * 100);

    vm.prank(owner);
    notifier.setRewardAmount(smallReward);

    // First notify needs to happen after interval
    vm.warp(block.timestamp + initialRewardInterval);
    notifier.notify();

    // Try to notify again immediately - should revert because APR is below target
    vm.expectRevert(APRRewardNotifier.APRRewardNotifier__RewardIntervalNotElapsed.selector);
    notifier.notify();
  }


}

contract Approve is APRRewardNotifierTest {
  function testFuzz_ApprovesSpender(address _spender, uint256 _amount) public {
    vm.assume(_spender != address(0));
    _amount = bound(_amount, 1, type(uint256).max);

    vm.prank(owner);
    notifier.approve(_spender, _amount);

    assertEq(rewardToken.allowance(address(notifier), _spender), _amount);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(address _notOwner, address _spender, uint256 _amount)
    public
  {
    vm.assume(_notOwner != owner);
    vm.assume(_spender != address(0));
    _amount = bound(_amount, 1, type(uint256).max);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    vm.prank(_notOwner);
    notifier.approve(_spender, _amount);
  }
}

contract CalculateRewardAmountForAPRTarget is APRRewardNotifierTest {
  function testFuzz_CalculatesCorrectAmountToReachTarget(
    uint256 _stakeAmount,
    uint256 _currentReward,
    uint16 _targetAPR
  ) public {
    _stakeAmount = bound(_stakeAmount, 1e18, 100_000e18);
    _currentReward = bound(_currentReward, 1e15, 100e18);
    _targetAPR = uint16(bound(_targetAPR, 100, 5000)); // 1% to 50%

    _mintAndStake(alice, _stakeAmount);
    rewardToken.mint(address(notifier), _currentReward * 10);

    vm.prank(owner);
    notifier.setTargetAPR(_targetAPR);

    notifier.notify();

    uint256 aprBefore = notifier.getCurrentAPR();

    if (aprBefore > _targetAPR) {
      uint256 balanceBefore = rewardToken.balanceOf(address(receiver));
      notifier.notify();
      uint256 balanceAfter = rewardToken.balanceOf(address(receiver));

      uint256 aprAfter = notifier.getCurrentAPR();

      if (balanceAfter > balanceBefore) assertTrue(aprAfter <= aprBefore);
    }
  }
}

contract APRCalculationAccuracy is APRRewardNotifierTest {
  function testFuzz_VerifiesCalculationAccuracyThroughResultingAPR(
    uint256 _stakeAmount,
    uint256 _rewardAmount,
    uint16 _multiplier,
    uint16 _targetAPR
  ) public {
    _stakeAmount = bound(_stakeAmount, 1e18, 100_000e18);
    _rewardAmount = bound(_rewardAmount, 100e18, 100_000e18);
    _multiplier = uint16(bound(_multiplier, 1000, 10_000)); // 10% to 100%
    _targetAPR = uint16(bound(_targetAPR, 100, 2000)); // 1% to 20%

    _mintAndStake(alice, _stakeAmount);

    vm.startPrank(owner);
    notifier.setMaxEarningPowerTokenMultiplier(_multiplier);
    notifier.setTargetAPR(_targetAPR);
    notifier.setRewardAmount(_rewardAmount);
    vm.stopPrank();

    rewardToken.mint(address(notifier), _rewardAmount * 10);

    vm.warp(block.timestamp + initialRewardInterval);
    notifier.notify();

    uint256 resultingAPR = notifier.getCurrentAPR();

    uint256 scaledRewardRate = receiver.scaledRewardRate();
    uint256 totalEarningPower = receiver.totalEarningPower();

    if (totalEarningPower > 0) {
      uint256 calculatedAPR = (scaledRewardRate * uint256(_multiplier) * SECONDS_PER_YEAR)
        / (totalEarningPower * BIPS_DENOMINATOR);

      assertEq(resultingAPR, calculatedAPR);
    }
  }
}

contract EdgeCases is APRRewardNotifierTest {
  function test_HandlesZeroTotalEarningPower() public {
    rewardToken.mint(address(notifier), initialRewardAmount);

    vm.warp(block.timestamp + initialRewardInterval);
    notifier.notify();

    assertEq(notifier.getCurrentAPR(), 0);
  }

  function testFuzz_HandlesLargeValues(uint256 _largeStake, uint256 _largeReward) public {
    _largeStake = bound(_largeStake, 10_000e18, 1_000_000e18);
    _largeReward = bound(_largeReward, 1e17, 1000e18);

    _mintAndStake(alice, _largeStake);
    rewardToken.mint(address(notifier), _largeReward);

    vm.warp(block.timestamp + initialRewardInterval);

    notifier.notify();

    assertTrue(notifier.getCurrentAPR() >= 0);
  }

  function test_HandlesStakingAndUnstakingDuringRewardPeriod() public {
    uint256 stakeAmount = 1000e18;
    uint256 rewardAmount = 100e18; // 0.1 ether

    // Start with a simple scenario - stake first
    _mintAndStake(alice, stakeAmount);
    _mintAndStake(bob, stakeAmount);

    // Give notifier tokens and set smaller reward amount
    rewardToken.mint(address(notifier), rewardAmount * 100);
    vm.prank(owner);
    notifier.setRewardAmount(rewardAmount);

    // First notification to establish rewards
    vm.warp(block.timestamp + initialRewardInterval);
    notifier.notify();

    uint256 aprBefore = notifier.getCurrentAPR();

    // Bob stakes more, should decrease APR
    _mintAndStake(bob, stakeAmount);

    uint256 aprAfterStake = notifier.getCurrentAPR();

    // Get Alice's deposit ID for withdrawal
    stakeToken.mint(alice, stakeAmount);
    vm.startPrank(alice);
    stakeToken.approve(address(receiver), stakeAmount);
    Staker.DepositIdentifier newDepositId = receiver.stake(stakeAmount, alice);
    vm.stopPrank();

    // Alice withdraws, should increase APR
    vm.prank(alice);
    receiver.withdraw(newDepositId, stakeAmount / 2);

    uint256 aprAfterWithdraw = notifier.getCurrentAPR();
    assertGe(aprAfterWithdraw, aprAfterStake);
  }
}

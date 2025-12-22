// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Staking} from "../src/interfaces/IERC20Staking.sol";

import {Staker} from "src/Staker.sol";
import {IdentityEarningPowerCalculator} from "src/calculators/IdentityEarningPowerCalculator.sol";

import {Test, console2} from "forge-std/Test.sol";
import {ERC20VotesMock} from "staker-test/mocks/MockERC20Votes.sol";
import {StakerHarness} from "staker-test/harnesses/StakerHarness.sol";
import {
  APRRewardNotifier,
  APRRewardNotifierHarness
} from "staker-test/harnesses/APRRewardNotifierHarness.sol";

contract APRRewardNotifierTest is Test {
  ERC20VotesMock internal rewardToken;
  ERC20VotesMock internal stakeToken;
  StakerHarness internal receiver;
  APRRewardNotifierHarness internal notifier;
  IdentityEarningPowerCalculator internal calculator;

  uint16 initialTargetAPR = 1000; // 10%
  uint16 initialMaxMultiplier = 10_000; // 100%
  uint256 initialRewardAmount = 10_000e18;
  uint256 initialRewardInterval = 7 days;
  uint256 maxBumpTip = 1e18;
  address admin = makeAddr("Admin");
  address owner = makeAddr("Notifier Owner");
  address alice = makeAddr("Alice");
  address bob = makeAddr("Bob");

  uint256 SECONDS_PER_YEAR;
  uint16 BIPS_DENOMINATOR;

  function setUp() public {
    rewardToken = new ERC20VotesMock();
    stakeToken = new ERC20VotesMock();
    calculator = new IdentityEarningPowerCalculator();
    receiver = new StakerHarness(
      IERC20(rewardToken), IERC20Staking(stakeToken), calculator, maxBumpTip, admin, "Test Staker"
    );
    notifier = new APRRewardNotifierHarness(receiver, rewardToken, initialMaxMultiplier, owner);

    vm.prank(admin);
    receiver.setRewardNotifier(address(notifier), true);

    vm.prank(owner);
    notifier.setTargetAPR(initialTargetAPR);

    SECONDS_PER_YEAR = notifier.SECONDS_PER_YEAR();
    BIPS_DENOMINATOR = notifier.BIPS_DENOMINATOR();
    vm.warp(block.timestamp + 10);
  }

  function _boundMintAmount(uint256 _amount) internal pure returns (uint256) {
    return bound(_amount, 10e12, 10e18);
  }

  function _mintAndStake(address _staker, uint256 _amount)
    internal
    returns (Staker.DepositIdentifier)
  {
    stakeToken.mint(_staker, _amount);
    vm.startPrank(_staker);
    stakeToken.approve(address(receiver), _amount);
    Staker.DepositIdentifier _depositId = receiver.stake(_amount, _staker);
    vm.stopPrank();

    return _depositId;
  }

  function _startExternalRewardStream(uint256 _amount) internal {
    vm.prank(admin);
    receiver.setRewardNotifier(address(this), true);

    rewardToken.mint(address(this), _amount);
    rewardToken.transfer(address(receiver), _amount);
    receiver.notifyRewardAmount(_amount);

    vm.prank(admin);
    receiver.setRewardNotifier(address(this), false);
  }

  function _minRewardAmountForAPR(uint256 _targetAPR) internal view returns (uint256) {
    uint256 totalEarningPower = receiver.totalEarningPower();
    if (totalEarningPower == 0) return 0;
    return (_targetAPR * receiver.REWARD_DURATION() * totalEarningPower * BIPS_DENOMINATOR)
      / (uint256(notifier.maxEarningPowerTokenMultiplier()) * SECONDS_PER_YEAR);
  }

  function _targetRewardAmount() internal view returns (uint256) {
    uint256 _targetScaledRate = notifier.exposed_targetScaledRewardRate();
    return _targetScaledRate * receiver.REWARD_DURATION() / receiver.SCALE_FACTOR();
  }

  function _expectedCurrentAPR() internal view returns (uint256) {
    uint256 totalEarningPower = receiver.totalEarningPower();
    if (totalEarningPower == 0) return 0;

    return (receiver.scaledRewardRate()
        * uint256(notifier.maxEarningPowerTokenMultiplier())
        * SECONDS_PER_YEAR) / (totalEarningPower * BIPS_DENOMINATOR * receiver.SCALE_FACTOR());
  }

  function _assertCurrentAPRMatchesExpectation() internal view returns (uint256) {
    uint256 currentAPR = notifier.exposed_currentScaledAPR();
    assertEq(currentAPR, _expectedCurrentAPR());
    return currentAPR;
  }
}

contract NotifyDecrease is APRRewardNotifierTest {
  function testFuzz_NotifyStakerToDecraseAPR(
    uint256 _amount,
    uint16 _lowTargetAPR,
    uint256 _newTimestamp
  ) public {
    _amount = _boundMintAmount(_amount);
    _newTimestamp =
      bound(_newTimestamp, block.timestamp + 1, block.timestamp + receiver.REWARD_DURATION());
    _lowTargetAPR = uint16(bound(_lowTargetAPR, 1, initialTargetAPR - 2));

    // Alice mint and stake to prop total earning power above 0
    _mintAndStake(alice, _amount);

    // Create external reward stream to artificially prop up APR
    _startExternalRewardStream(_targetRewardAmount());

    // Mint sufficient token for the notifier
    rewardToken.mint(address(notifier), _targetRewardAmount());

    // Artificially lower target APR
    vm.prank(owner);
    notifier.setTargetAPR(_lowTargetAPR);
    uint256 _aprBefore = _assertCurrentAPRMatchesExpectation();
    uint256 _rewardEndTimeBefore = receiver.rewardEndTime();

    // Skip arbitrary amount of time to extend reward duration
    vm.warp(_newTimestamp);

    // Notifier owner calls notify decrease
    vm.prank(owner);
    notifier.notifyDecrease();
    uint256 _aprAfter = _assertCurrentAPRMatchesExpectation();
    uint256 _rewardEndTimeAfter = receiver.rewardEndTime();

    assertEq(_lowTargetAPR, notifier.targetAPR());
    assertGt(_aprBefore, _lowTargetAPR);
    assertGe(_aprBefore, _aprAfter);
    assertLt(_rewardEndTimeBefore, _rewardEndTimeAfter);
  }

  function testFuzz_NotifyDecreaseRecudesInflatedAPRDueToUnstaking(
    uint256 _aliceDeposit,
    uint256 _bobDeposit,
    uint256 _newTimestamp
  ) public {
    // Two token holder stakes
    _aliceDeposit = _boundMintAmount(_aliceDeposit);
    _bobDeposit = bound(_bobDeposit, _aliceDeposit / 100, 10e18);
    _newTimestamp =
      bound(_newTimestamp, block.timestamp + 1, block.timestamp + receiver.REWARD_DURATION());

    _mintAndStake(alice, _aliceDeposit);
    Staker.DepositIdentifier _depositId = _mintAndStake(bob, _bobDeposit);

    // Notify reward such that APR is at initialTargetAPR
    rewardToken.mint(address(notifier), _targetRewardAmount() * 2);
    vm.prank(owner);
    notifier.notifyIncrease();

    // Bob unstakes, total earning power decreases, current APR increases
    vm.prank(bob);
    receiver.withdraw(_depositId, _bobDeposit);
    uint256 _aprBefore = _assertCurrentAPRMatchesExpectation();

    // Skip arbitrary amount of time to extend reward duration
    vm.warp(_newTimestamp);
    vm.prank(owner);
    notifier.notifyDecrease();
    uint256 _aprAfter = _assertCurrentAPRMatchesExpectation();

    assertGt(_aprBefore, initialTargetAPR);
    assertLe(_aprAfter, _aprBefore);
  }

  function testFuzz_EmitsNotified(uint256 _amount, uint16 _lowTargetAPR, uint256 _newTimestamp)
    public
  {
    _amount = _boundMintAmount(_amount);
    _lowTargetAPR = uint16(bound(_lowTargetAPR, 1, initialTargetAPR - 2));
    _newTimestamp =
      bound(_newTimestamp, block.timestamp + 1, block.timestamp + receiver.REWARD_DURATION());

    // Alice stakes and set external reward stream to reach initial target APR
    _mintAndStake(alice, _amount);
    _startExternalRewardStream(_targetRewardAmount());

    // Artificially lower target APR
    vm.prank(owner);
    notifier.setTargetAPR(_lowTargetAPR);

    // Skip arbitrary amount of time to extend reward duration
    vm.warp(_newTimestamp);

    uint256 _targetRewardAmount = _targetRewardAmount();
    uint256 _remainingRewards = notifier.exposed_remainingScaledReward() / receiver.SCALE_FACTOR();
    uint256 _amountToNotify =
      (_targetRewardAmount > _remainingRewards) ? _targetRewardAmount - _remainingRewards : 0;
    uint256 _currentAPR = notifier.exposed_currentScaledAPR();
    rewardToken.mint(address(notifier), _amountToNotify);

    vm.expectEmit();
    emit APRRewardNotifier.Notified(_amountToNotify, _currentAPR);
    vm.prank(owner);
    notifier.notifyDecrease();
  }

  function testFuzz_RevertIf_UnstakeIsTooSmallToMoveBipsAPR(
    uint256 _aliceDeposit,
    uint256 _bobDeposit,
    uint256 _newTimestamp
  ) public {
    // Two token holder stakes, but Bob's stake is so small that unstaking doesn't change APR
    _aliceDeposit = _boundMintAmount(_aliceDeposit);
    _bobDeposit = bound(_bobDeposit, 1, _aliceDeposit / 1000);
    _newTimestamp =
      bound(_newTimestamp, block.timestamp + 1, block.timestamp + receiver.REWARD_DURATION());

    _mintAndStake(alice, _aliceDeposit);
    Staker.DepositIdentifier _depositId = _mintAndStake(bob, _bobDeposit);

    // Notify reward such that APR is at initialTargetAPR
    rewardToken.mint(address(notifier), _targetRewardAmount() * 2);
    vm.prank(owner);
    notifier.notifyIncrease();

    // Bob unstakes, total earning power decreases, current APR remains the same
    vm.prank(bob);
    receiver.withdraw(_depositId, _bobDeposit);

    // Skip arbitrary amount of time to extend reward duration
    vm.warp(_newTimestamp);

    vm.expectRevert(
      abi.encodeWithSelector(APRRewardNotifier.APRRewardNotifier__APROffTarget.selector)
    );
    vm.prank(owner);
    notifier.notifyDecrease();
  }

  function testFuzz_RevertIf_AlreadyBelowTarget(uint256 _amount, uint16 _highTargetAPR) public {
    _amount = _boundMintAmount(_amount);
    _mintAndStake(alice, _amount);
    uint256 _externalReward = _minRewardAmountForAPR(initialTargetAPR);
    _startExternalRewardStream(_externalReward);

    _highTargetAPR = uint16(bound(_highTargetAPR, initialTargetAPR, type(uint16).max));
    vm.prank(owner);
    notifier.setTargetAPR(_highTargetAPR);

    vm.expectRevert(
      abi.encodeWithSelector(APRRewardNotifier.APRRewardNotifier__APROffTarget.selector)
    );
    vm.prank(owner);
    notifier.notifyDecrease();
  }

  function testFuzz_RevertIf_CallerNotNotifierRole(address _caller) public {
    vm.assume(_caller != owner);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, _caller, notifier.NOTIFIER_ROLE()
      )
    );
    vm.prank(_caller);
    notifier.notifyDecrease();
  }
}

contract NotifyIncrease is APRRewardNotifierTest {
  function testFuzz_NotifyStakerToIncraseAPR(uint256 _amount, uint256 _newTimestamp) public {
    _amount = _boundMintAmount(_amount);
    _newTimestamp =
      bound(_newTimestamp, block.timestamp + 1, block.timestamp + receiver.REWARD_DURATION());

    _mintAndStake(alice, 10e18);
    rewardToken.mint(address(notifier), _targetRewardAmount());
    _startExternalRewardStream(_targetRewardAmount());
    uint256 _aprBefore = _assertCurrentAPRMatchesExpectation();

    // Skip arbitrary amount of time to reduce APR
    vm.warp(_newTimestamp);

    vm.prank(owner);
    notifier.notifyIncrease();
    uint256 _aprAfter = _assertCurrentAPRMatchesExpectation();

    assertApproxEqAbs(_aprBefore, notifier.targetAPR(), 1);
    assertLe(_aprAfter, notifier.targetAPR());
    assertLe(_aprBefore, _aprAfter);
  }

  function testFuzz_NotifyIncreaseRaisesAPRDueToStaking(
    uint256 _aliceDeposit,
    uint256 _bobDeposit,
    uint256 _newTimestamp
  ) public {
    // Two token holder stakes, but Bob's stake is so small that unstaking doesn't change APR
    _aliceDeposit = _boundMintAmount(_aliceDeposit);
    _bobDeposit = _boundMintAmount(_aliceDeposit);
    _newTimestamp =
      bound(_newTimestamp, block.timestamp + 1, block.timestamp + receiver.REWARD_DURATION());

    _mintAndStake(alice, _aliceDeposit);
    rewardToken.mint(address(notifier), _targetRewardAmount() * 2);
    _startExternalRewardStream(_targetRewardAmount());
    assertApproxEqAbs(notifier.exposed_currentScaledAPR(), initialTargetAPR, 1);

    // Add new staker, APR is reduced
    _mintAndStake(bob, _bobDeposit);
    uint256 _aprBefore = _assertCurrentAPRMatchesExpectation();

    // Call notify increase to raise APR back to target APR
    vm.prank(owner);
    notifier.notifyIncrease();
    uint256 _aprAfter = _assertCurrentAPRMatchesExpectation();

    assertLt(_aprBefore, initialTargetAPR);
    assertLt(_aprBefore, _aprAfter);
  }

  function test_EmitsNotified(uint256 _amount) public {
    _amount = _boundMintAmount(_amount);
    _mintAndStake(alice, _amount);

    uint256 _targetRewardAmount = _targetRewardAmount();
    rewardToken.mint(address(notifier), _targetRewardAmount);

    uint256 _currentAPR = notifier.exposed_currentScaledAPR();
    uint256 _remainingRewards = notifier.exposed_remainingScaledReward();
    uint256 _amountToNotify =
      (_targetRewardAmount > _remainingRewards) ? _targetRewardAmount - _remainingRewards : 0;

    vm.expectEmit();
    emit APRRewardNotifier.Notified(_amountToNotify, _currentAPR);
    vm.prank(owner);
    notifier.notifyIncrease();
  }

  function testFuzz_RevertIf_AlreadyAboveTarget(uint256 _amount, uint16 _lowTargetAPR) public {
    _amount = _boundMintAmount(_amount);

    _mintAndStake(alice, _amount);
    _startExternalRewardStream(_targetRewardAmount());

    _lowTargetAPR = uint16(bound(_lowTargetAPR, 1, initialTargetAPR - 1));

    vm.prank(owner);
    notifier.setTargetAPR(_lowTargetAPR);

    vm.expectRevert(
      abi.encodeWithSelector(APRRewardNotifier.APRRewardNotifier__APROffTarget.selector)
    );
    vm.prank(owner);
    notifier.notifyIncrease();
  }

  function testFuzz_RevertIf_CallerNotNotifierRole(address _caller) public {
    vm.assume(_caller != owner);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector, _caller, notifier.NOTIFIER_ROLE()
      )
    );
    vm.prank(_caller);
    notifier.notifyIncrease();
  }
}

contract SetMaxEarningPowerTokenMultiplier is APRRewardNotifierTest {
  function testFuzz_UpdatesMasxEarningPowerMultiplier(uint16 _newMultiple) public {
    vm.assume(_newMultiple != 0);

    vm.prank(owner);
    notifier.setMaxEarningPowerTokenMultiplier(_newMultiple);
    assertEq(notifier.maxEarningPowerTokenMultiplier(), _newMultiple);
  }

  function testFuzz_EmitsMaxEarningPowerTokenMultiplierSet(uint16 _newMultiple) public {
    vm.assume(_newMultiple != 0);

    uint16 _oldMultiple = notifier.maxEarningPowerTokenMultiplier();
    vm.expectEmit();
    emit APRRewardNotifier.MaxEarningPowerTokenMultiplierSet(_oldMultiple, _newMultiple);
    vm.prank(owner);
    notifier.setMaxEarningPowerTokenMultiplier(_newMultiple);
  }

  function test_RevertIf_MaxEarningPowerTokenMultiplierIsSetToZero() public {
    vm.expectRevert(
      abi.encodeWithSelector(APRRewardNotifier.APRRewardNotifier__InvalidParameter.selector)
    );
    vm.prank(owner);
    notifier.setMaxEarningPowerTokenMultiplier(0);
  }

  function testFuzz_RevertIf_CallerNotDefaultAdmin(address _caller, uint16 _multiple) public {
    vm.assume(_caller != owner);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        _caller,
        notifier.DEFAULT_ADMIN_ROLE()
      )
    );
    vm.prank(_caller);
    notifier.setMaxEarningPowerTokenMultiplier(_multiple);
  }
}

contract SetTargetAPR is APRRewardNotifierTest {
  function testFuzz_UpdatesTargetAPR(uint16 _newTargetAPR) public {
    vm.assume(_newTargetAPR != 0);

    vm.prank(owner);
    notifier.setTargetAPR(_newTargetAPR);
    assertEq(notifier.targetAPR(), _newTargetAPR);
  }

  function testFuzz_EmitsTargetAPRSet(uint16 _newTargetAPR) public {
    vm.assume(_newTargetAPR != 0);

    uint16 _oldTargetAPR = notifier.targetAPR();
    vm.expectEmit();
    emit APRRewardNotifier.TargetAPRSet(_oldTargetAPR, _newTargetAPR);
    vm.prank(owner);
    notifier.setTargetAPR(_newTargetAPR);
  }

  function test_RevertIf_TargetAPRIsSetToZero() public {
    vm.expectRevert(
      abi.encodeWithSelector(APRRewardNotifier.APRRewardNotifier__InvalidParameter.selector)
    );
    vm.prank(owner);
    notifier.setTargetAPR(0);
  }

  function testFuzz_RevertIf_CallerNotDefaultAdmin(address _caller, uint16 _targetAPR) public {
    vm.assume(_caller != owner);
    vm.expectRevert(
      abi.encodeWithSelector(
        IAccessControl.AccessControlUnauthorizedAccount.selector,
        _caller,
        notifier.DEFAULT_ADMIN_ROLE()
      )
    );
    vm.prank(_caller);
    notifier.setTargetAPR(_targetAPR);
  }
}

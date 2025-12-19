// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Staking} from "../src/interfaces/IERC20Staking.sol";

import {IdentityEarningPowerCalculator} from "src/calculators/IdentityEarningPowerCalculator.sol";

import {Test} from "forge-std/Test.sol";
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

  function _mintAndStake(address _staker, uint256 _amount) internal {
    stakeToken.mint(_staker, _amount);
    vm.startPrank(_staker);
    stakeToken.approve(address(receiver), _amount);
    receiver.stake(_amount, _staker);
    vm.stopPrank();
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
}

contract NotifyDecrease is APRRewardNotifierTest {
  function testFuzz_NotifyStakerToDecraseAPR(uint16 _lowTargetAPR, uint256 _newTimestamp) public {
    _newTimestamp =
      bound(_newTimestamp, block.timestamp, block.timestamp + receiver.REWARD_DURATION());
    _lowTargetAPR = uint16(bound(_lowTargetAPR, 1, initialTargetAPR - 2));

    _mintAndStake(alice, 10e18);
    uint256 _externalReward = _minRewardAmountForAPR(initialTargetAPR);
    _startExternalRewardStream(_externalReward);
    rewardToken.mint(address(notifier), _targetRewardAmount());

    vm.prank(owner);
    notifier.setTargetAPR(_lowTargetAPR);
    uint256 _aprBefore = _assertCurrentAPRMatchesExpectation();

    vm.warp(_newTimestamp);

    vm.prank(owner);
    notifier.notifyDecrease();
    uint256 _aprAfter = _assertCurrentAPRMatchesExpectation();

    assertGt(_aprBefore, notifier.targetAPR());
    assertLe(_aprAfter, _aprBefore);
  }

  function testFuzz_EmitsNotified(uint16 _lowTargetAPR) public {
    _mintAndStake(alice, 10e18);
    uint256 _externalReward = _minRewardAmountForAPR(initialTargetAPR);
    _startExternalRewardStream(_externalReward);

    _lowTargetAPR = uint16(bound(_lowTargetAPR, 1, initialTargetAPR - 2));
    vm.prank(owner);
    notifier.setTargetAPR(_lowTargetAPR);

    uint256 _targetRewardAmount = _targetRewardAmount();
    uint256 _remainingRewards = notifier.exposed_remainingScaledReward();

    uint256 _amountToNotify =
      (_targetRewardAmount > _remainingRewards) ? _targetRewardAmount - _remainingRewards : 0;

    uint256 _currentAPR = notifier.exposed_currentScaledAPR();

    vm.expectEmit();
    emit APRRewardNotifier.Notified(_amountToNotify, _currentAPR);
    vm.prank(owner);
    notifier.notifyDecrease();
  }

  function testFuzz_RevertIf_AlreadyBelowTarget(uint16 _highTargetAPR) public {
    _mintAndStake(alice, 10e18);
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
  function testFuzz_NotifyStakerToIncraseAPR(uint16 _lowTargetAPR, uint256 _newTimestamp) public {
    _lowTargetAPR = uint16(bound(_lowTargetAPR, 1, initialTargetAPR - 2));
    _newTimestamp =
      bound(_newTimestamp, block.timestamp, block.timestamp + receiver.REWARD_DURATION());

    _mintAndStake(alice, 10e18);
    rewardToken.mint(address(notifier), _targetRewardAmount());
    uint256 _externalReward = _minRewardAmountForAPR(_lowTargetAPR);
    _startExternalRewardStream(_externalReward);

    uint256 _aprBefore = _assertCurrentAPRMatchesExpectation();

    vm.warp(_newTimestamp);
    vm.prank(owner);
    notifier.notifyIncrease();

    uint256 _aprAfter = _assertCurrentAPRMatchesExpectation();

    assertLt(_aprBefore, notifier.targetAPR());
    assertLe(_aprAfter, notifier.targetAPR());
    assertGe(_aprAfter, _aprBefore);
  }

  function test_EmitsNotified() public {
    _mintAndStake(alice, 10e18);

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

  function testFuzz_RevertIf_AlreadyAboveTarget(uint256 _externalReward, uint16 _lowTargetAPR)
    public
  {
    _externalReward = bound(_externalReward, 1e20, 1e24);

    _mintAndStake(alice, 10e18);
    _startExternalRewardStream(_externalReward);

    uint256 _currentAPR = notifier.exposed_currentScaledAPR();
    vm.assume(_currentAPR > 0);

    _lowTargetAPR = uint16(bound(_lowTargetAPR, 1, _currentAPR));

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

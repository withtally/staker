// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, console, stdError} from "forge-std/Test.sol";
import {TransferRewardNotifier} from "src/notifiers/TransferRewardNotifier.sol";
import {RewardTokenNotifierBase} from "src/notifiers/RewardTokenNotifierBase.sol";
import {INotifiableRewardReceiver} from "src/interfaces/INotifiableRewardReceiver.sol";
import {MockNotifiableRewardReceiver} from "test/mocks/MockNotifiableRewardReceiver.sol";
import {ERC20VotesMock} from "test/mocks/MockERC20Votes.sol";
import {TestHelpers} from "test/helpers/TestHelpers.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

contract TransferRewardNotifierTest is Test, TestHelpers {
  ERC20VotesMock token;
  MockNotifiableRewardReceiver receiver;
  TransferRewardNotifier notifier;
  address owner = makeAddr("Notifier Owner");

  uint256 initialRewardAmount = 2000e18;
  uint256 initialRewardInterval = 30 days;

  function setUp() public virtual {
    token = new ERC20VotesMock();
    receiver = new MockNotifiableRewardReceiver(token);
    notifier =
      new TransferRewardNotifier(receiver, initialRewardAmount, initialRewardInterval, owner);
  }

  function _assumeSafeOwner(address _owner) public pure {
    vm.assume(_owner != address(0));
  }

  function _mintToken(address _to, uint256 _amount) public {
    token.mint(_to, _amount);
  }
}

contract Constructor is TransferRewardNotifierTest {
  function test_SetsInitializationParameters() public view {
    assertEq(address(notifier.RECEIVER()), address(receiver));
    assertEq(address(notifier.TOKEN()), address(token));
    assertEq(notifier.rewardAmount(), initialRewardAmount);
    assertEq(notifier.rewardInterval(), initialRewardInterval);
    assertEq(notifier.owner(), owner);
  }

  function testFuzz_SetsInitializationParametersToArbitraryValues(
    address _receiver,
    address _token,
    uint256 _initialRewardAmount,
    uint256 _initialRewardInterval,
    address _owner
  ) public {
    _assumeSafeOwner(_owner);
    _assumeSafeMockAddress(_receiver);
    vm.mockCall(
      _receiver,
      abi.encodeWithSelector(INotifiableRewardReceiver.REWARD_TOKEN.selector),
      abi.encode(_token)
    );

    TransferRewardNotifier _notifier = new TransferRewardNotifier(
      INotifiableRewardReceiver(_receiver), _initialRewardAmount, _initialRewardInterval, _owner
    );

    assertEq(address(_notifier.RECEIVER()), _receiver);
    assertEq(address(_notifier.TOKEN()), _token);
    assertEq(_notifier.rewardAmount(), _initialRewardAmount);
    assertEq(_notifier.rewardInterval(), _initialRewardInterval);
    assertEq(_notifier.owner(), _owner);
  }

  function testFuzz_EmitsAnEventForSettingTheRewardAmount(uint256 _initialRewardAmount) public {
    vm.expectEmit();
    emit RewardTokenNotifierBase.RewardAmountSet(0, _initialRewardAmount);
    new TransferRewardNotifier(receiver, _initialRewardAmount, initialRewardInterval, owner);
  }

  function testFuzz_EmitsAnEventForSettingTheRewardInterval(uint256 _initialRewardInterval) public {
    vm.expectEmit();
    emit RewardTokenNotifierBase.RewardIntervalSet(0, _initialRewardInterval);
    new TransferRewardNotifier(receiver, initialRewardAmount, _initialRewardInterval, owner);
  }
}

contract Notify is TransferRewardNotifierTest {
  function testFuzz_SendsTheRewardTokenToTheReceiver(address _caller, uint256 _notifierBalance)
    public
  {
    _notifierBalance = bound(_notifierBalance, notifier.rewardAmount(), type(uint256).max);
    _mintToken(address(notifier), _notifierBalance);

    vm.prank(_caller);
    notifier.notify();

    assertEq(token.balanceOf(address(notifier)), _notifierBalance - notifier.rewardAmount());
    assertEq(token.balanceOf(address(receiver)), notifier.rewardAmount());
  }

  function testFuzz_CallsNotifyRewardAmountOnTheReceiver(address _caller) public {
    _mintToken(address(notifier), notifier.rewardAmount());

    vm.prank(_caller);
    notifier.notify();

    assertEq(receiver.lastParam_notifyRewardAmount_amount(), notifier.rewardAmount());
  }

  function testFuzz_UpdatesTheNextTimeARewardIsAvailable(address _caller) public {
    uint256 _rewardAmount = notifier.rewardAmount();
    uint256 _rewardInterval = notifier.rewardInterval();

    _mintToken(address(notifier), _rewardAmount);

    uint256 _expectedTime = block.timestamp + _rewardInterval;

    vm.prank(_caller);
    notifier.notify();

    assertEq(notifier.nextRewardTime(), _expectedTime);
  }

  function testFuzz_EmitsANotifiedEvent(address _caller) public {
    uint256 _rewardAmount = notifier.rewardAmount();
    uint256 _rewardInterval = notifier.rewardInterval();

    _mintToken(address(notifier), _rewardAmount);

    vm.prank(_caller);
    vm.expectEmit();
    emit RewardTokenNotifierBase.Notified(_rewardAmount, block.timestamp + _rewardInterval);
    notifier.notify();
  }

  function testFuzz_RevertIf_TheRewardIntervalHasNotElapsedSinceTheLastTimeNotifyWasCalled(
    address _caller,
    uint256 _elapsedTime
  ) public {
    uint256 _rewardAmount = notifier.rewardAmount();
    uint256 _rewardInterval = notifier.rewardInterval();

    _elapsedTime = bound(_elapsedTime, 0, _rewardInterval - 1);
    _mintToken(address(notifier), 2 * _rewardAmount);

    // the first reward distribution occurs
    vm.prank(_caller);
    notifier.notify();
    // time elapses, but less than the reward interval
    skip(_elapsedTime);

    vm.prank(_caller);
    vm.expectRevert(
      RewardTokenNotifierBase.RewardTokenNotifierBase__RewardIntervalNotElapsed.selector
    );
    notifier.notify();
  }

  function testFuzz_DistributesAdditionalRewardsAfterTheIntervalElapses(
    address _caller,
    uint256 _elapsedTime
  ) public {
    uint256 _rewardAmount = notifier.rewardAmount();
    uint256 _rewardInterval = notifier.rewardInterval();

    _elapsedTime = bound(_elapsedTime, _rewardInterval, _rewardInterval + 52 weeks);
    _mintToken(address(notifier), 2 * _rewardAmount);

    // the first reward distribution occurs
    vm.prank(_caller);
    notifier.notify();
    // a time of at least the reward interval elapses
    skip(_elapsedTime);

    vm.prank(_caller);
    notifier.notify();

    assertEq(token.balanceOf(address(notifier)), 0);
    assertEq(token.balanceOf(address(receiver)), 2 * _rewardAmount);
    assertEq(notifier.nextRewardTime(), block.timestamp + _rewardInterval);
  }

  function testFuzz_DistributesRewardsProperlyAsTimeElapsesAndParametersAreChanged(
    address _caller,
    uint256 _interval,
    uint256 _amount,
    uint256 _extraTime,
    uint256 _extraAmount
  ) public {
    uint256 _receiverLastBalance;

    // repeatedly update parameters and perform notifications ensuring the notifier behaves as
    // expected
    for (uint256 _reps = 50; _reps > 0; _reps--) {
      // bound and label values
      _amount = bound(_amount, 1, 10_000_000_000e18);
      _extraAmount = bound(_extraAmount, 0, 1_000_000e18);
      _interval = bound(_interval, 1 minutes, 520 weeks);
      _extraTime = bound(_extraTime, 0, 1 days);
      vm.label(_caller, "Caller");

      // mint token and perform approval
      _mintToken(address(notifier), _amount + _extraAmount);

      // perform admin updates to the new values
      vm.startPrank(owner);
      notifier.setRewardInterval(_interval);
      notifier.setRewardAmount(_amount);
      vm.stopPrank();

      // jump to a time after the last reward interval has elapsed
      vm.warp(notifier.nextRewardTime() + _extraTime);
      vm.prank(_caller);
      notifier.notify();

      // ensure token transfers and updates have occurred as expected
      assertEq(token.balanceOf(address(receiver)), _receiverLastBalance + _amount);
      assertEq(token.balanceOf(address(receiver)), _receiverLastBalance + _amount);
      assertEq(notifier.nextRewardTime(), block.timestamp + _interval);
      assertEq(receiver.lastParam_notifyRewardAmount_amount(), _amount);

      // remember the receiver's balance
      _receiverLastBalance = token.balanceOf(address(receiver));

      // reset all the values for the next iteration
      _caller = address(uint160(uint256(keccak256(abi.encode(_caller)))));
      _amount = uint256(keccak256(abi.encode(_amount)));
      _extraAmount = uint256(keccak256(abi.encode(_extraAmount)));
      _interval = uint256(keccak256(abi.encode(_interval)));
      _extraTime = uint256(keccak256(abi.encode(_extraTime)));
    }
  }
}

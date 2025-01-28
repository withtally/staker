// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, console, stdError} from "forge-std/Test.sol";
import {MintRewardNotifier, IMintable} from "src/notifiers/MintRewardNotifier.sol";
import {RewardTokenNotifierBase} from "src/notifiers/RewardTokenNotifierBase.sol";
import {INotifiableRewardReceiver} from "src/interfaces/INotifiableRewardReceiver.sol";
import {MockNotifiableRewardReceiver} from "test/mocks/MockNotifiableRewardReceiver.sol";
import {ERC20VotesMock} from "test/mocks/MockERC20Votes.sol";
import {FakeMinter} from "test/fakes/FakeMinter.sol";
import {TestHelpers} from "test/helpers/TestHelpers.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

contract MintRewardNotifierTest is Test, TestHelpers {
  ERC20VotesMock token;
  MockNotifiableRewardReceiver receiver;
  MintRewardNotifier notifier;
  address owner = makeAddr("Notifier Owner");

  uint256 initialRewardAmount = 2000e18;
  uint256 initialRewardInterval = 30 days;

  uint256 MIN_REWARD_INTERVAL;
  uint256 MAX_REWARD_INTERVAL;

  function setUp() public virtual {
    token = new ERC20VotesMock();
    receiver = new MockNotifiableRewardReceiver(token);
    notifier =
      new MintRewardNotifier(receiver, initialRewardAmount, initialRewardInterval, owner, token);

    // cache these in tests for convenience
    MIN_REWARD_INTERVAL = notifier.MIN_REWARD_INTERVAL();
    MAX_REWARD_INTERVAL = notifier.MAX_REWARD_INTERVAL();
  }

  function _assumeSafeOwner(address _owner) public pure {
    vm.assume(_owner != address(0));
  }
}

contract Constructor is MintRewardNotifierTest {
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
    address _owner,
    IMintable _initialMinter
  ) public {
    _assumeSafeOwner(_owner);
    _assumeSafeMockAddress(_receiver);
    _initialRewardAmount = bound(_initialRewardAmount, 1, type(uint256).max);
    _initialRewardInterval = bound(_initialRewardInterval, MIN_REWARD_INTERVAL, MAX_REWARD_INTERVAL);
    vm.mockCall(
      _receiver,
      abi.encodeWithSelector(INotifiableRewardReceiver.REWARD_TOKEN.selector),
      abi.encode(_token)
    );

    MintRewardNotifier _notifier = new MintRewardNotifier(
      INotifiableRewardReceiver(_receiver),
      _initialRewardAmount,
      _initialRewardInterval,
      _owner,
      _initialMinter
    );

    assertEq(address(_notifier.RECEIVER()), _receiver);
    assertEq(address(_notifier.TOKEN()), _token);
    assertEq(_notifier.rewardAmount(), _initialRewardAmount);
    assertEq(_notifier.rewardInterval(), _initialRewardInterval);
    assertEq(_notifier.owner(), _owner);
    assertEq(address(_notifier.minter()), address(_initialMinter));
  }

  function testFuzz_EmitsAnEventForSettingTheRewardAmount(uint256 _initialRewardAmount) public {
    _initialRewardAmount = bound(_initialRewardAmount, 1, type(uint256).max);

    vm.expectEmit();
    emit RewardTokenNotifierBase.RewardAmountSet(0, _initialRewardAmount);
    new MintRewardNotifier(receiver, _initialRewardAmount, initialRewardInterval, owner, token);
  }

  function testFuzz_EmitsAnEventForSettingTheRewardInterval(uint256 _initialRewardInterval) public {
    _initialRewardInterval = bound(_initialRewardInterval, MIN_REWARD_INTERVAL, MAX_REWARD_INTERVAL);

    vm.expectEmit();
    emit RewardTokenNotifierBase.RewardIntervalSet(0, _initialRewardInterval);
    new MintRewardNotifier(receiver, initialRewardAmount, _initialRewardInterval, owner, token);
  }

  function testFuzz_EmitsAnEventForSettingTheMinter(IMintable _minter) public {
    vm.expectEmit();
    emit MintRewardNotifier.MinterSet(IMintable(address(0)), _minter);
    new MintRewardNotifier(receiver, initialRewardAmount, initialRewardInterval, owner, _minter);
  }
}

contract SetMinter is MintRewardNotifierTest {
  function testFuzz_UpdatesTheMinter(IMintable _newMinter) public {
    vm.prank(owner);
    notifier.setMinter(_newMinter);

    assertEq(address(notifier.minter()), address(_newMinter));
  }

  function testFuzz_EmitsAnEventForSettingTheMinter(IMintable _newMinter) public {
    vm.expectEmit();
    emit MintRewardNotifier.MinterSet(token, _newMinter);
    vm.prank(owner);
    notifier.setMinter(_newMinter);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(IMintable _newMinter, address _notOwner) public {
    vm.assume(_notOwner != owner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    vm.prank(_notOwner);
    notifier.setMinter(_newMinter);
  }
}

contract Notify is MintRewardNotifierTest {
  function testFuzz_MintsTheRewardTokenToTheReceiver(address _caller) public {
    vm.prank(_caller);
    notifier.notify();

    assertEq(token.balanceOf(address(receiver)), notifier.rewardAmount());
  }

  function testFuzz_CallsNotifyRewardAmountOnTheReceiver(address _caller) public {
    vm.prank(_caller);
    notifier.notify();

    assertEq(receiver.lastParam_notifyRewardAmount_amount(), notifier.rewardAmount());
  }

  function testFuzz_UpdatesTheNextTimeARewardIsAvailable(address _caller) public {
    uint256 _rewardInterval = notifier.rewardInterval();

    uint256 _expectedTime = block.timestamp + _rewardInterval;

    vm.prank(_caller);
    notifier.notify();

    assertEq(notifier.nextRewardTime(), _expectedTime);
  }

  function testFuzz_EmitsANotifiedEvent(address _caller) public {
    uint256 _rewardAmount = notifier.rewardAmount();
    uint256 _rewardInterval = notifier.rewardInterval();

    vm.prank(_caller);
    vm.expectEmit();
    emit RewardTokenNotifierBase.Notified(_rewardAmount, block.timestamp + _rewardInterval);
    notifier.notify();
  }

  function testFuzz_RevertIf_TheRewardIntervalHasNotElapsedSinceTheLastTimeNotifyWasCalled(
    address _caller,
    uint256 _elapsedTime
  ) public {
    uint256 _rewardInterval = notifier.rewardInterval();

    _elapsedTime = bound(_elapsedTime, 0, _rewardInterval - 1);

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

    // the first reward distribution occurs
    vm.prank(_caller);
    notifier.notify();
    // a time of at least the reward interval elapses
    skip(_elapsedTime);

    vm.prank(_caller);
    notifier.notify();

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
    // For the first iteration, the minter is token, i.e. direct minting
    IMintable _minter = token;

    // repeatedly update parameters and perform notifications ensuring the notifier behaves as
    // expected
    for (uint256 _reps = 50; _reps > 0; _reps--) {
      // bound and label values
      _amount = bound(_amount, 1, 10_000_000_000e18);
      _extraAmount = bound(_extraAmount, 0, 1_000_000e18);
      _interval = bound(_interval, MIN_REWARD_INTERVAL, MAX_REWARD_INTERVAL);
      _extraTime = bound(_extraTime, 0, 1 days);
      vm.label(_caller, "Caller");

      // perform admin updates to the new values
      vm.startPrank(owner);
      notifier.setRewardInterval(_interval);
      notifier.setRewardAmount(_amount);
      notifier.setMinter(_minter);
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
      // we deploy a new sub-minter contract, i.e. for DAOs that used "capped minters" or similar
      // shim constructs to enable others to mint within certain parameters.
      _minter = new FakeMinter(token);
    }
  }
}

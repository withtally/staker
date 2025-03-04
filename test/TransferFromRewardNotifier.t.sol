// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, stdError} from "forge-std/Test.sol";
import {TransferFromRewardNotifier} from "../src/notifiers/TransferFromRewardNotifier.sol";
import {RewardTokenNotifierBase} from "../src/notifiers/RewardTokenNotifierBase.sol";
import {INotifiableRewardReceiver} from "../src/interfaces/INotifiableRewardReceiver.sol";
import {MockNotifiableRewardReceiver} from "./mocks/MockNotifiableRewardReceiver.sol";
import {ERC20VotesMock} from "./mocks/MockERC20Votes.sol";
import {TestHelpers} from "./helpers/TestHelpers.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TransferFromRewardNotifierTest is Test, TestHelpers {
  ERC20VotesMock token;
  MockNotifiableRewardReceiver receiver;
  TransferFromRewardNotifier notifier;
  address owner = makeAddr("Notifier Owner");
  address source = makeAddr("Reward Source");

  uint256 initialRewardAmount = 2000e18;
  uint256 initialRewardInterval = 30 days;

  uint256 MIN_REWARD_INTERVAL;
  uint256 MAX_REWARD_INTERVAL;

  function setUp() public virtual {
    token = new ERC20VotesMock();
    receiver = new MockNotifiableRewardReceiver(token);
    notifier = new TransferFromRewardNotifier(
      receiver, initialRewardAmount, initialRewardInterval, owner, source
    );
    // cache these in tests for convenience
    MIN_REWARD_INTERVAL = notifier.MIN_REWARD_INTERVAL();
    MAX_REWARD_INTERVAL = notifier.MAX_REWARD_INTERVAL();
  }

  function _assumeSafeOwner(address _owner) public pure {
    vm.assume(_owner != address(0));
  }

  function _mintToken(address _to, uint256 _amount) public {
    token.mint(_to, _amount);
  }

  function _approveNotifier(address _source, uint256 _amount) public {
    vm.prank(_source);
    token.approve(address(notifier), _amount);
  }
}

contract Constructor is TransferFromRewardNotifierTest {
  function test_SetsInitializationParameters() public view {
    assertEq(address(notifier.RECEIVER()), address(receiver));
    assertEq(address(notifier.TOKEN()), address(token));
    assertEq(notifier.rewardAmount(), initialRewardAmount);
    assertEq(notifier.rewardInterval(), initialRewardInterval);
    assertEq(notifier.rewardSource(), source);
    assertEq(notifier.owner(), owner);
  }

  function testFuzz_SetsInitializationParametersToArbitraryValues(
    address _receiver,
    address _token,
    uint256 _initialRewardAmount,
    uint256 _initialRewardInterval,
    address _initialRewardSource,
    address _owner
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

    TransferFromRewardNotifier _notifier = new TransferFromRewardNotifier(
      INotifiableRewardReceiver(_receiver),
      _initialRewardAmount,
      _initialRewardInterval,
      _owner,
      _initialRewardSource
    );

    assertEq(address(_notifier.RECEIVER()), _receiver);
    assertEq(address(_notifier.TOKEN()), _token);
    assertEq(_notifier.rewardAmount(), _initialRewardAmount);
    assertEq(_notifier.rewardInterval(), _initialRewardInterval);
    assertEq(_notifier.rewardSource(), _initialRewardSource);
    assertEq(_notifier.owner(), _owner);
  }

  function testFuzz_EmitsAnEventForSettingTheRewardAmount(uint256 _initialRewardAmount) public {
    _initialRewardAmount = bound(_initialRewardAmount, 1, type(uint256).max);

    vm.expectEmit();
    emit RewardTokenNotifierBase.RewardAmountSet(0, _initialRewardAmount);
    new TransferFromRewardNotifier(
      receiver, _initialRewardAmount, initialRewardInterval, owner, source
    );
  }

  function testFuzz_EmitsAnEventForSettingTheRewardInterval(uint256 _initialRewardInterval) public {
    _initialRewardInterval = bound(_initialRewardInterval, MIN_REWARD_INTERVAL, MAX_REWARD_INTERVAL);
    emit RewardTokenNotifierBase.RewardIntervalSet(0, _initialRewardInterval);
    new TransferFromRewardNotifier(
      receiver, initialRewardAmount, _initialRewardInterval, owner, source
    );
  }

  function testFuzz_EmitsAnEventForSettingTheRewardSource(address _initialRewardSource) public {
    vm.expectEmit();
    emit TransferFromRewardNotifier.RewardSourceSet(address(0), _initialRewardSource);
    new TransferFromRewardNotifier(
      receiver, initialRewardAmount, initialRewardInterval, owner, _initialRewardSource
    );
  }

  function testFuzz_RevertIf_InitialRewardIntervalIsShorterThanTheMinInterval(
    uint256 _initialRewardInterval
  ) public {
    _initialRewardInterval = bound(_initialRewardInterval, 0, MIN_REWARD_INTERVAL - 1);

    vm.expectRevert(RewardTokenNotifierBase.RewardTokenNotifierBase__InvalidParameter.selector);
    new TransferFromRewardNotifier(
      INotifiableRewardReceiver(receiver),
      initialRewardAmount,
      _initialRewardInterval,
      owner,
      source
    );
  }

  function testFuzz_RevertIf_InitialRewardIntervalIsLongerThanTheMaxInterval(
    uint256 _initialRewardInterval
  ) public {
    _initialRewardInterval =
      bound(_initialRewardInterval, MAX_REWARD_INTERVAL + 1, type(uint256).max);

    vm.expectRevert(RewardTokenNotifierBase.RewardTokenNotifierBase__InvalidParameter.selector);
    new TransferFromRewardNotifier(
      INotifiableRewardReceiver(receiver),
      initialRewardAmount,
      _initialRewardInterval,
      owner,
      source
    );
  }

  function test_RevertIf_InitialRewardRewardAmountIsZero() public {
    vm.expectRevert(RewardTokenNotifierBase.RewardTokenNotifierBase__InvalidParameter.selector);
    new TransferFromRewardNotifier(
      INotifiableRewardReceiver(receiver), 0, initialRewardInterval, owner, source
    );
  }
}

contract SetRewardAmount is TransferFromRewardNotifierTest {
  function testFuzz_UpdatesTheRewardAmount(uint256 _newRewardAmount) public {
    _newRewardAmount = bound(_newRewardAmount, 1, type(uint256).max);

    vm.prank(owner);
    notifier.setRewardAmount(_newRewardAmount);

    assertEq(notifier.rewardAmount(), _newRewardAmount);
  }

  function testFuzz_EmitsAnEventForSettingTheRewardAmount(uint256 _newRewardAmount) public {
    _newRewardAmount = bound(_newRewardAmount, 1, type(uint256).max);

    vm.expectEmit();
    emit RewardTokenNotifierBase.RewardAmountSet(initialRewardAmount, _newRewardAmount);
    vm.prank(owner);
    notifier.setRewardAmount(_newRewardAmount);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(uint256 _newRewardAmount, address _notOwner) public {
    _newRewardAmount = bound(_newRewardAmount, 1, type(uint256).max);
    vm.assume(_notOwner != owner);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    vm.prank(_notOwner);
    notifier.setRewardAmount(_newRewardAmount);
  }

  function test_RevertIf_NewRewardAmountIsZero() public {
    vm.expectRevert(RewardTokenNotifierBase.RewardTokenNotifierBase__InvalidParameter.selector);
    vm.prank(owner);
    notifier.setRewardAmount(0);
  }
}

contract SetRewardInterval is TransferFromRewardNotifierTest {
  function testFuzz_UpdatesTheRewardInterval(uint256 _newRewardInterval) public {
    _newRewardInterval = bound(_newRewardInterval, MIN_REWARD_INTERVAL, MAX_REWARD_INTERVAL);

    vm.prank(owner);
    notifier.setRewardInterval(_newRewardInterval);

    assertEq(notifier.rewardInterval(), _newRewardInterval);
  }

  function testFuzz_EmitsAnEventForSettingTheRewardInterval(uint256 _newRewardInterval) public {
    _newRewardInterval = bound(_newRewardInterval, MIN_REWARD_INTERVAL, MAX_REWARD_INTERVAL);

    vm.expectEmit();
    emit RewardTokenNotifierBase.RewardIntervalSet(initialRewardInterval, _newRewardInterval);
    vm.prank(owner);
    notifier.setRewardInterval(_newRewardInterval);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(uint256 _newRewardInterval, address _notOwner) public {
    vm.assume(_notOwner != owner);
    _newRewardInterval = bound(_newRewardInterval, MIN_REWARD_INTERVAL, MAX_REWARD_INTERVAL);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    vm.prank(_notOwner);
    notifier.setRewardInterval(_newRewardInterval);
  }

  function testFuzz_RevertIf_NewIntervalIsShorterThanTheMinInterval(uint256 _newRewardInterval)
    public
  {
    _newRewardInterval = bound(_newRewardInterval, 0, MIN_REWARD_INTERVAL - 1);

    vm.prank(owner);
    vm.expectRevert(RewardTokenNotifierBase.RewardTokenNotifierBase__InvalidParameter.selector);
    notifier.setRewardInterval(_newRewardInterval);
  }

  function testFuzz_RevertIf_NewIntervalIsLongerThanTheMaxInterval(uint256 _newRewardInterval)
    public
  {
    _newRewardInterval = bound(_newRewardInterval, MAX_REWARD_INTERVAL + 1, type(uint256).max);

    vm.prank(owner);
    vm.expectRevert(RewardTokenNotifierBase.RewardTokenNotifierBase__InvalidParameter.selector);
    notifier.setRewardInterval(_newRewardInterval);
  }
}

contract SetRewardSource is TransferFromRewardNotifierTest {
  function testFuzz_UpdatesTheRewardSource(address _newRewardSource) public {
    vm.prank(owner);
    notifier.setRewardSource(_newRewardSource);

    assertEq(notifier.rewardSource(), _newRewardSource);
  }

  function testFuzz_EmitsAnEventForSettingTheRewardSource(address _newRewardSource) public {
    vm.expectEmit();
    emit TransferFromRewardNotifier.RewardSourceSet(source, _newRewardSource);
    vm.prank(owner);
    notifier.setRewardSource(_newRewardSource);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(address _newRewardSource, address _notOwner) public {
    vm.assume(_notOwner != owner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    vm.prank(_notOwner);
    notifier.setRewardSource(_newRewardSource);
  }
}

contract Notify is TransferFromRewardNotifierTest {
  function testFuzz_MovesTheRewardTokenAmountFromSourceToReceiver(
    address _caller,
    uint256 _sourceBalance
  ) public {
    _sourceBalance = bound(_sourceBalance, notifier.rewardAmount(), type(uint256).max);
    _mintToken(source, _sourceBalance);
    _approveNotifier(source, notifier.rewardAmount());

    vm.prank(_caller);
    notifier.notify();

    assertEq(token.balanceOf(source), _sourceBalance - notifier.rewardAmount());
    assertEq(token.balanceOf(address(receiver)), notifier.rewardAmount());
  }

  function testFuzz_CallsNotifyRewardAmountOnTheReceiver(address _caller) public {
    _mintToken(source, notifier.rewardAmount());
    _approveNotifier(source, notifier.rewardAmount());

    vm.prank(_caller);
    notifier.notify();

    assertEq(receiver.lastParam_notifyRewardAmount_amount(), notifier.rewardAmount());
  }

  function testFuzz_UpdatesTheNextTimeARewardIsAvailable(address _caller) public {
    uint256 _rewardAmount = notifier.rewardAmount();
    uint256 _rewardInterval = notifier.rewardInterval();

    _mintToken(source, _rewardAmount);
    _approveNotifier(source, _rewardAmount);

    uint256 _expectedTime = block.timestamp + _rewardInterval;

    vm.prank(_caller);
    notifier.notify();

    assertEq(notifier.nextRewardTime(), _expectedTime);
  }

  function testFuzz_EmitsANotifiedEvent(address _caller) public {
    uint256 _rewardAmount = notifier.rewardAmount();
    uint256 _rewardInterval = notifier.rewardInterval();

    _mintToken(source, _rewardAmount);
    _approveNotifier(source, _rewardAmount);

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
    _mintToken(source, 2 * _rewardAmount);
    _approveNotifier(source, 2 * _rewardAmount);

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
    _mintToken(source, 2 * _rewardAmount);
    _approveNotifier(source, 2 * _rewardAmount);

    // the first reward distribution occurs
    vm.prank(_caller);
    notifier.notify();
    // a time of at least the reward interval elapses
    skip(_elapsedTime);

    vm.prank(_caller);
    notifier.notify();

    assertEq(token.balanceOf(source), 0);
    assertEq(token.balanceOf(address(receiver)), 2 * _rewardAmount);
    assertEq(notifier.nextRewardTime(), block.timestamp + _rewardInterval);
  }

  function testFuzz_DistributesRewardsProperlyAsTimeElapsesAndParametersAreChanged(
    address _caller,
    address _source,
    uint256 _interval,
    uint256 _amount,
    uint256 _extraTime,
    uint256 _extraAmount
  ) public {
    vm.assume(_source != address(0) && _source != address(receiver));
    uint256 _receiverLastBalance;

    // repeatedly update parameters and perform notifications ensuring the notifier behaves as
    // expected
    for (uint256 _reps = 50; _reps > 0; _reps--) {
      // bound and label values
      _amount = bound(_amount, 1, 10_000_000_000e18);
      _extraAmount = bound(_extraAmount, 0, 1_000_000e18);
      _interval = bound(_interval, MIN_REWARD_INTERVAL, MAX_REWARD_INTERVAL);
      _extraTime = bound(_extraTime, 0, 1 days);
      vm.label(_source, "Source");
      vm.label(_caller, "Caller");

      // mint token and perform approval
      _mintToken(_source, _amount + _extraAmount);
      _approveNotifier(_source, _amount);

      // perform admin updates to the new values
      vm.startPrank(owner);
      notifier.setRewardInterval(_interval);
      notifier.setRewardSource(_source);
      notifier.setRewardAmount(_amount);
      vm.stopPrank();

      // jump to a time after the last reward interval has elapsed
      vm.warp(notifier.nextRewardTime() + _extraTime);
      vm.prank(_caller);
      notifier.notify();

      // ensure token transfers and updates have occurred as expected
      assertEq(token.balanceOf(address(receiver)), _receiverLastBalance + _amount);
      assertEq(token.balanceOf(_source), _extraAmount);
      assertEq(token.balanceOf(address(receiver)), _receiverLastBalance + _amount);
      assertEq(notifier.nextRewardTime(), block.timestamp + _interval);
      assertEq(receiver.lastParam_notifyRewardAmount_amount(), _amount);

      // remember the receiver's balance
      _receiverLastBalance = token.balanceOf(address(receiver));

      // reset all the values for the next iteration
      _source = address(uint160(uint256(keccak256(abi.encode(_source)))));
      _caller = address(uint160(uint256(keccak256(abi.encode(_caller)))));
      _amount = uint256(keccak256(abi.encode(_amount)));
      _extraAmount = uint256(keccak256(abi.encode(_extraAmount)));
      _interval = uint256(keccak256(abi.encode(_interval)));
      _extraTime = uint256(keccak256(abi.encode(_extraTime)));
    }
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, stdError} from "forge-std/Test.sol";
import {TransferFromRewardNotifier, Ownable} from "src/TransferFromRewardNotifier.sol";
import {INotifiableRewardReceiver} from "src/interfaces/INotifiableRewardReceiver.sol";
import {MockNotifiableRewardReceiver} from "test/mocks/MockNotifiableRewardReceiver.sol";
import {ERC20VotesMock} from "test/mocks/MockERC20Votes.sol";

contract TransferFromRewardNotifierTest is Test {
  ERC20VotesMock token;
  MockNotifiableRewardReceiver receiver;
  TransferFromRewardNotifier notifier;
  address owner = makeAddr("Notifier Owner");
  address source = makeAddr("Reward Source");

  uint256 initialRewardAmount = 2000e18;
  uint256 initialRewardInterval = 30 days;

  function setUp() public virtual {
    token = new ERC20VotesMock();
    receiver = new MockNotifiableRewardReceiver(token);
    notifier = new TransferFromRewardNotifier(
      receiver, initialRewardAmount, initialRewardInterval, source, owner
    );
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
    vm.mockCall(
      _receiver,
      abi.encodeWithSelector(INotifiableRewardReceiver.REWARD_TOKEN.selector),
      abi.encode(_token)
    );

    TransferFromRewardNotifier _notifier = new TransferFromRewardNotifier(
      INotifiableRewardReceiver(_receiver),
      _initialRewardAmount,
      _initialRewardInterval,
      _initialRewardSource,
      _owner
    );

    assertEq(address(_notifier.RECEIVER()), _receiver);
    assertEq(address(_notifier.TOKEN()), _token);
    assertEq(_notifier.rewardAmount(), _initialRewardAmount);
    assertEq(_notifier.rewardInterval(), _initialRewardInterval);
    assertEq(_notifier.rewardSource(), _initialRewardSource);
    assertEq(_notifier.owner(), _owner);
  }

  function testFuzz_EmitsAnEventForSettingTheRewardAmount(uint256 _initialRewardAmount) public {
    vm.expectEmit();
    emit TransferFromRewardNotifier.RewardAmountSet(0, _initialRewardAmount);
    new TransferFromRewardNotifier(
      receiver, _initialRewardAmount, initialRewardInterval, source, owner
    );
  }

  function testFuzz_EmitsAnEventForSettingTheRewardInterval(uint256 _initialRewardInterval) public {
    vm.expectEmit();
    emit TransferFromRewardNotifier.RewardIntervalSet(0, _initialRewardInterval);
    new TransferFromRewardNotifier(
      receiver, initialRewardAmount, _initialRewardInterval, source, owner
    );
  }

  function testFuzz_EmitsAnEventForSettingTheRewardSource(address _initialRewardSource) public {
    vm.expectEmit();
    emit TransferFromRewardNotifier.RewardSourceSet(address(0), _initialRewardSource);
    new TransferFromRewardNotifier(
      receiver, initialRewardAmount, initialRewardInterval, _initialRewardSource, owner
    );
  }
}

contract SetRewardAmount is TransferFromRewardNotifierTest {
  function testFuzz_UpdatesTheRewardAmount(uint256 _newRewardAmount) public {
    vm.prank(owner);
    notifier.setRewardAmount(_newRewardAmount);

    assertEq(notifier.rewardAmount(), _newRewardAmount);
  }

  function testFuzz_EmitsAnEventForSettingTheRewardAmount(uint256 _newRewardAmount) public {
    vm.expectEmit();
    emit TransferFromRewardNotifier.RewardAmountSet(initialRewardAmount, _newRewardAmount);
    vm.prank(owner);
    notifier.setRewardAmount(_newRewardAmount);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(uint256 _newRewardAmount, address _notOwner) public {
    vm.assume(_notOwner != owner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    vm.prank(_notOwner);
    notifier.setRewardAmount(_newRewardAmount);
  }
}

contract SetRewardInterval is TransferFromRewardNotifierTest {
  function testFuzz_UpdatesTheRewardInterval(uint256 _newRewardInterval) public {
    vm.prank(owner);
    notifier.setRewardInterval(_newRewardInterval);

    assertEq(notifier.rewardInterval(), _newRewardInterval);
  }

  function testFuzz_EmitsAnEventForSettingTheRewardInterval(uint256 _newRewardInterval) public {
    vm.expectEmit();
    emit TransferFromRewardNotifier.RewardIntervalSet(initialRewardInterval, _newRewardInterval);
    vm.prank(owner);
    notifier.setRewardInterval(_newRewardInterval);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(uint256 _newRewardInterval, address _notOwner) public {
    vm.assume(_notOwner != owner);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _notOwner));
    vm.prank(_notOwner);
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
    emit TransferFromRewardNotifier.Notified(_rewardAmount, block.timestamp + _rewardInterval);
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
      TransferFromRewardNotifier.TransferFromRewardNotifier__RewardIntervalNotElapsed.selector
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
      _interval = bound(_interval, 1 minutes, 520 weeks);
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

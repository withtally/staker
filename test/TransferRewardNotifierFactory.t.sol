// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {TransferRewardNotifierFactory} from "../src/notifiers/TransferRewardNotifierFactory.sol";
import {TransferRewardNotifier} from "../src/notifiers/TransferRewardNotifier.sol";
import {RewardTokenNotifierBase} from "../src/notifiers/RewardTokenNotifierBase.sol";
import {ERC20VotesMock} from "./mocks/MockERC20Votes.sol";
import {MockNotifiableRewardReceiver} from "./mocks/MockNotifiableRewardReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TransferRewardNotifierFactoryTest is Test {
  TransferRewardNotifierFactory factory;
  MockNotifiableRewardReceiver receiver;
  ERC20VotesMock rewardToken;
  address owner;
  uint256 initialRewardAmount;
  uint256 initialRewardInterval;

  function setUp() public {
    factory = new TransferRewardNotifierFactory();
    rewardToken = new ERC20VotesMock();
    receiver = new MockNotifiableRewardReceiver(IERC20(rewardToken));
    owner = address(this);
    initialRewardAmount = 100 ether;
    initialRewardInterval = 7 days;
  }

  function testCreateTransferRewardNotifier() public {
    address notifierAddr = factory.createTransferRewardNotifier(
      receiver, initialRewardAmount, initialRewardInterval, owner
    );

    assertGt(notifierAddr.code.length, 0, "Deployed notifier should have code");

    // Verify factory bookkeeping
    assertEq(factory.allNotifiersLength(), 1);
    assertEq(factory.allNotifiers(0), notifierAddr);

    // Verify notifier configuration
    TransferRewardNotifier notifier = TransferRewardNotifier(notifierAddr);
    assertEq(address(notifier.RECEIVER()), address(receiver));
    assertEq(address(notifier.TOKEN()), address(rewardToken));
    assertEq(notifier.rewardAmount(), initialRewardAmount);
    assertEq(notifier.rewardInterval(), initialRewardInterval);
    assertEq(notifier.owner(), owner);
  }

  function testMultipleDeployments() public {
    uint256 deployments = 3;

    for (uint256 i = 0; i < deployments; i++) {
      MockNotifiableRewardReceiver customReceiver =
        new MockNotifiableRewardReceiver(IERC20(rewardToken));

      address notifierAddr = factory.createTransferRewardNotifier(
        customReceiver, initialRewardAmount * (i + 1), initialRewardInterval, owner
      );

      assertGt(notifierAddr.code.length, 0);
      assertEq(factory.allNotifiers(i), notifierAddr);

      // Verify configuration
      TransferRewardNotifier notifier = TransferRewardNotifier(notifierAddr);
      assertEq(address(notifier.RECEIVER()), address(customReceiver));
      assertEq(notifier.rewardAmount(), initialRewardAmount * (i + 1));
    }

    assertEq(factory.allNotifiersLength(), deployments);
  }

  function testNotifierFunctionality() public {
    // Deploy notifier
    address notifierAddr = factory.createTransferRewardNotifier(
      receiver, initialRewardAmount, initialRewardInterval, owner
    );
    TransferRewardNotifier notifier = TransferRewardNotifier(notifierAddr);

    // Send reward tokens to notifier
    rewardToken.mint(notifierAddr, initialRewardAmount);

    // Verify initial state
    assertEq(rewardToken.balanceOf(notifierAddr), initialRewardAmount);
    assertEq(rewardToken.balanceOf(address(receiver)), 0);
    assertEq(receiver.lastParam_notifyRewardAmount_amount(), 0);

    // Trigger notification
    notifier.notify();

    // Verify notification occurred
    assertEq(rewardToken.balanceOf(notifierAddr), 0);
    assertEq(rewardToken.balanceOf(address(receiver)), initialRewardAmount);
    assertEq(receiver.lastParam_notifyRewardAmount_amount(), initialRewardAmount);
  }

  /*//////////////////////////////////////////////////////////////////////////
                                  New Tests
  //////////////////////////////////////////////////////////////////////////*/

  function testEmitsEventOnCreate() public {
    // We cannot know the notifier address ahead of time, so we ignore topic1 (notifier)
    vm.expectEmit(false, true, true, true);
    emit TransferRewardNotifierFactory.TransferRewardNotifierCreated(
      address(0),
      address(receiver),
      address(rewardToken),
      initialRewardAmount,
      initialRewardInterval,
      owner
    );

    factory.createTransferRewardNotifier(
      receiver, initialRewardAmount, initialRewardInterval, owner
    );
  }

  function testRevertIf_RewardAmountIsZero() public {
    vm.expectRevert(RewardTokenNotifierBase.RewardTokenNotifierBase__InvalidParameter.selector);
    factory.createTransferRewardNotifier(receiver, 0, initialRewardInterval, owner);
  }

  function testRevertIf_IntervalBelowMinimum() public {
    uint256 invalidInterval = 1 hours; // < MIN_REWARD_INTERVAL (1 day)
    vm.expectRevert(RewardTokenNotifierBase.RewardTokenNotifierBase__InvalidParameter.selector);
    factory.createTransferRewardNotifier(receiver, initialRewardAmount, invalidInterval, owner);
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {TransferFromRewardNotifierFactory} from
  "../src/notifiers/TransferFromRewardNotifierFactory.sol";
import {TransferFromRewardNotifier} from "../src/notifiers/TransferFromRewardNotifier.sol";
import {RewardTokenNotifierBase} from "../src/notifiers/RewardTokenNotifierBase.sol";
import {ERC20VotesMock} from "./mocks/MockERC20Votes.sol";
import {MockNotifiableRewardReceiver} from "./mocks/MockNotifiableRewardReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TransferFromRewardNotifierFactoryTest is Test {
  TransferFromRewardNotifierFactory factory;
  MockNotifiableRewardReceiver receiver;
  ERC20VotesMock rewardToken;
  address owner;
  address rewardSource;
  uint256 initialRewardAmount;
  uint256 initialRewardInterval;

  function setUp() public {
    factory = new TransferFromRewardNotifierFactory();
    rewardToken = new ERC20VotesMock();
    receiver = new MockNotifiableRewardReceiver(IERC20(rewardToken));
    owner = address(this);
    rewardSource = address(1234); // Using a simple address for reward source
    initialRewardAmount = 100 ether;
    initialRewardInterval = 7 days;
  }

  function testCreateTransferFromRewardNotifier() public {
    address notifierAddr = factory.createTransferFromRewardNotifier(
      receiver, initialRewardAmount, initialRewardInterval, owner, rewardSource
    );

    assertGt(notifierAddr.code.length, 0, "Deployed notifier should have code");

    // Verify factory bookkeeping
    assertEq(factory.allNotifiersLength(), 1);
    assertEq(factory.allNotifiers(0), notifierAddr);

    // Verify notifier configuration
    TransferFromRewardNotifier notifier = TransferFromRewardNotifier(notifierAddr);
    assertEq(address(notifier.RECEIVER()), address(receiver));
    assertEq(address(notifier.TOKEN()), address(rewardToken));
    assertEq(notifier.rewardAmount(), initialRewardAmount);
    assertEq(notifier.rewardInterval(), initialRewardInterval);
    assertEq(notifier.owner(), owner);
    assertEq(notifier.rewardSource(), rewardSource);
  }

  function testMultipleDeployments() public {
    uint256 deployments = 3;

    for (uint256 i = 0; i < deployments; i++) {
      MockNotifiableRewardReceiver customReceiver =
        new MockNotifiableRewardReceiver(IERC20(rewardToken));
      address customSource = address(uint160(1000 + i));

      address notifierAddr = factory.createTransferFromRewardNotifier(
        customReceiver, initialRewardAmount * (i + 1), initialRewardInterval, owner, customSource
      );

      assertGt(notifierAddr.code.length, 0);
      assertEq(factory.allNotifiers(i), notifierAddr);

      // Verify configuration
      TransferFromRewardNotifier notifier = TransferFromRewardNotifier(notifierAddr);
      assertEq(address(notifier.RECEIVER()), address(customReceiver));
      assertEq(notifier.rewardAmount(), initialRewardAmount * (i + 1));
      assertEq(notifier.rewardSource(), customSource);
    }

    assertEq(factory.allNotifiersLength(), deployments);
  }

  function testNotifierFunctionality() public {
    // Set our test contract as the reward source so we can approve tokens
    address localRewardSource = address(this);

    // Deploy notifier with this contract as reward source
    address notifierAddr = factory.createTransferFromRewardNotifier(
      receiver, initialRewardAmount, initialRewardInterval, owner, localRewardSource
    );
    TransferFromRewardNotifier notifier = TransferFromRewardNotifier(notifierAddr);

    // Mint reward tokens to the source
    rewardToken.mint(localRewardSource, initialRewardAmount);

    // Approve notifier to transfer tokens
    rewardToken.approve(notifierAddr, initialRewardAmount);

    // Verify initial state
    assertEq(rewardToken.balanceOf(localRewardSource), initialRewardAmount);
    assertEq(rewardToken.balanceOf(address(receiver)), 0);
    assertEq(receiver.lastRewardAmount(), 0);

    // Trigger notification
    notifier.notify();

    // Verify notification occurred
    assertEq(rewardToken.balanceOf(localRewardSource), 0);
    assertEq(rewardToken.balanceOf(address(receiver)), initialRewardAmount);
    assertEq(receiver.lastRewardAmount(), initialRewardAmount);
  }

  /*//////////////////////////////////////////////////////////////////////////
                                  New Tests
  //////////////////////////////////////////////////////////////////////////*/

  function testEmitsEventOnCreate() public {
    vm.expectEmit(false, true, true, true);
    emit TransferFromRewardNotifierFactory.TransferFromRewardNotifierCreated(
      address(0),
      address(receiver),
      address(rewardToken),
      initialRewardAmount,
      initialRewardInterval,
      owner,
      rewardSource
    );

    factory.createTransferFromRewardNotifier(
      receiver, initialRewardAmount, initialRewardInterval, owner, rewardSource
    );
  }

  function testRevertIf_RewardAmountIsZero() public {
    vm.expectRevert(RewardTokenNotifierBase.RewardTokenNotifierBase__InvalidParameter.selector);
    factory.createTransferFromRewardNotifier(
      receiver, 0, initialRewardInterval, owner, rewardSource
    );
  }

  // No revert expected when reward source is zero; notifier allows updating later.
}

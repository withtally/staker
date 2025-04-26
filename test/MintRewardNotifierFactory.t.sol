// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {MintRewardNotifierFactory} from "../src/notifiers/MintRewardNotifierFactory.sol";
import {MintRewardNotifier} from "../src/notifiers/MintRewardNotifier.sol";
import {RewardTokenNotifierBase} from "../src/notifiers/RewardTokenNotifierBase.sol";
import {ERC20Fake} from "./fakes/ERC20Fake.sol";
import {MockNotifiableRewardReceiver} from "./mocks/MockNotifiableRewardReceiver.sol";
import {IMintable} from "../src/interfaces/IMintable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MintRewardNotifierFactoryTest is Test {
  MintRewardNotifierFactory factory;
  MockNotifiableRewardReceiver receiver;
  ERC20Fake minter;
  address owner;
  uint256 initialRewardAmount;
  uint256 initialRewardInterval;

  function setUp() public {
    factory = new MintRewardNotifierFactory();
    minter = new ERC20Fake();
    receiver = new MockNotifiableRewardReceiver(IERC20(address(minter)));
    owner = address(this);
    initialRewardAmount = 100 ether;
    initialRewardInterval = 7 days;
  }

  function testCreateMintRewardNotifier() public {
    address notifierAddr = factory.createMintRewardNotifier(
      receiver, initialRewardAmount, initialRewardInterval, owner, IMintable(address(minter))
    );

    assertGt(notifierAddr.code.length, 0, "Deployed notifier should have code");

    // Verify factory bookkeeping
    assertEq(factory.allNotifiersLength(), 1);
    assertEq(factory.allNotifiers(0), notifierAddr);

    // Verify notifier configuration
    MintRewardNotifier notifier = MintRewardNotifier(notifierAddr);
    assertEq(address(notifier.RECEIVER()), address(receiver));
    assertEq(address(notifier.TOKEN()), address(minter));
    assertEq(notifier.rewardAmount(), initialRewardAmount);
    assertEq(notifier.rewardInterval(), initialRewardInterval);
    assertEq(notifier.owner(), owner);
    assertEq(address(notifier.minter()), address(minter));
  }

  function testMultipleDeployments() public {
    uint256 deployments = 3;

    for (uint256 i = 0; i < deployments; i++) {
      ERC20Fake customMinter = new ERC20Fake();
      MockNotifiableRewardReceiver customReceiver =
        new MockNotifiableRewardReceiver(IERC20(address(customMinter)));

      address notifierAddr = factory.createMintRewardNotifier(
        customReceiver,
        initialRewardAmount * (i + 1),
        initialRewardInterval,
        owner,
        IMintable(address(customMinter))
      );

      assertGt(notifierAddr.code.length, 0);
      assertEq(factory.allNotifiers(i), notifierAddr);

      // Verify configuration
      MintRewardNotifier notifier = MintRewardNotifier(notifierAddr);
      assertEq(address(notifier.RECEIVER()), address(customReceiver));
      assertEq(notifier.rewardAmount(), initialRewardAmount * (i + 1));
      assertEq(address(notifier.minter()), address(customMinter));
    }

    assertEq(factory.allNotifiersLength(), deployments);
  }

  function testNotifierFunctionality() public {
    // Deploy notifier
    address notifierAddr = factory.createMintRewardNotifier(
      receiver, initialRewardAmount, initialRewardInterval, owner, IMintable(address(minter))
    );
    MintRewardNotifier notifier = MintRewardNotifier(notifierAddr);

    // Verify initial state
    assertEq(minter.balanceOf(address(receiver)), 0);
    assertEq(receiver.lastParam_notifyRewardAmount_amount(), 0);

    // Trigger notification
    notifier.notify();

    // Verify notification occurred
    assertEq(minter.balanceOf(address(receiver)), initialRewardAmount);
    assertEq(receiver.lastParam_notifyRewardAmount_amount(), initialRewardAmount);
  }

  /*//////////////////////////////////////////////////////////////////////////
                                  New Tests
  //////////////////////////////////////////////////////////////////////////*/

  function testEmitsEventOnCreate() public {
    vm.expectEmit(false, true, true, true);
    emit MintRewardNotifierFactory.MintRewardNotifierCreated(
      address(0),
      address(receiver),
      address(minter),
      initialRewardAmount,
      initialRewardInterval,
      owner,
      address(minter)
    );

    factory.createMintRewardNotifier(
      receiver, initialRewardAmount, initialRewardInterval, owner, IMintable(address(minter))
    );
  }

  function testRevertIf_RewardAmountIsZero() public {
    vm.expectRevert(RewardTokenNotifierBase.RewardTokenNotifierBase__InvalidParameter.selector);
    factory.createMintRewardNotifier(
      receiver, 0, initialRewardInterval, owner, IMintable(address(minter))
    );
  }
}

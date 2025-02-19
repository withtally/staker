// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

import {IEarningPowerCalculator} from "src/Staker.sol";
import {StakerHandler} from "test/helpers/Staker.handler.sol";
import {StakerHarness} from "test/harnesses/StakerHarness.sol";
import {ERC20VotesMock} from "test/mocks/MockERC20Votes.sol";
import {ERC20Fake} from "test/fakes/ERC20Fake.sol";
import {MockFullEarningPowerCalculator} from "test/mocks/MockFullEarningPowerCalculator.sol";

contract StakerInvariants is Test {
  StakerHandler public handler;
  StakerHarness public govStaker;
  ERC20Fake rewardToken;
  ERC20VotesMock govToken;
  IEarningPowerCalculator earningPowerCalculator;
  address rewardsNotifier;
  uint256 maxBumpTip = 2e18;
  string STAKER_NAME = "StakerHarness";

  function setUp() public {
    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Rewards Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");

    rewardsNotifier = address(0xaffab1ebeef);
    vm.label(rewardsNotifier, "Rewards Notifier");

    earningPowerCalculator = new MockFullEarningPowerCalculator();
    vm.label(address(earningPowerCalculator), "Full Earning Power Calculator");

    govStaker = new StakerHarness(
      rewardToken, govToken, earningPowerCalculator, maxBumpTip, rewardsNotifier, STAKER_NAME
    );
    handler = new StakerHandler(govStaker);

    bytes4[] memory selectors = new bytes4[](7);
    selectors[0] = StakerHandler.stake.selector;
    selectors[1] = StakerHandler.validStakeMore.selector;
    selectors[2] = StakerHandler.validWithdraw.selector;
    selectors[3] = StakerHandler.warpAhead.selector;
    selectors[4] = StakerHandler.claimReward.selector;
    selectors[5] = StakerHandler.enableRewardNotifier.selector;
    selectors[6] = StakerHandler.notifyRewardAmount.selector;

    targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));

    targetContract(address(handler));
  }

  // Invariants

  function invariant_Sum_of_all_depositor_balances_equals_total_stake() public {
    assertEq(govStaker.totalStaked(), handler.reduceDepositors(0, this.accumulateDeposits));
  }

  function invariant_Sum_of_surrogate_balance_equals_total_stake() public {
    assertEq(govStaker.totalStaked(), handler.reduceDelegates(0, this.accumulateSurrogateBalance));
  }

  function invariant_Sum_of_depositor_earning_power_equals_total_earning_power() public {
    assertEq(
      govStaker.totalEarningPower(), handler.reduceDepositors(0, this.accumulateEarningPower)
    );
  }

  function invariant_Cumulative_staked_minus_withdrawals_equals_total_stake() public view {
    assertEq(govStaker.totalStaked(), handler.ghost_stakeSum() - handler.ghost_stakeWithdrawn());
  }

  function invariant_Sum_of_notified_rewards_equals_all_claimed_rewards_plus_rewards_left()
    public
    view
  {
    assertEq(
      handler.ghost_rewardsNotified(),
      rewardToken.balanceOf(address(govStaker)) + handler.ghost_rewardsClaimed()
    );
  }

  function invariant_Sum_of_unclaimed_reward_should_be_less_than_or_equal_to_total_rewards_balance()
    public
  {
    assertLe(
      handler.reduceDeposits(0, this.accumulateUnclaimedReward),
      rewardToken.balanceOf(address(govStaker))
    );
  }

  function invariant_RewardPerTokenAccumulatedCheckpoint_should_be_greater_or_equal_to_the_last_rewardPerTokenAccumulatedCheckpoint(
  ) public view {
    assertGe(
      govStaker.rewardPerTokenAccumulatedCheckpoint(),
      handler.ghost_prevRewardPerTokenAccumulatedCheckpoint()
    );
  }

  // Used to see distribution of non-reverting calls
  function invariant_callSummary() public view {
    handler.callSummary();
  }

  // Helpers

  function accumulateDeposits(uint256 balance, address depositor) external view returns (uint256) {
    return balance + govStaker.depositorTotalStaked(depositor);
  }

  function accumulateUnclaimedReward(
    uint256 unclaimedReward,
    StakerHarness.DepositIdentifier depositId
  ) external view returns (uint256) {
    return unclaimedReward + govStaker.unclaimedReward(depositId);
  }

  function accumulateEarningPower(uint256 earningPower, address depositor)
    external
    view
    returns (uint256)
  {
    return earningPower + govStaker.depositorTotalEarningPower(depositor);
  }

  function accumulateSurrogateBalance(uint256 balance, address delegate)
    external
    view
    returns (uint256)
  {
    address surrogateAddr = address(govStaker.surrogates(delegate));
    return balance + IERC20(address(govStaker.STAKE_TOKEN())).balanceOf(surrogateAddr);
  }
}

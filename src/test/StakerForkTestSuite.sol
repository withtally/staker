// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {Staker} from "../Staker.sol";
import {StakerTestBase} from "./StakerTestBase.sol";

/// @title StakeBase
/// @author [ScopeLift](https://scopelift.co)
/// @notice Provides a standard suite of tests for core staking functionality.
/// This includes tests for single and multiple depositors staking and earning rewards
/// over various timeframes and reward periods.
/// @dev Inherit this contract to test the fundamental staking and reward accrual logic of a Staker
/// implementation, covering scenarios where there are single and multiple depositors, as well as
/// single and multiple reward periods.
abstract contract StakeBase is StakerTestBase {
  /// @notice Tests that a single depositor correctly stakes and earns rewards after a specified
  /// duration within a single reward period. Asserts that the unclaimed rewards are consistent with
  /// calculated earned rewards.
  /// @param _depositor The address of the staker.
  /// @param _amount The amount of stake tokens to deposit.
  /// @param _delegatee The address with the stake's voting power.
  /// @param _rewardAmount The total reward amount for the period.
  /// @param _percentDuration The percentage of the reward duration to advance time by (1-100).
  function testForkFuzz_CorrectlyStakeAndEarnRewardsAfterDuration(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _percentDuration
  ) public virtual {
    _assumeNotZeroAddressOrStaker(_depositor);
    vm.assume(_delegatee != address(0) && _amount != 0);

    _mintStakeToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 1, 100);

    Staker.DepositIdentifier _depositId = _stake(_depositor, _amount, _delegatee);
    _updateEarningPower(_depositId);
    _notifyRewardAmount(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(bound(_percentDuration, 0, 100));

    uint256 unclaimedRewards = staker.unclaimedReward(_depositId);
    Staker.Deposit memory _deposit = _fetchDeposit(_depositId);

    uint256 _earnedRewards =
      _calculateEarnedRewards(_deposit.earningPower, _rewardAmount, _percentDuration);

    assertLteWithinOneUnit(unclaimedRewards, _earnedRewards);
  }

  /// @notice Tests that two distinct depositors correctly earn rewards over a single reward period,
  /// with stakes made at the same time. Asserts that unclaimed rewards for both depositors are
  /// consistent with calculated earned rewards.
  /// @param _depositor1 The address of the first staker.
  /// @param _depositor2 The address of the second staker.
  /// @param _amount The amount of stake tokens each depositor deposits.
  /// @param _delegatee The address to delegate voting power to for both deposits.
  /// @param _rewardAmount The total reward amount for the period.
  /// @param _percentDuration1 The first percentage of the reward duration to advance time by.
  /// @param _percentDuration2 The second percentage of the reward duration to advance time by,
  /// after the first.
  function testForkFuzz_TwoDepositorsEarnRewardsOverSinglePeriod(
    address _depositor1,
    address _depositor2,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _percentDuration1,
    uint256 _percentDuration2
  ) public {
    _assumeNotZeroAddressOrStaker(_depositor1);
    _assumeNotZeroAddressOrStaker(_depositor2);
    vm.assume(_depositor1 != _depositor2 && _delegatee != address(0) && _amount != 0);

    _mintStakeToken(_depositor1, _amount);
    _mintStakeToken(_depositor2, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration1 = bound(_percentDuration1, 1, 100);
    _percentDuration2 = bound(_percentDuration2, 0, 100 - _percentDuration1);

    Staker.DepositIdentifier _depositId1 = _stake(_depositor1, _amount, _delegatee);
    _updateEarningPower(_depositId1);
    Staker.DepositIdentifier _depositId2 = _stake(_depositor2, _amount, _delegatee);
    _updateEarningPower(_depositId2);
    _notifyRewardAmount(_rewardAmount);

    _jumpAheadByPercentOfRewardDuration(_percentDuration1);
    uint256 unclaimedRewards1 = staker.unclaimedReward(_depositId1);
    Staker.Deposit memory _deposit1 = _fetchDeposit(_depositId1);
    uint256 _earnedRewards1 =
      _calculateEarnedRewards(_deposit1.earningPower, _rewardAmount, _percentDuration1);

    _jumpAheadByPercentOfRewardDuration(_percentDuration2);
    uint256 unclaimedRewards2 = staker.unclaimedReward(_depositId2);
    Staker.Deposit memory _deposit2 = _fetchDeposit(_depositId2);
    uint256 _earnedRewards2 = _calculateEarnedRewards(
      _deposit2.earningPower, _rewardAmount, _percentDuration1 + _percentDuration2
    );

    assertLteWithinOneUnit(unclaimedRewards1, _earnedRewards1);
    assertLteWithinOneUnit(unclaimedRewards2, _earnedRewards2);
  }

  /// @notice Tests that two distinct depositors correctly earn rewards across multiple reward
  /// periods. Asserts that unclaimed rewards for both depositors are consistent with calculated
  /// earned rewards accumulated over both periods.
  /// @param _depositor1 The address of the first staker.
  /// @param _depositor2 The address of the second staker.
  /// @param _amount The amount of stake tokens each depositor deposits.
  /// @param _delegatee The address to delegate voting power to for both deposits.
  /// @param _rewardAmount The total reward amount for each period.
  /// @param _percentDuration1 The percentage of the first reward duration to advance time by.
  /// @param _percentDuration2 The percentage of the second reward duration to advance time by.
  function testForkFuzz_TwoDepositorsEarnRewardsOverMultiplePeriods(
    address _depositor1,
    address _depositor2,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _percentDuration1,
    uint256 _percentDuration2
  ) public {
    _assumeNotZeroAddressOrStaker(_depositor1);
    _assumeNotZeroAddressOrStaker(_depositor2);
    vm.assume(_depositor1 != _depositor2 && _delegatee != address(0) && _amount != 0);

    _mintStakeToken(_depositor1, _amount);
    _mintStakeToken(_depositor2, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration1 = bound(_percentDuration1, 1, 100);
    _percentDuration2 = bound(_percentDuration2, 1, 100);

    Staker.DepositIdentifier _depositId1 = _stake(_depositor1, _amount, _delegatee);
    _updateEarningPower(_depositId1);
    Staker.DepositIdentifier _depositId2 = _stake(_depositor2, _amount, _delegatee);
    _updateEarningPower(_depositId2);

    _notifyRewardAmount(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration1);

    // intentionally warp till the end of current reward period
    _jumpAheadByPercentOfRewardDuration(100 - _percentDuration1);

    _notifyRewardAmount(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration2);

    uint256 unclaimedRewards1 = staker.unclaimedReward(_depositId1);
    uint256 unclaimedRewards2 = staker.unclaimedReward(_depositId2);
    Staker.Deposit memory _deposit1 = _fetchDeposit(_depositId1);
    Staker.Deposit memory _deposit2 = _fetchDeposit(_depositId2);
    uint256 _earnedRewards1 = _calculateEarnedRewards(_deposit1.earningPower, _rewardAmount, 100)
      + _calculateEarnedRewards(_deposit1.earningPower, _rewardAmount, _percentDuration2);
    uint256 _earnedRewards2 = _calculateEarnedRewards(_deposit2.earningPower, _rewardAmount, 100)
      + _calculateEarnedRewards(_deposit2.earningPower, _rewardAmount, _percentDuration2);

    assertLteWithinOneUnit(unclaimedRewards1, _earnedRewards1);
    assertLteWithinOneUnit(unclaimedRewards2, _earnedRewards2);
  }
}

/// @title WithdrawBase
/// @author [ScopeLift](https://scopelift.co)
/// @notice Provides a standard suite of tests for withdrawal functionality.
/// This includes tests for unstaking after reward accrual, withdrawals by multiple users,
/// and interactions between claiming rewards and withdrawing stake.
/// @dev Inherit this contract to test the withdrawal mechanisms of a Staker implementation,
/// including scenarios with single and multiple users unstaking, and interactions
/// between reward claims and withdrawals.
abstract contract WithdrawBase is StakerTestBase {
  /// @notice Tests that a depositor can correctly unstake a specified amount after rewards have
  /// accrued over a duration. Asserts that the staker's token balance reflects the withdrawal and
  /// unclaimed rewards are handled consistently.
  /// @param _depositor The address of the staker.
  /// @param _amount The initial amount of stake tokens deposited.
  /// @param _delegatee The address with the stake's voting power.
  /// @param _rewardAmount The total reward amount for the period.
  /// @param _withdrawAmount The amount of stake tokens to withdraw.
  /// @param _percentDuration The percentage of the reward duration to advance time by before
  /// withdrawal.
  function testForkFuzz_CorrectlyUnstakeAfterDuration(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _withdrawAmount,
    uint256 _percentDuration
  ) public {
    vm.assume(_depositor != address(0) && _delegatee != address(0));
    vm.assume(_depositor != address(staker));

    _amount = uint96(_boundMintAmount(_amount));
    vm.assume(_amount != 0);
    _mintStakeToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 1, 100);

    Staker.DepositIdentifier _depositId = _stake(_depositor, _amount, _delegatee);
    _updateEarningPower(_depositId);
    _notifyRewardAmount(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 initialRewards = staker.unclaimedReward(_depositId);

    _withdrawAmount = bound(_withdrawAmount, 0, _amount);
    _withdraw(_depositor, _depositId, _withdrawAmount);

    uint256 _balance = STAKE_TOKEN.balanceOf(_depositor);

    // If we have rewards accrued, check that they're consistent after withdrawal
    uint256 currentRewards = staker.unclaimedReward(_depositId);
    assertLteWithinOneUnit(currentRewards, initialRewards);
    assertEq(_balance, _withdrawAmount);
  }

  /// @notice Tests withdrawal functionality for two distinct users after rewards have accrued over
  /// different partial durations. Asserts that each user's token balance reflects their withdrawal
  /// and unclaimed rewards are consistent.
  /// @param _depositor1 The address of the first staker.
  /// @param _depositor2 The address of the second staker.
  /// @param _amount The initial amount of stake tokens deposited by each user.
  /// @param _delegatee The address to delegate voting power to for both deposits.
  /// @param _rewardAmount The total reward amount for the period.
  /// @param _withdrawAmount1 The amount for the first depositor to withdraw.
  /// @param _withdrawAmount2 The amount for the second depositor to withdraw.
  /// @param _percentDuration1 The first percentage of the reward duration to advance time by before
  /// the first withdrawal.
  /// @param _percentDuration2 The second percentage of the reward duration to advance time by
  /// before the second withdrawal.
  function testFuzz_WithdrawTwoUsersAfterDuration(
    address _depositor1,
    address _depositor2,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _withdrawAmount1,
    uint256 _withdrawAmount2,
    uint256 _percentDuration1,
    uint256 _percentDuration2
  ) public {
    _assumeNotZeroAddressOrStaker(_depositor1);
    _assumeNotZeroAddressOrStaker(_depositor2);
    vm.assume(_depositor1 != _depositor2 && _delegatee != address(0));

    _amount = uint96(_boundMintAmount(_amount));
    vm.assume(_amount != 0);

    _mintStakeToken(_depositor1, _amount);
    _mintStakeToken(_depositor2, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration1 = bound(_percentDuration1, 1, 100);
    _percentDuration2 = bound(_percentDuration2, 0, 100 - _percentDuration1);

    Staker.DepositIdentifier _depositId1 = _stake(_depositor1, _amount, _delegatee);
    _updateEarningPower(_depositId1);
    Staker.DepositIdentifier _depositId2 = _stake(_depositor2, _amount, _delegatee);
    _updateEarningPower(_depositId2);

    _notifyRewardAmount(_rewardAmount);

    _jumpAheadByPercentOfRewardDuration(_percentDuration1);
    uint256 initialRewards1 = staker.unclaimedReward(_depositId1);
    _withdrawAmount1 = bound(_withdrawAmount1, 0, _amount);
    _withdraw(_depositor1, _depositId1, _withdrawAmount1);
    assertLteWithinOneUnit(staker.unclaimedReward(_depositId1), initialRewards1);

    _jumpAheadByPercentOfRewardDuration(_percentDuration2);
    uint256 initialRewards2 = staker.unclaimedReward(_depositId2);
    _withdrawAmount2 = bound(_withdrawAmount2, 0, _amount);
    _withdraw(_depositor2, _depositId2, _withdrawAmount2);
    assertLteWithinOneUnit(staker.unclaimedReward(_depositId2), initialRewards2);

    assertEq(STAKE_TOKEN.balanceOf(_depositor1), _withdrawAmount1);
    assertEq(STAKE_TOKEN.balanceOf(_depositor2), _withdrawAmount2);
  }

  /// @notice Tests that a depositor can claim their accrued rewards and then withdraw parts or all
  /// of their stake. Asserts that rewards are correctly transferred upon claim, unclaimed rewards
  /// become zero, and stake is correctly withdrawn.
  /// @param _depositor The address of the staker.
  /// @param _amount The initial amount of stake tokens deposited.
  /// @param _delegatee The address with the stake's voting power.
  /// @param _rewardAmount The total reward amount for the period.
  /// @param _withdrawAmount The amount of stake tokens to withdraw.
  /// @param _percentDuration The percentage of the reward duration to advance time by before
  /// claiming and withdrawing.
  function testForkFuzz_ClaimRewardAndWithdrawAfterDuration(
    address _depositor,
    uint96 _amount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _withdrawAmount,
    uint256 _percentDuration
  ) public {
    _assumeNotZeroAddressOrStaker(_depositor);
    vm.assume(_delegatee != address(0));

    _amount = uint96(_boundMintAmount(_amount));
    _mintStakeToken(_depositor, _amount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 1, 100);

    Staker.DepositIdentifier _depositId = _stake(_depositor, _amount, _delegatee);
    _updateEarningPower(_depositId);
    _notifyRewardAmount(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 initialRewards = staker.unclaimedReward(_depositId);
    uint256 initialRewardBalance = REWARD_TOKEN.balanceOf(_depositor);

    vm.prank(_depositor);
    staker.claimReward(_depositId);

    uint256 rewardsReceived = REWARD_TOKEN.balanceOf(_depositor) - initialRewardBalance;
    assertEq(staker.unclaimedReward(_depositId), 0);
    assertEq(rewardsReceived, initialRewards);

    _withdrawAmount = bound(_withdrawAmount, 0, _amount);
    _withdraw(_depositor, _depositId, _withdrawAmount);

    uint256 _balance = STAKE_TOKEN.balanceOf(_depositor);
    assertEq(_balance, _withdrawAmount);
  }
}

/// @title ClaimRewardBase
/// @author [ScopeLift](https://scopelift.co)
/// @notice Provides a standard suite of tests for reward claiming functionality.
/// This includes tests for claiming rewards over single and multiple periods, handling of
/// zero-deposits, and scenarios involving staking, claiming, and re-staking.
/// @dev Inherit this contract to test the reward claiming mechanisms of a Staker implementation,
/// covering scenarios such as claims within single and across multiple reward periods, zero-deposit
/// handling, and sequences of staking, claiming, and re-staking.
abstract contract ClaimRewardBase is StakerTestBase {
  /// @notice Tests that a depositor can correctly claim all earned rewards within a single reward
  /// period. Asserts that the claimed reward amount matches the unclaimed rewards and that
  /// unclaimed rewards become zero post-claim.
  /// @param _depositor The address of the staker.
  /// @param _delegatee The address with the stake's voting power.
  /// @param _depositAmount The amount of stake tokens deposited.
  /// @param _rewardAmount The total reward amount for the period.
  /// @param _percentDuration The percentage of the reward duration to advance time by before
  /// claiming.
  function testFuzz_DepositorClaimsEarnedRewardsWithinASinglePeriod(
    address _depositor,
    address _delegatee,
    uint96 _depositAmount,
    uint256 _rewardAmount,
    uint256 _percentDuration
  ) public {
    _assumeNotZeroAddressOrStaker(_depositor);
    vm.assume(_delegatee != address(0));

    _mintStakeToken(_depositor, _depositAmount);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _percentDuration = bound(_percentDuration, 1, 100);

    Staker.DepositIdentifier _depositId = _stake(_depositor, _depositAmount, _delegatee);
    _updateEarningPower(_depositId);
    _notifyRewardAmount(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _unclaimedReward = staker.unclaimedReward(_depositId);

    vm.prank(_depositor);
    staker.claimReward(_depositId);

    uint256 _claimedReward = REWARD_TOKEN.balanceOf(_depositor);

    assertEq(_claimedReward, _unclaimedReward);
    assertEq(staker.unclaimedReward(_depositId), 0);
  }

  /// @notice Tests that a depositor can correctly claim rewards accumulated over multiple reward
  /// periods. Asserts that the total claimed reward matches the total unclaimed rewards from all
  /// periods.
  /// @param _depositor The address of the staker.
  /// @param _delegatee The address with the stake's voting power.
  /// @param _depositAmount The amount of stake tokens deposited.
  /// @param _rewardAmount1 The reward amount for the first period.
  /// @param _rewardAmount2 The reward amount for the second period.
  /// @param _percentDuration The percentage of the second reward duration to advance time by before
  /// claiming.
  function testFuzz_DepositorClaimsEarnedRewardsAfterMultiplePeriods(
    address _depositor,
    address _delegatee,
    uint96 _depositAmount,
    uint256 _rewardAmount1,
    uint256 _rewardAmount2,
    uint256 _percentDuration
  ) public {
    _assumeNotZeroAddressOrStaker(_depositor);
    vm.assume(_delegatee != address(0) && _depositAmount != 0);

    _percentDuration = bound(_percentDuration, 1, 100);
    _rewardAmount1 = _boundToRealisticReward(_rewardAmount1);
    _rewardAmount2 = _boundToRealisticReward(_rewardAmount2);

    _mintStakeToken(_depositor, _depositAmount);

    Staker.DepositIdentifier _depositId = _stake(_depositor, _depositAmount, _delegatee);
    _updateEarningPower(_depositId);

    _notifyRewardAmount(_rewardAmount1);
    _jumpAheadByPercentOfRewardDuration(100);

    _rewardAmount2 = _boundToRealisticReward(_rewardAmount2);
    _notifyRewardAmount(_rewardAmount2);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _unclaimedReward = staker.unclaimedReward(_depositId);

    vm.prank(_depositor);
    staker.claimReward(_depositId);

    uint256 _claimedReward = REWARD_TOKEN.balanceOf(_depositor);

    assertEq(_claimedReward, _unclaimedReward);
    assertLteWithinOneUnit(_claimedReward, _rewardAmount1 + _rewardAmount2 * _percentDuration / 100);
    assertEq(staker.unclaimedReward(_depositId), 0);
  }

  /// @notice Tests that a deposit of zero tokens correctly yields zero rewards. Asserts that both
  /// unclaimed and claimed rewards are zero when the deposit amount is zero.
  /// @param _depositor The address of the staker.
  /// @param _delegatee The address with the stake's voting power.
  /// @param _rewardAmount The total reward amount for the period.
  /// @param _percentDuration The percentage of the reward duration to advance time by.
  function testFuzz_ZeroDepositYieldsZeroReward(
    address _depositor,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _percentDuration
  ) public {
    _assumeNotZeroAddressOrStaker(_depositor);
    vm.assume(_delegatee != address(0));

    _percentDuration = bound(_percentDuration, 0, 100);

    _rewardAmount = _boundToRealisticReward(_rewardAmount);

    _mintStakeToken(_depositor, 0);
    Staker.DepositIdentifier _depositId = _stake(_depositor, 0, _delegatee);
    _updateEarningPower(_depositId);
    _notifyRewardAmount(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    uint256 _unclaimedReward = staker.unclaimedReward(_depositId);

    vm.prank(_depositor);
    staker.claimReward(_depositId);

    uint256 _claimedReward = REWARD_TOKEN.balanceOf(_depositor);

    assertEq(_claimedReward, _unclaimedReward);
    assertEq(_claimedReward, 0);
    assertEq(staker.unclaimedReward(_depositId), 0);
  }

  /// @notice Tests a scenario where a depositor stakes, claims rewards, waits, stakes again (new
  /// deposit), and then claims all rewards within a single reward period. Asserts that the total
  /// claimed rewards correctly reflect earnings from both deposits across the various time
  /// segments.
  /// @param _depositor The address of the staker.
  /// @param _delegatee The address with the stake's voting power.
  /// @param _depositAmount The amount for each of the two stake operations.
  /// @param _rewardAmount The total reward amount for the period.
  /// @param _percentDuration1 Percentage of duration before first claim.
  /// @param _percentDuration2 Percentage of duration to wait after first claim before second stake.
  /// @param _percentDuration3 Percentage of duration after second stake before final claims.
  function testFuzz_DepositorClaimsRewardsWaitsAndStakesAgainWithinASinglePeriod(
    address _depositor,
    address _delegatee,
    uint96 _depositAmount,
    uint256 _rewardAmount,
    uint256 _percentDuration1,
    uint256 _percentDuration2,
    uint256 _percentDuration3
  ) public {
    _assumeNotZeroAddressOrStaker(_depositor);
    vm.assume(_delegatee != address(0));

    _depositAmount = uint96(_boundToRealisticStake(_depositAmount));

    _percentDuration1 = bound(_percentDuration1, 0, 100);
    _percentDuration2 = bound(_percentDuration2, 0, 100 - _percentDuration1);
    _percentDuration3 = bound(_percentDuration3, 0, 100 - _percentDuration1 - _percentDuration2);

    _rewardAmount = _boundToRealisticReward(_rewardAmount);

    _mintStakeToken(_depositor, _depositAmount * 2);
    Staker.DepositIdentifier _depositId1 = _stake(_depositor, _depositAmount, _delegatee);
    _updateEarningPower(_depositId1);
    _notifyRewardAmount(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration1);

    uint256 _unclaimedReward1 = staker.unclaimedReward(_depositId1);

    vm.prank(_depositor);
    staker.claimReward(_depositId1);

    _jumpAheadByPercentOfRewardDuration(_percentDuration2);

    Staker.DepositIdentifier _depositId2 = _stake(_depositor, _depositAmount, _delegatee);
    _updateEarningPower(_depositId2);
    _jumpAheadByPercentOfRewardDuration(_percentDuration3);

    _unclaimedReward1 += staker.unclaimedReward(_depositId1);
    uint256 _unclaimedReward2 = staker.unclaimedReward(_depositId2);

    vm.startPrank(_depositor);
    staker.claimReward(_depositId1);
    staker.claimReward(_depositId2);
    vm.stopPrank();

    uint256 _claimedReward = REWARD_TOKEN.balanceOf(_depositor);

    assertEq(_claimedReward, _unclaimedReward1 + _unclaimedReward2);
    // because we summed 3 time periods, the rounding error can be as much as 2 units
    assertApproxEqAbs(
      _claimedReward,
      _rewardAmount * (_percentDuration1 + _percentDuration2 + _percentDuration3) / 100,
      2
    );
    assertEq(staker.unclaimedReward(_depositId1), 0);
    assertEq(staker.unclaimedReward(_depositId2), 0);
  }

  /// @notice Tests a scenario where a depositor stakes, claims rewards, waits until a new reward
  /// period, stakes again (new deposit), and then claims all rewards. Asserts that total claimed
  /// rewards correctly reflect earnings from both deposits across both reward periods.
  /// @param _depositor The address of the staker.
  /// @param _delegatee The address with the stake's voting power.
  /// @param _depositAmount1 The amount for the first stake.
  /// @param _depositAmount2 The amount for the second stake.
  /// @param _rewardAmount1 The reward amount for the first period.
  /// @param _rewardAmount2 The reward amount for the second period.
  /// @param _percentDuration1 Percentage of the first reward duration before the first claim.
  /// @param _percentDuration2 Percentage of the second reward duration after the second stake
  /// before final claims.
  function testFuzz_DepositorClaimsRewardsWaitsAndStakesAgainAfterMultiplePeriods(
    address _depositor,
    address _delegatee,
    uint96 _depositAmount1,
    uint96 _depositAmount2,
    uint256 _rewardAmount1,
    uint256 _rewardAmount2,
    uint256 _percentDuration1,
    uint256 _percentDuration2
  ) public {
    _assumeNotZeroAddressOrStaker(_depositor);
    vm.assume(_delegatee != address(0));
    _depositAmount1 = uint96(_boundToRealisticStake(_depositAmount1));
    _depositAmount2 = uint96(_boundToRealisticStake(_depositAmount2));

    _percentDuration1 = bound(_percentDuration1, 0, 100);
    _percentDuration2 = bound(_percentDuration2, 0, 100);

    _rewardAmount1 = _boundToRealisticReward(_rewardAmount1);
    _rewardAmount2 = _boundToRealisticReward(_rewardAmount2);

    _mintStakeToken(_depositor, _depositAmount1 + _depositAmount2);
    Staker.DepositIdentifier _depositId1 = _stake(_depositor, _depositAmount1, _delegatee);
    _updateEarningPower(_depositId1);
    _notifyRewardAmount(_rewardAmount1);
    _jumpAheadByPercentOfRewardDuration(_percentDuration1);

    uint256 _unclaimedReward1 = staker.unclaimedReward(_depositId1);

    vm.prank(_depositor);
    staker.claimReward(_depositId1);
    // intentionally warp till the end of current reward period
    _jumpAheadByPercentOfRewardDuration(100 - _percentDuration1);

    Staker.DepositIdentifier _depositId2 = _stake(_depositor, _depositAmount2, _delegatee);
    _updateEarningPower(_depositId2);
    _notifyRewardAmount(_rewardAmount2);
    _jumpAheadByPercentOfRewardDuration(_percentDuration2);

    _unclaimedReward1 += staker.unclaimedReward(_depositId1);
    uint256 _unclaimedReward2 = staker.unclaimedReward(_depositId2);

    vm.startPrank(_depositor);
    staker.claimReward(_depositId1);
    staker.claimReward(_depositId2);
    vm.stopPrank();

    uint256 _claimedReward = REWARD_TOKEN.balanceOf(_depositor);

    assertEq(_claimedReward, _unclaimedReward1 + _unclaimedReward2);
    // because we summed 2 amounts, the rounding error can be as much as 2 units
    assertApproxEqAbs(_claimedReward, _rewardAmount1 + _percentDuration2 * _rewardAmount2 / 100, 2);
    assertEq(staker.unclaimedReward(_depositId1), 0);
    assertEq(staker.unclaimedReward(_depositId2), 0);
  }
}

/// @title AlterClaimerBase
/// @author [ScopeLift](https://scopelift.co)
/// @notice Provides a standard suite of tests for the `alterClaimer` functionality.
/// This includes tests for updating the claimer both before and after rewards have
/// accrued.
/// @dev Inherit this contract to test the claimer alteration mechanism of a Staker implementation,
/// including updates to the claimer both before and after rewards have accrued.
abstract contract AlterClaimerBase is StakerTestBase {
  /// @notice Tests that a depositor can successfully update the claimer for their deposit before
  /// any rewards have accrued. Verifies that the `ClaimerAltered` event is emitted with correct
  /// parameters and the deposit's claimer is updated. No rewards should be present.
  /// @param _depositor The address of the staker.
  /// @param _depositAmount The amount of stake tokens deposited.
  /// @param _delegatee The initial delegatee address.
  /// @param _firstClaimer The initial claimer address.
  /// @param _newClaimer The new claimer address to be set.
  function testFuzz_DepositorCanUpdateClaimerBeforeAccruingRewards(
    address _depositor,
    uint96 _depositAmount,
    address _delegatee,
    address _firstClaimer,
    address _newClaimer
  ) public {
    _assumeNotZeroAddressOrStaker(_depositor);
    vm.assume(
      _firstClaimer != address(0) && _newClaimer != address(0) && _newClaimer != _firstClaimer
    );

    _depositAmount = uint96(_boundMintAmount(_depositAmount));
    _mintStakeToken(_depositor, _depositAmount);
    Staker.DepositIdentifier _depositId =
      _stake(_depositor, _depositAmount, _delegatee, _firstClaimer);
    _updateEarningPower(_depositId);

    Staker.Deposit memory _deposit = _fetchDeposit(_depositId);

    vm.expectEmit();
    emit Staker.ClaimerAltered(_depositId, _firstClaimer, _newClaimer, _deposit.earningPower);

    vm.prank(_depositor);
    staker.alterClaimer(_depositId, _newClaimer);

    _deposit = _fetchDeposit(_depositId);

    assertEq(staker.unclaimedReward(_depositId), 0);
    assertEq(_deposit.claimer, _newClaimer);
  }

  /// @notice Tests that a depositor can successfully update the claimer for their deposit after
  /// rewards have accrued. Verifies that `ClaimerAltered` event is emitted, the deposit's claimer
  /// is updated, and existing unclaimed rewards are maintained for the new claimer.
  /// @param _depositor The address of the staker.
  /// @param _depositAmount The amount of stake tokens deposited.
  /// @param _delegatee The initial delegatee address.
  /// @param _rewardAmount The total reward amount for the period.
  /// @param _percentDuration The percentage of the reward duration to advance time by before
  /// altering the claimer.
  /// @param _firstClaimer The initial claimer address.
  /// @param _newClaimer The new claimer address to be set.
  function testFuzz_DepositorCanUpdateClaimerAfterAccruingRewards(
    address _depositor,
    uint96 _depositAmount,
    address _delegatee,
    uint256 _rewardAmount,
    uint256 _percentDuration,
    address _firstClaimer,
    address _newClaimer
  ) public {
    _assumeNotZeroAddressOrStaker(_depositor);
    vm.assume(
      _firstClaimer != address(0) && _newClaimer != address(0) && _newClaimer != _firstClaimer
    );
    _percentDuration = bound(_percentDuration, 1, 100);
    _rewardAmount = _boundToRealisticReward(_rewardAmount);
    _depositAmount = uint96(_boundMintAmount(_depositAmount));
    // We assume the following to guarantee positive unclaimed reward.
    vm.assume(_depositAmount != 0 && _rewardAmount != 0);

    _mintStakeToken(_depositor, _depositAmount);
    Staker.DepositIdentifier _depositId =
      _stake(_depositor, _depositAmount, _delegatee, _firstClaimer);
    _updateEarningPower(_depositId);

    Staker.Deposit memory _deposit = _fetchDeposit(_depositId);

    _notifyRewardAmount(_rewardAmount);
    _jumpAheadByPercentOfRewardDuration(_percentDuration);

    vm.expectEmit();
    emit Staker.ClaimerAltered(_depositId, _firstClaimer, _newClaimer, _deposit.earningPower);

    vm.prank(_depositor);
    staker.alterClaimer(_depositId, _newClaimer);

    _deposit = _fetchDeposit(_depositId);

    assertGt(staker.unclaimedReward(_depositId), 0);
    assertEq(_deposit.claimer, _newClaimer);
  }
}

/// @title AlterDelegateeBase
/// @author [ScopeLift](https://scopelift.co)
/// @notice Provides a standard suite of tests for the `alterDelegatee` functionality.
/// This includes tests for updating the delegatee and verifying the correct transfer
/// of delegated stake/voting power.
/// @dev Inherit this contract to test the delegatee alteration mechanism of a Staker
/// implementation.
abstract contract AlterDelegateeBase is StakerTestBase {
  /// @notice Tests that a depositor can successfully update the delegatee for their deposit.
  /// Verifies that `DelegateeAltered` event is emitted, the deposit's delegatee is updated, and
  /// stake token balances of corresponding surrogates are correctly adjusted.
  /// @param _depositor The address of the staker.
  /// @param _depositAmount The amount of stake tokens deposited.
  /// @param _firstDelegatee The initial delegatee address.
  /// @param _newDelegatee The new delegatee address to be set.
  function testFuzz_DepositorCanUpdateDelegatee(
    address _depositor,
    uint96 _depositAmount,
    address _firstDelegatee,
    address _newDelegatee
  ) public {
    _assumeNotZeroAddressOrStaker(_depositor);
    vm.assume(
      _firstDelegatee != address(0) && _newDelegatee != address(0)
        && _newDelegatee != _firstDelegatee
    );

    _depositAmount = uint96(_boundMintAmount(_depositAmount));
    _mintStakeToken(_depositor, _depositAmount);
    Staker.DepositIdentifier _depositId = _stake(_depositor, _depositAmount, _firstDelegatee);
    _updateEarningPower(_depositId);
    address _firstSurrogate = address(staker.surrogates(_firstDelegatee));

    vm.expectEmit();
    emit Staker.DelegateeAltered(_depositId, _firstDelegatee, _newDelegatee, _depositAmount);

    vm.prank(_depositor);
    staker.alterDelegatee(_depositId, _newDelegatee);

    Staker.Deposit memory _deposit = _fetchDeposit(_depositId);
    address _newSurrogate = address(staker.surrogates(_deposit.delegatee));

    assertEq(_deposit.delegatee, _newDelegatee);
    assertEq(STAKE_TOKEN.balanceOf(_newSurrogate), _depositAmount);
    assertEq(STAKE_TOKEN.balanceOf(_firstSurrogate), 0);
  }
}

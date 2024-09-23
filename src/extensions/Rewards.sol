// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {UniStaker} from "src/UniStaker.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

abstract contract Rewards is UniStaker {
  /// @notice ERC20 token in which rewards are denominated and distributed.
  IERC20 public immutable REWARD_TOKEN;

  /// @notice Maps addresses to whether they are authorized to call `notifyRewardAmount`.
  mapping(address rewardNotifier => bool) public isRewardNotifier;

  /// @notice Emitted when a reward notifier address is enabled or disabled.
  event RewardNotifierSet(address indexed account, bool isEnabled);

  constructor(IERC20 _rewardToken,  address _admin) {
    REWARD_TOKEN = _rewardToken;
    _setAdmin(_admin);
  }

  /// @notice Set the admin address.
  /// @param _newAdmin Address of the new admin.
  /// @dev Caller must be the current admin.
  function setAdmin(address _newAdmin) external {
    _revertIfNotAdmin();
    _setAdmin(_newAdmin);
  }

  /// @notice Internal helper method which sets the admin address.
  /// @param _newAdmin Address of the new admin.
  function _setAdmin(address _newAdmin) internal {
    _revertIfAddressZero(_newAdmin);
    emit AdminSet(admin, _newAdmin);
    admin = _newAdmin;
  }

  /// @notice Internal helper method which reverts UniStaker__Unauthorized if the message sender is
  /// not the admin.
  function _revertIfNotAdmin() internal view {
    if (msg.sender != admin) revert UniStaker__Unauthorized("not admin", msg.sender);
  }




  /// @notice Enables or disables a reward notifier address.
  /// @param _rewardNotifier Address of the reward notifier.
  /// @param _isEnabled `true` to enable the `_rewardNotifier`, or `false` to disable.
  /// @dev Caller must be the current admin.
  function setRewardNotifier(address _rewardNotifier, bool _isEnabled) external {
    _revertIfNotAdmin();
    isRewardNotifier[_rewardNotifier] = _isEnabled;
    emit RewardNotifierSet(_rewardNotifier, _isEnabled);
  }

  /// @notice Claim reward tokens the message sender has earned as a stake beneficiary. Tokens are
  /// sent to the message sender.
  /// @return Amount of reward tokens claimed.
  function claimReward(DepositIdentifier _depositId) external returns (uint256) {
    Deposit storage deposit = deposits[_depositId];
    if (msg.sender != deposit.beneficiary) revert UniStaker__Unauthorized("not beneficiary", msg.sender);
    return _claimReward(_depositId);
  }

  function _claimReward(DepositIdentifier _depositId) internal returns (uint256) {
    Deposit storage deposit = deposits[_depositId];

    _checkpointGlobalReward();
    _checkpointReward(_depositId);

    uint256 _reward = deposit.scaledUnclaimedRewardCheckpoint / SCALE_FACTOR;
    if (_reward == 0) return 0;

    // retain sub-wei dust that would be left due to the precision loss
    deposit.scaledUnclaimedRewardCheckpoint =
      uint96(deposit.scaledUnclaimedRewardCheckpoint) - uint96(_reward * SCALE_FACTOR);
    emit RewardClaimed(_depositId, _reward);

    // Update the earning power. We don't have to do this but if we're working on the deposit, why
    // not? One awkward thing is that, as written, the beneficiary can claim the rewards, and can
    // be different from the owner. Presumably they must have some kind of trust relationship, but
    // it feels a little odd some entity other than the owner could cause the earning power to
    // drop.
    deposit.earningPower = earningPowerCalculator.getEarningPower(deposit.balance, deposit.owner, deposit.delegatee);

    SafeERC20.safeTransfer(REWARD_TOKEN, deposit.beneficiary, _reward);
    return _reward;
  }

  function notifyRewardAmount(uint256 _amount) external {
    if (!isRewardNotifier[msg.sender]) revert UniStaker__Unauthorized("not notifier", msg.sender);

    // We checkpoint the accumulator without updating the timestamp at which it was updated,
    // because that second operation will be done after updating the reward rate.
    rewardPerTokenAccumulatedCheckpoint = rewardPerTokenAccumulated();

    if (block.timestamp >= rewardEndTime) {
      scaledRewardRate = (_amount * SCALE_FACTOR) / REWARD_DURATION;
    } else {
      uint256 _remainingReward = scaledRewardRate * (rewardEndTime - block.timestamp);
      scaledRewardRate = (_remainingReward + _amount * SCALE_FACTOR) / REWARD_DURATION;
    }

    rewardEndTime = block.timestamp + REWARD_DURATION;
    lastCheckpointTime = block.timestamp;

    if ((scaledRewardRate / SCALE_FACTOR) == 0) revert UniStaker__InvalidRewardRate();

    // This check cannot _guarantee_ sufficient rewards have been transferred to the contract,
    // because it cannot isolate the unclaimed rewards owed to stakers left in the balance. While
    // this check is useful for preventing degenerate cases, it is not sufficient. Therefore, it is
    // critical that only safe reward notifier contracts are approved to call this method by the
    // admin.
    if (
      (scaledRewardRate * REWARD_DURATION) > (REWARD_TOKEN.balanceOf(address(this)) * SCALE_FACTOR)
    ) revert UniStaker__InsufficientRewardBalance();

    emit RewardNotified(_amount, msg.sender);
  }

  function forceUpdateEarningPower(DepositIdentifier _depositId, uint256 _tipRequested, address _tipReceiver) external {
    if (_tipRequested > maxEarningPowerUpdaterTip) revert("Invalid Tip"); // TODO: would have error type

    Deposit storage deposit = deposits[_depositId];

    // Checkpoint system so reward checkpoint is updated
    _checkpointGlobalReward();
    _checkpointReward(_depositId);

    (uint256 _newEarningPower, bool _isSignificantChange) = earningPowerCalculator.getNewEarningPower(deposit.balance, deposit.owner, deposit.delegatee, deposit.earningPower);
    if (!_isSignificantChange) revert("Insignificant Earning Power Change");

    uint256 _unclaimedRewards = deposit.scaledUnclaimedRewardCheckpoint / SCALE_FACTOR;

    if (_newEarningPower > deposit.earningPower && _unclaimedRewards < _tipRequested) {
      // If the staker's earning power is increasing, we make sure there are enough rewards to pay
      // the tip. Theoretically, we could do a more advanced calculation to decide if this is
      // "worth it" for the user to pay for. For example, we could calculate, based on the tip,
      // the current reward rate, and the user's change in earning power, how long it would take to
      // earn the tip back, and thus only allow this if the difference is within some threshold time,
      // e.g. a week or a day. This same calculation could also be implemented by the earning power
      // calculator though, so this simpler enforcement is probably fine for the core staker. Also,
      // none of this matters for a calculator that only returns a binary 0 earning power or full
      // earning power.
      revert("Insufficient Rewards To Pay Tip");
    } else if (_newEarningPower < deposit.earningPower && (_unclaimedRewards - _tipRequested) < maxEarningPowerUpdaterTip) {
      // If the staker's earning power is decreasing, we make sure there are enough rewards left
      // for at least one more forced adjustment paying the max tip. This means the deposit will
      // still have enough rewards left pay a tip that increases its earning power should the
      // delegatee improve. This includes if the score drops all the way to zero. We could be even
      // stricter here, and only require 2x tip if the new earning power IS 0. The current system
      // is a little nicer to stakers, in that it gives them more time to adjust should their
      // delegatee's earning power drop.
      revert("Insufficient Rewards To Pay Tip");
    }

    // update the earning power
    deposit.earningPower = _newEarningPower;
    // Update unclaimed rewards to remove tip (ignore casting issues, will all go to uint256)
    deposit.scaledUnclaimedRewardCheckpoint -= uint96(_tipRequested);

    // Send tip.
    SafeERC20.safeTransfer(REWARD_TOKEN, _tipReceiver, _tipRequested);
  }
}

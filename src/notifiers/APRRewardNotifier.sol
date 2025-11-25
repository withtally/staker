// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Staker} from "../Staker.sol";

/// @notice A reward notifier that will extend rewards over the
/// reward duration if rewards exceed a target APR. If rewards
/// are constantly below a fixed APR then we revert to a fixed
/// notification schedule.
///
/// @dev `RewardNotifierBase` expects a fixed reward interval and
/// a fixed amount.
contract APRRewardNotifier is Ownable {
  using SafeERC20 for IERC20;

  /// @notice Emitted when the target APR is changed.
  event TargetAPRSet(uint16 oldTargetAPR, uint16 newTargetAPR);

  /// @notice Emitted when the reward amount is changed.
  event RewardAmountSet(uint256 oldAmount, uint256 newAmount);

  /// @notice Emitted when the reward interval is changed.
  event RewardIntervalSet(uint256 oldInterval, uint256 newInterval);

  /// @notice Emitted when the max earning power token multiplier is changed.
  event MaxEarningPowerTokenMultiplierSet(uint16 oldMultiplier, uint16 newMultiplier);

  /// @notice Emitted when rewards are notified to the receiver.
  event Notified(uint256 amount, uint256 currentAPR, uint256 nextRewardTime);

  /// @notice Thrown when trying to notify before the interval has elapsed and APR is below
  /// target.
  error APRRewardNotifier__RewardIntervalNotElapsed();

  /// @notice Thrown when an invalid parameter is provided.
  error APRRewardNotifier__InvalidParameter();

  /// @notice Thrown when there is insufficient balance to notify rewards.
  error APRRewardNotifier__InsufficientBalance();

  /// @notice The contract that will receive reward notifications. Typically an instance of Staker.
  Staker public immutable RECEIVER;

  /// @notice The ERC20 token in which rewards are denominated.
  IERC20 public immutable TOKEN;

  /// @notice Seconds in a year for APR calculations.
  uint256 public constant SECONDS_PER_YEAR = 31_556_952;

  /// @notice Denominator for basis points calculations.
  uint16 public constant BIPS_DENOMINATOR = 10_000;

  /// @notice Minimum reward interval (1 day).
  uint256 public constant MIN_REWARD_INTERVAL = 1 days;

  /// @notice Maximum reward interval (365 days).
  uint256 public constant MAX_REWARD_INTERVAL = 365 days;

  /// @notice APR threshold in basis points.
  uint16 public targetAPR;

  /// @notice Max earning power to token multiplier in basis points.
  uint16 public maxEarningPowerTokenMultiplier;

  /// @notice The amount of reward tokens to be distributed at fixed intervals.
  uint256 public rewardAmount;

  /// @notice The interval between reward notifications.
  uint256 public rewardInterval;

  /// @notice The timestamp after which the next reward notification can be sent.
  uint256 public nextRewardTime;

  constructor(
    Staker _receiver,
    address _owner,
    uint16 _maxEarningPowerTokenMultiplier,
    uint16 _targetAPR,
    uint256 _rewardAmount,
    uint256 _rewardInterval
  ) Ownable(_owner) {
    if (address(_receiver) == address(0)) {
      revert APRRewardNotifier__InvalidParameter();
    }

    RECEIVER = _receiver;
    TOKEN = _receiver.REWARD_TOKEN();
    _setMaxEarningPowerTokenMultiplier(_maxEarningPowerTokenMultiplier);
    _setTargetAPR(_targetAPR);
    _setRewardAmount(_rewardAmount);
    _setRewardInterval(_rewardInterval);
  }

  /// @notice Calls `notifyRewardAmount` on `RECEIVER`. This function can be called anytime the
  /// APR has exceeded its target or when a fixed interval has occurred. When notifying the
  /// amount notified should not cause the APR to exceed the target. In the case the APR
  /// is above the target the amount can be as low as 0. This does not guarantee the APR is
  /// below the target. If it isn't then another notify can follow immediately after until
  /// it is. If the fixed interval has occurred and the APR is below the target, then the
  /// notifier can notify at most up to the target.
  function notify() external virtual {
    uint256 currentAPR = _calculateCurrentScaledAPR();
    uint256 amountToNotify = 0;

    if (currentAPR <= targetAPR && block.timestamp < nextRewardTime) {
      revert APRRewardNotifier__RewardIntervalNotElapsed();
    }

    // If APR is above target, we can notify immediately with 0 or minimal amount
    if (currentAPR > targetAPR) {
      // Notify with 0 to extend the reward duration without adding more rewards
      amountToNotify = _calculateRewardAmountForAPRTarget();
    }

    // If the fixed interval has elapsed
    if (block.timestamp >= nextRewardTime) {
      // Calculate the maximum amount we can notify without exceeding the target
      uint256 maxAllowableAmount = _calculateMaxNotifyAmount(currentAPR);
      amountToNotify = rewardAmount > maxAllowableAmount ? maxAllowableAmount : rewardAmount;
      nextRewardTime = block.timestamp + rewardInterval;
    }
    if (TOKEN.balanceOf(address(this)) < amountToNotify) {
      revert APRRewardNotifier__InsufficientBalance();
    }

	// Avoids revert in underlying staker if scaled reward rate is 0
    if (amountToNotify == 0 && (RECEIVER.scaledRewardRate() / RECEIVER.SCALE_FACTOR()) == 0) {
      return;
    }
    TOKEN.safeTransfer(address(RECEIVER), amountToNotify);

    // Notify the receiver
    RECEIVER.notifyRewardAmount(amountToNotify);
    emit Notified(amountToNotify, currentAPR, nextRewardTime);
  }

  /// @notice Set the target APR. This target should be denominated in BIPS. This is
  /// only callable by the owner.
  /// @param _targetAPR The new target APR in basis points.
  function setTargetAPR(uint16 _targetAPR) external virtual {
    _checkOwner();
    _setTargetAPR(_targetAPR);
  }

  /// @notice The interval between reward notifications outside of notifications to move
  /// the APR below the target.
  /// @param _rewardInterval The new reward interval in seconds.
  function setRewardInterval(uint256 _rewardInterval) external {
    _checkOwner();
    _setRewardInterval(_rewardInterval);
  }

  /// @notice The amount that can be notified at fixed intervals. If APR is always below the
  /// target then the max amount that can be notified over some period is the amount times
  /// the reward interval.
  /// @param _rewardAmount The new reward amount.
  function setRewardAmount(uint256 _rewardAmount) external {
    _checkOwner();
    _setRewardAmount(_rewardAmount);
  }

  /// @notice The owner can set a token multiple in bips.
  /// @param _multiple The new max earning power token multiplier in basis points.
  function setMaxEarningPowerTokenMultiplier(uint16 _multiple) external {
    _checkOwner();
    _setMaxEarningPowerTokenMultiplier(_multiple);
  }

  /// @notice Approve an address to transferFrom tokens held by this contract.
  /// @param _spender The address to approve for token spending.
  /// @param _amount The amount of tokens to approve.
  /// @dev This enables tokens to be clawed back to end rewards as desired.
  function approve(address _spender, uint256 _amount) external {
    _checkOwner();
    TOKEN.safeIncreaseAllowance(_spender, _amount);
  }

  /// @notice Get the current APR in basis points.
  /// @return The current APR in basis points.
  function getCurrentAPR() external view returns (uint256) {
    return _calculateCurrentScaledAPR();
  }

  /// @notice Calculate the maximum amount that can be notified without exceeding the target APR.
  /// @param _currentAPR The current APR in basis points.
  /// @return The maximum amount that can be notified.
  function _calculateMaxNotifyAmount(uint256 _currentAPR) internal view returns (uint256) {
    if (_currentAPR >= targetAPR) return 0;

    uint256 totalEarningPower = RECEIVER.totalEarningPower();
    if (totalEarningPower == 0) return rewardAmount;

    uint256 targetScaledRate = _targetScaledRewardRate(totalEarningPower);
    uint256 maxAmount =
      (targetScaledRate * RECEIVER.REWARD_DURATION()) / RECEIVER.SCALE_FACTOR();

    uint256 remainingRewards =
      _remainingScaledReward() / RECEIVER.SCALE_FACTOR();
    if (maxAmount > remainingRewards) return maxAmount - remainingRewards;
    return 0;
  }

  /// @notice How to calculate the current APR. The APR is scaled by the RECEIVER scale factor.
  /// @dev The APR = (scaledRewardRate / totalEarningPower) * maxEarningPowerToTokensMultiplier *
  /// SECONDS_PER_YEAR / BIPS_DENOMINATOR
  function _calculateCurrentScaledAPR() internal view returns (uint256) {
    uint256 _totalEarningPower = RECEIVER.totalEarningPower();
    if (_totalEarningPower == 0) return 0;

    return ((RECEIVER.scaledRewardRate()
          * uint256(maxEarningPowerTokenMultiplier)
          * SECONDS_PER_YEAR) / (_totalEarningPower * BIPS_DENOMINATOR));
  }

  function _calculateRewardAmountForAPRTarget() internal view returns (uint256) {
    uint256 _totalEarningPower = RECEIVER.totalEarningPower();
    if (_totalEarningPower == 0) return 0;

    uint256 targetScaledRewardRate = _targetScaledRewardRate(_totalEarningPower);
    uint256 targetScaledReward =
      targetScaledRewardRate * RECEIVER.REWARD_DURATION();
    uint256 remainingReward = _remainingScaledReward();
    if (targetScaledReward <= remainingReward) return 0;

    return (targetScaledReward - remainingReward) / RECEIVER.SCALE_FACTOR();
  }

  /// @notice Internal helper method which sets the target APR.
  /// @param _targetAPR The new target APR in basis points.
  function _setTargetAPR(uint16 _targetAPR) internal {
    if (_targetAPR == 0) revert APRRewardNotifier__InvalidParameter();
    emit TargetAPRSet(targetAPR, _targetAPR);
    targetAPR = _targetAPR;
  }

  /// @notice Internal helper method which sets the reward interval.
  /// @param _rewardInterval The new reward interval in seconds.
  function _setRewardInterval(uint256 _rewardInterval) internal {
    if (_rewardInterval < MIN_REWARD_INTERVAL || _rewardInterval > MAX_REWARD_INTERVAL) {
      revert APRRewardNotifier__InvalidParameter();
    }
    emit RewardIntervalSet(rewardInterval, _rewardInterval);
    rewardInterval = _rewardInterval;
  }

  /// @notice Internal helper method which sets the reward amount.
  /// @param _rewardAmount The new reward amount.
  function _setRewardAmount(uint256 _rewardAmount) internal {
    if (_rewardAmount == 0) revert APRRewardNotifier__InvalidParameter();
    emit RewardAmountSet(rewardAmount, _rewardAmount);
    rewardAmount = _rewardAmount;
  }

  /// @notice Internal helper method which sets the max earning power token multiplier.
  /// @param _multiple The new max earning power token multiplier in basis points.
  function _setMaxEarningPowerTokenMultiplier(uint16 _multiple) internal {
    if (_multiple == 0) revert APRRewardNotifier__InvalidParameter();
    emit MaxEarningPowerTokenMultiplierSet(maxEarningPowerTokenMultiplier, _multiple);
    maxEarningPowerTokenMultiplier = _multiple;
  }

  function _targetScaledRewardRate(uint256 _totalEarningPower) internal view returns (uint256) {
    return (uint256(targetAPR) * _totalEarningPower * BIPS_DENOMINATOR)
      / (uint256(maxEarningPowerTokenMultiplier) * SECONDS_PER_YEAR);
  }

  function _remainingScaledReward() internal view returns (uint256) {
    uint256 rewardEndTime = RECEIVER.rewardEndTime();
    if (block.timestamp >= rewardEndTime) return 0;
    return RECEIVER.scaledRewardRate() * (rewardEndTime - block.timestamp);
  }
}

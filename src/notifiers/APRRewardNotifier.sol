// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Staker} from "../Staker.sol";

/// @title APR Reward Notifier
/// @author ScopeLift
/// @notice Manages staking rewards to maintain a target Annual Percentage Rate (APR)
/// @dev This contract acts as a reward notifier for a Staker contract, automatically
/// adjusting reward distributions to maintain a target APR. It monitors the current APR
/// and can increase or decrease reward rates to converge towards the target.
/// The contract uses basis points (10,000 = 100%) for APR representation and includes
/// role-based access control for administrative functions.
contract APRRewardNotifier is AccessControl {
  using SafeERC20 for IERC20;

  /// @notice Emitted when a reward notification is sent to the receiver.
  /// @param amount The amount of reward tokens notified.
  /// @param previousAPR The previous APR before the notification (in basis points).
  event Notified(uint256 amount, uint256 previousAPR);

  /// @notice Emitted when the max earning power token multiplier is updated.
  /// @param oldMultiplier The previous multiplier value (in basis points).
  /// @param newMultiplier The new multiplier value (in basis points).
  event MaxEarningPowerTokenMultiplierSet(uint16 oldMultiplier, uint16 newMultiplier);

  /// @notice Emitted when the target APR is updated.
  /// @param oldTargetAPR The previous target APR (in basis points).
  /// @param newTargetAPR The new target APR (in basis points).
  event TargetAPRSet(uint16 oldTargetAPR, uint16 newTargetAPR);

  /// @notice Thrown when a parameter value is invalid (e.g., zero when non-zero required).
  error APRRewardNotifier__InvalidParameter();

  /// @notice Thrown when APR adjustment is attempted but APR is already on the correct side of
  /// target.
  error APRRewardNotifier__APROffTarget();

  /// @notice The Staker contract that receives reward notifications.
  Staker public immutable RECEIVER;

  /// @notice The ERC20 token used for rewards.
  IERC20 public immutable REWARD_TOKEN;

  /// @notice Basis points denominator (10,000 = 100%).
  uint16 public constant BIPS_DENOMINATOR = 10_000;

  /// @notice Role identifier for addresses allowed to trigger notifications.
  bytes32 public constant NOTIFIER_ROLE = keccak256("NOTIFIER");

  /// @notice Number of seconds in a year for APR calculations.
  /// @dev Using 365 days: 365 * 24 * 60 * 60
  uint256 public constant SECONDS_PER_YEAR = 31_536_000;

  /// @notice Maximum ratio of earning power to staked tokens (in basis points).
  /// @dev Used to calculate the effective APR based on maximum possible earning power.
  /// For example, 10,000 means 1:1 ratio (100%), 5,000 means 0.5:1 ratio (50%).
  uint16 public maxEarningPowerTokenMultiplier;

  /// @notice Target APR to maintain (in basis points).
  /// @dev 1000 = 10% APR, 10000 = 100% APR.
  uint16 public targetAPR;

  /// @notice Initializes the APR Reward Notifier.
  /// @param _receiver The Staker contract that will receive reward notifications.
  /// @param _rewardToken The ERC20 token to be used as rewards.
  /// @param _multiple The initial max earning power token multiplier (in basis points).
  /// @param _owner The address that will have admin and notifier roles.
  /// @dev Grants both `DEFAULT_ADMIN_ROLE` and `NOTIFIER_ROLE` to the owner.
  constructor(Staker _receiver, IERC20 _rewardToken, uint16 _multiple, address _owner) {
    RECEIVER = _receiver;
    REWARD_TOKEN = _rewardToken;

    _setMaxEarningPowerTokenMultiplier(_multiple);
    _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    _grantRole(NOTIFIER_ROLE, _owner);
  }

  /// @notice Notifies a reward decrease to lower the current APR towards the target.
  /// @dev Reverts if current APR is already at or below the target.
  /// Calculates the exact reward amount needed to achieve the target APR
  /// and transfers it to the receiver contract.
  function notifyDecrease() external virtual {
    _checkRole(NOTIFIER_ROLE, msg.sender);
    uint256 _currentAPR =  getCurrentAPR();
    // Calculate how to raise the apr
    if (_currentAPR <= targetAPR) revert APRRewardNotifier__APROffTarget();
    uint256 _targetScaledRate = _targetScaledRewardRate();
    uint256 _maxRewardAmount =
      (_targetScaledRate * RECEIVER.REWARD_DURATION()) / RECEIVER.SCALE_FACTOR();
    uint256 _remainingRewards = _remainingScaledReward() / RECEIVER.SCALE_FACTOR();

    uint256 _amountToNotify =
      (_maxRewardAmount > _remainingRewards) ? _maxRewardAmount - _remainingRewards : 0;

    REWARD_TOKEN.safeTransfer(address(RECEIVER), _amountToNotify);

    RECEIVER.notifyRewardAmount(_amountToNotify);
    emit Notified(_amountToNotify, _currentAPR);
  }

  /// @notice Notifies a reward increase to raise the current APR towards the target.
  /// @dev Reverts if current APR is already at or above the target.
  /// Calculates the additional reward amount needed to achieve the target APR
  /// and transfers it to the receiver contract.
  function notifyIncrease() external virtual {
    _checkRole(NOTIFIER_ROLE, msg.sender);
    uint256 _currentAPR = getCurrentAPR();
    // Calculate how to raise the apr
    if (_currentAPR >= targetAPR) revert APRRewardNotifier__APROffTarget();
    uint256 _targetScaledRate = _targetScaledRewardRate();
    uint256 _maxRewardAmount =
      (_targetScaledRate * RECEIVER.REWARD_DURATION()) / RECEIVER.SCALE_FACTOR();
    uint256 _remainingRewards = _remainingScaledReward() / RECEIVER.SCALE_FACTOR();

    uint256 _amountToNotify = _maxRewardAmount - _remainingRewards;

    REWARD_TOKEN.safeTransfer(address(RECEIVER), _amountToNotify);

    RECEIVER.notifyRewardAmount(_amountToNotify);
    emit Notified(_amountToNotify, _currentAPR);
  }

  /// @notice Updates the maximum earning power token multiplier.
  /// @param _multiple The new multiplier value (in basis points, must be non-zero).
  /// @dev Only callable by addresses with `DEFAULT_ADMIN_ROLE`.
  /// This affects how APR is calculated based on the maximum possible earning power.
  function setMaxEarningPowerTokenMultiplier(uint16 _multiple) external {
    _checkRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setMaxEarningPowerTokenMultiplier(_multiple);
  }

  /// @notice Updates the target APR that the notifier will try to maintain.
  /// @param _targetAPR The new target APR (in basis points, must be non-zero).
  /// @dev Only callable by addresses with DEFAULT_ADMIN_ROLE.
  /// 100 = 1% APR, 1000 = 10% APR, 10000 = 100% APR.
  function setTargetAPR(uint16 _targetAPR) external virtual {
    _checkRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setTargetAPR(_targetAPR);
  }

  /// @notice Returns the current APR of the staking rewards.
  /// @return The current APR in basis points (10000 = 100%).
  /// @dev This is a convenience function that exposes the internal calculation.
  function getCurrentAPR() public view returns (uint256) {
    return _currentScaledAPR() / RECEIVER.SCALE_FACTOR();
  }

  /// @notice Checks if the current APR is above the target.
  /// @return True if current APR exceeds target, false otherwise.
  function isAPRAboveTarget() external view returns (bool) {
    return _currentScaledAPR() > targetAPR;
  }

  /// @notice Checks if the current APR is below the target.
  /// @return True if current APR is below target, false otherwise.
  function isAPRBelowTarget() external view returns (bool) {
    return _currentScaledAPR() < targetAPR;
  }

  /// @notice Calculates the current APR based on the reward rate and earning power.
  /// @return The current APR in basis points (10000 = 100%).
  /// @dev Returns 0 if there is no earning power.
  /// Uses the scaled reward rate from the receiver to maintain precision.
  function _currentScaledAPR() internal view returns (uint256) {
    uint256 _totalEarningPower = RECEIVER.totalEarningPower();
    if (_totalEarningPower == 0) return 0;

    return ((RECEIVER.scaledRewardRate()
          * uint256(maxEarningPowerTokenMultiplier)
          * SECONDS_PER_YEAR) / (_totalEarningPower * BIPS_DENOMINATOR));
  }

  /// @notice Calculates the total remaining reward amount to be distributed.
  /// @return The remaining reward amount (scaled by SCALE_FACTOR for precision).
  /// @dev Returns 0 if the reward period has ended.
  function _remainingScaledReward() internal view returns (uint256) {
    uint256 _rewardEndTime = RECEIVER.rewardEndTime();
    if (block.timestamp >= _rewardEndTime) return 0;
    return RECEIVER.scaledRewardRate() * (_rewardEndTime - block.timestamp);
  }

  /// @notice Internal function to set the max earning power token multiplier.
  /// @param _multiple The new multiplier value (must be non-zero).
  /// @dev Reverts if _multiple is 0, emits MaxEarningPowerTokenMultiplierSet event.
  function _setMaxEarningPowerTokenMultiplier(uint16 _multiple) internal {
    if (_multiple == 0) revert APRRewardNotifier__InvalidParameter();
    emit MaxEarningPowerTokenMultiplierSet(maxEarningPowerTokenMultiplier, _multiple);
    maxEarningPowerTokenMultiplier = _multiple;
  }

  /// @notice Internal function to set the target APR.
  /// @param _targetAPR The new target APR value (must be non-zero).
  /// @dev Reverts if _targetAPR is 0, emits TargetAPRSet event.
  function _setTargetAPR(uint16 _targetAPR) internal {
    if (_targetAPR == 0) revert APRRewardNotifier__InvalidParameter();
    emit TargetAPRSet(targetAPR, _targetAPR);
    targetAPR = _targetAPR;
  }

  /// @notice Calculates the reward rate needed to achieve the target APR.
  /// @return The target reward rate (scaled by SCALE_FACTOR for precision).
  /// @dev Returns 0 if there is no earning power.
  /// The calculation accounts for the max earning power multiplier to determine
  /// the effective reward rate needed.
  function _targetScaledRewardRate() internal view returns (uint256) {
    uint256 _totalEarningPower = RECEIVER.totalEarningPower();
    if (_totalEarningPower == 0) return 0;
    return (uint256(targetAPR)
        * _totalEarningPower
        * uint256(maxEarningPowerTokenMultiplier)
        * RECEIVER.SCALE_FACTOR()) / (BIPS_DENOMINATOR * SECONDS_PER_YEAR);
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Staker} from "../Staker.sol";

/// @notice A reward notifier that will extend rewards over the
/// reward duration if rewards exceed a target APR. If rewwards
/// are constantly below a fixed APR then we revert to a fixed
/// notification schedule.
///
/// @dev `RewwardNotifierBase` expects a fixed reward interval and
/// a fixed amount.
contract APRRewardNotifier is Ownable {
  /// @notice The contract that will receive reward notifications. Typically an instance of Staker.
  Staker public immutable RECEIVER;

  uint16 maxEarningPowerTokenMultiplier;

  uint256 SECONDS_PER_YEAR = 31556952;

  /// @notice The ERC20 token in which rewards are denominated.
  IERC20 public immutable TOKEN;

  constructor(Staker _receiver, address _owner, uint16 _maxEarningPowerTokenMultiplier) Ownable(_owner) {
    RECEIVER = _receiver;
    TOKEN = _receiver.REWARD_TOKEN();
	maxEarningPowerTokenMultiplier = _maxEarningPowerTokenMultiplier;
  }

  /// @notice Calls `notifyRewardAmount` on `RECEIVER`. This function can be called anytime the 
  /// APR has exceed it's threshold or when a fixed interval has occurred. When notifying the
  /// amount notified should not cause the APR to exceed the threshold. In the case the APR
  /// is above the threshold the amount can be as low as 0. This does not gurantee the apr is
  /// below the threshold. If it isn't then another notify can follow immediately after until 
  /// it is. If the fixed interval has occured and the APR is below the threshold, then the
  /// notifier can notify at most up to the threshold.
  function notify() external virtual {}

  /// @notice Set the APR threshold this threshold should be denominated in BIPS. This is 
  /// only callable by the owner
  function setAPRThreshold() external virtual {}

  /// @notice The interval between reward notifications outside of notifications to move
  /// the APR below some threshold.
  function setRewardInterval() external {}

  /// @notice The amount that can be notified at fixed intervals. If APR is always below the
  /// threshold then the max amount that can be notified over some period is the amount times
  /// the reward interval.
  function setRewardAmount() external {}

  /// @notice The owner can set a token multiple in bips
  function setMaxEarningPowerTokenMultiplier(uint16 _multiple) external {}

  /// @notice The denominator for BIPS calculations
  function _denominator() internal returns (uint16) {}

  /// @notice How to calculate the current APR. The APR is scaled by the RECEIVER scale factor.
  /// @dev The APR = (scaledRewardRate / totalEarninPower) * maxEarningPowerToTokensMultiplier * SECONDS_PER_YEAR
  function _calculateCurrentScaledAPR() internal returns (uint256) {
		  return ((RECEIVER.scaledRewardRate() / RECEIVER.totalEarningPower()) * maxEarningPowerTokenMultiplier * SECONDS_PER_YEAR) / _denominator();
  }
}

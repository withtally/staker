// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver, IERC20} from "../interfaces/INotifiableRewardReceiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title RewardTokenNotifierBase
/// @author [ScopeLift](https://scopelift.co)
/// @notice An abstract reward notifier contract for managing the distribution of rewards to Staker
/// instances.
///
/// Specifically, this base contract manages the details of directly distributing tokens
/// of the same type as the reward token. In other words, value does not need to be converted in
/// any way from one type of token to the reward token, rather reward tokens are simply moved to
/// Staker instance.
///
/// The contract is not opinionated about how the tokens are "moved" to the notifier. Inheriting
/// contracts must implement the `_sendTokensToReceiver` method to effectuate the movement of the
/// reward tokens using whatever mechanic is desired. The implementation must ensure that exactly
/// rewardAmount tokens are moved to the receiver.
///
/// The contract enforces a minimum interval between reward notifications. The contract ensures
/// that a set amount of reward tokens are distributed each time. These parameters are updatable by
/// the contract owner, which will presumably be the DAO itself in most instances.
abstract contract RewardTokenNotifierBase is Ownable {
  /// @notice Emitted when the reward amount is changed.
  /// @param oldRewardAmount The previous reward amount.
  /// @param newRewardAmount The new reward amount.
  event RewardAmountSet(uint256 oldRewardAmount, uint256 newRewardAmount);

  /// @notice Emitted when the reward interval is changed.
  /// @param oldRewardAmount The previous reward interval duration.
  /// @param newRewardAmount The new reward interval duration.
  event RewardIntervalSet(uint256 oldRewardAmount, uint256 newRewardAmount);

  /// @notice Emitted when rewards are distributed to the receiver.
  /// @param rewardAmount The amount of rewards that were distributed.
  /// @param nextRewardTime The timestamp after which the next reward can be distributed.
  event Notified(uint256 rewardAmount, uint256 nextRewardTime);

  /// @notice Thrown if a caller attempts to notify rewards before the reward interval has elapsed.
  error RewardTokenNotifierBase__RewardIntervalNotElapsed();

  error RewardTokenNotifierBase__InvalidParameter();

  /// @notice The contract that will receive reward notifications. Typically an instance of Staker.
  INotifiableRewardReceiver public immutable RECEIVER;

  /// @notice The ERC20 token in which rewards are denominated.
  IERC20 public immutable TOKEN;

  /// @notice The minimum value to which the reward interval can be set.
  /// @dev If an inheriting contract wants to allow for a shorter reward interval, this value can be
  /// overwritten explicitly by the inheriting contract in its own constructor.
  uint256 public immutable MIN_REWARD_INTERVAL = 1 days;

  /// @notice The maximum value to which the reward interval can be set.
  /// @dev If an inheriting contract wants to allow for a longer reward interval, this value can be
  /// overwritten explicitly by the inheriting contract in its own constructor.
  uint256 public immutable MAX_REWARD_INTERVAL = 365 days;

  /// @notice The amount of reward tokens to be distributed in each notification.
  uint256 public rewardAmount;

  /// @notice The minimum time that must elapse between reward notifications.
  uint256 public rewardInterval;

  /// @notice The timestamp after which the next reward notification can be sent.
  uint256 public nextRewardTime = 0;

  /// @param _receiver The contract that will receive reward notifications. Typically an instance
  /// of Staker.
  /// @param _initialRewardAmount The initial amount of reward tokens to be distributed per
  /// notification.
  /// @param _initialRewardInterval The initial minimum time that must elapse between
  /// notifications.
  /// @dev Care must be taken when initializing a reward interval, because the interval until the
  /// next notification is saved at the time a `notify` is called. This means, if an unacceptably
  /// long reward time is set, the tokens must be revoked and a new notifier must be deployed to
  /// resolve the problem.
  constructor(
    INotifiableRewardReceiver _receiver,
    uint256 _initialRewardAmount,
    uint256 _initialRewardInterval
  ) {
    RECEIVER = _receiver;
    TOKEN = _receiver.REWARD_TOKEN();
    _setRewardAmount(_initialRewardAmount);
    _setRewardInterval(_initialRewardInterval);
  }

  /// @notice Notifies the receiver contract of a new reward, sending the reward tokens and
  /// triggering the distribution of those tokens to stakers.
  /// @dev The reward interval must have elapsed since the last notification.
  /// @dev The tokens are "sent" to the receiver contract using whatever mechanism is implemented
  /// in the `_sendTokensToReceiver` method.
  function notify() external virtual {
    if (block.timestamp < nextRewardTime) {
      revert RewardTokenNotifierBase__RewardIntervalNotElapsed();
    }

    nextRewardTime = block.timestamp + rewardInterval;
    _sendTokensToReceiver();
    RECEIVER.notifyRewardAmount(rewardAmount);
    emit Notified(rewardAmount, nextRewardTime);
  }

  /// @notice Sets a new reward amount to be used in future notifications.
  /// @param _newRewardAmount The new amount of reward tokens to distribute per notification.
  /// @dev Caller must be the contract owner.
  function setRewardAmount(uint256 _newRewardAmount) external virtual {
    _checkOwner();
    _setRewardAmount(_newRewardAmount);
  }

  /// @notice Sets a new reward interval to be used between future notifications.
  /// @param _newRewardInterval The new minimum time that must elapse between notifications.
  /// @dev Caller must be the contract owner.
  /// @dev Care must be taken when setting a reward interval, because the interval until the next
  /// notification is saved at the time a `notify` is called. This means, if an unacceptably long
  /// reward time is set, the tokens must be revoked and a new notifier must be deployed to resolve
  /// the problem.
  function setRewardInterval(uint256 _newRewardInterval) external virtual {
    _checkOwner();
    _setRewardInterval(_newRewardInterval);
  }

  /// @notice Internal helper method which sets a new reward amount.
  /// @param _newRewardAmount The new amount of reward tokens to distribute per notification.
  function _setRewardAmount(uint256 _newRewardAmount) internal {
    if (_newRewardAmount == 0) revert RewardTokenNotifierBase__InvalidParameter();

    emit RewardAmountSet(rewardAmount, _newRewardAmount);
    rewardAmount = _newRewardAmount;
  }

  /// @notice Internal helper method which sets a new reward interval.
  /// @param _newRewardInterval The new minimum time that must elapse between notifications.
  function _setRewardInterval(uint256 _newRewardInterval) internal {
    if (_newRewardInterval < MIN_REWARD_INTERVAL || _newRewardInterval > MAX_REWARD_INTERVAL) {
      revert RewardTokenNotifierBase__InvalidParameter();
    }

    emit RewardIntervalSet(rewardInterval, _newRewardInterval);
    rewardInterval = _newRewardInterval;
  }

  /// @notice Internal abstract method which must be implemented by inheritors to send tokens
  /// to the receiver contract.
  /// @dev This method will be called before the receiver is notified of new rewards. The
  /// implementation must ensure that exactly rewardAmount tokens are moved to the receiver.
  function _sendTokensToReceiver() internal virtual;
}

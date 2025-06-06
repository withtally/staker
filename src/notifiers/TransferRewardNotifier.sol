// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver, IERC20} from "../interfaces/INotifiableRewardReceiver.sol";
import {RewardTokenNotifierBase} from "../notifiers/RewardTokenNotifierBase.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title TransferRewardNotifier
/// @author [ScopeLift](https://scopelift.co)
/// @notice A reward notifier that uses ERC20 transfer to move reward tokens from this contract's
/// balance to the Staker contract. This implementation is suitable when reward tokens are held
/// directly by the notifier contract itself, rather than being transferred from a separate source.
///
/// The contract allows the owner to configure the reward parameters (amount and interval). The
/// contract must maintain a sufficient balance of reward tokens for distributions to succeed.
contract TransferRewardNotifier is RewardTokenNotifierBase {
  using SafeERC20 for IERC20;

  /// @param _receiver The contract that will receive reward notifications, typically an instance
  /// of Staker.
  /// @param _initialRewardAmount The initial amount of reward tokens to be distributed per
  /// notification.
  /// @param _initialRewardInterval The initial minimum time that must elapse between
  /// notifications.
  /// @param _initialOwner The address that will have permission to update contract parameters.
  constructor(
    INotifiableRewardReceiver _receiver,
    uint256 _initialRewardAmount,
    uint256 _initialRewardInterval,
    address _initialOwner
  )
    RewardTokenNotifierBase(_receiver, _initialRewardAmount, _initialRewardInterval)
    Ownable(_initialOwner)
  {}

  /// @notice Approves an address to transferFrom tokens held by this contract.
  /// @param _spender The address to approve for token spending.
  /// @param _amount The amount of tokens to approve.
  /// @dev Caller must be the contract owner. This enables tokens to be clawed back to end rewards
  /// as desired.
  function approve(address _spender, uint256 _amount) external {
    _checkOwner();
    TOKEN.safeIncreaseAllowance(_spender, _amount);
  }

  /// @inheritdoc RewardTokenNotifierBase
  /// @dev Transfers exactly rewardAmount tokens from this contract's balance to the receiver
  /// using transfer. This contract must have a sufficient balance of reward tokens for the
  /// transfer to succeed.
  function _sendTokensToReceiver() internal virtual override {
    TOKEN.safeTransfer(address(RECEIVER), rewardAmount);
  }
}

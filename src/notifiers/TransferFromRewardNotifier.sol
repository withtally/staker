// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver, IERC20} from "src/interfaces/INotifiableRewardReceiver.sol";
import {RewardTokenNotifierBase} from "src/notifiers/RewardTokenNotifierBase.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

/// @title TransferFromRewardNotifier
/// @author [ScopeLift](https://scopelift.co)
/// @notice A reward notifier that uses ERC20 transferFrom to move reward tokens from a designated
/// source address to the Staker contract. This implementation is suitable when reward tokens are
/// held by a separate address (like a treasury) that has approved this contract to spend tokens
/// on its behalf.
///
/// The contract allows the owner to configure both the reward parameters (amount and interval) as
/// well as the source address from which rewards will be transferred. The source address must
/// approve this contract to spend reward tokens before rewards can be distributed.
contract TransferFromRewardNotifier is RewardTokenNotifierBase {
  using SafeERC20 for IERC20;

  /// @notice Emitted when the reward source address is changed.
  /// @param oldRewardSource The previous address expected to provide reward tokens.
  /// @param newRewardSource The new address expected to provide reward tokens.
  event RewardSourceSet(address oldRewardSource, address newRewardSource);

  /// @notice The address from which reward tokens will be transferred when distributing rewards.
  address public rewardSource;

  /// @param _receiver The contract that will receive reward notifications, typically an instance
  /// of Staker.
  /// @param _initialRewardAmount The initial amount of reward tokens to be distributed per
  /// notification.
  /// @param _initialRewardInterval The initial minimum time that must elapse between
  /// notifications.
  /// @param _initialOwner The address that will have permission to update contract parameters.
  /// @param _initialRewardSource The initial address from which rewards will be transferred.
  constructor(
    INotifiableRewardReceiver _receiver,
    uint256 _initialRewardAmount,
    uint256 _initialRewardInterval,
    address _initialOwner,
    address _initialRewardSource
  )
    RewardTokenNotifierBase(_receiver, _initialRewardAmount, _initialRewardInterval)
    Ownable(_initialOwner)
  {
    _setRewardSource(_initialRewardSource);
  }

  /// @notice Sets a new address from which reward tokens will be transferred.
  /// @param _newRewardSource The new address that will provide reward tokens.
  /// @dev Caller must be the contract owner. The new source address must approve this contract
  /// to spend reward tokens before rewards can be distributed.
  function setRewardSource(address _newRewardSource) external {
    _checkOwner();
    _setRewardSource(_newRewardSource);
  }

  /// @notice Internal helper method which sets a new reward source address.
  /// @param _newRewardSource The new address that will provide reward tokens.
  function _setRewardSource(address _newRewardSource) internal {
    emit RewardSourceSet(rewardSource, _newRewardSource);
    rewardSource = _newRewardSource;
  }

  /// @inheritdoc RewardTokenNotifierBase
  /// @dev Transfers exactly rewardAmount tokens from the rewardSource address to the receiver
  /// using transferFrom. The rewardSource must have approved this contract to spend at least
  /// rewardAmount tokens.
  function _sendTokensToReceiver() internal virtual override {
    TOKEN.transferFrom(rewardSource, address(RECEIVER), rewardAmount);
  }
}

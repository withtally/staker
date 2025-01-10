// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver} from "src/interfaces/INotifiableRewardReceiver.sol";
import {IMintable} from "src/interfaces/IMintable.sol";
import {RewardTokenNotifierBase} from "src/notifiers/RewardTokenNotifierBase.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

/// @title MintRewardNotifier
/// @author [ScopeLift](https://scopelift.co)
/// @notice A reward notifier that uses a minting mechanism to create new reward tokens and send
/// them directly to the Staker contract. This implementation is suitable when reward tokens can be
/// minted on demand, such as when distributing inflationary issuance as a reward.
///
/// The contract allows the owner to configure both the reward parameters (amount and interval) as
/// well as the minter contract that will create new tokens. The minter must implement the
/// IMintable interface and grant this contract permission to mint tokens.
contract MintRewardNotifier is RewardTokenNotifierBase {
  /// @notice Emitted when the minter contract is changed.
  /// @param oldMinter The previous contract authorized to mint reward tokens.
  /// @param newMinter The new contract authorized to mint reward tokens.
  event MinterSet(IMintable oldMinter, IMintable newMinter);

  /// @notice The contract authorized to mint new reward tokens. This can be the token itself, or a
  /// permissioned minter contract that operates on the token to create new issuance.
  IMintable public minter;

  /// @param _receiver The contract that will receive reward notifications, typically an instance
  /// of Staker.
  /// @param _initialRewardAmount The initial amount of reward tokens to be distributed per
  /// notification.
  /// @param _initialRewardInterval The initial minimum time that must elapse between
  /// notifications.
  /// @param _initialOwner The address that will have permission to update contract parameters.
  /// @param _minter The initial contract authorized to mint reward tokens.
  constructor(
    INotifiableRewardReceiver _receiver,
    uint256 _initialRewardAmount,
    uint256 _initialRewardInterval,
    address _initialOwner,
    IMintable _minter
  )
    RewardTokenNotifierBase(_receiver, _initialRewardAmount, _initialRewardInterval)
    Ownable(_initialOwner)
  {
    _setMinter(_minter);
  }

  /// @notice Sets a new contract to call when minting reward tokens.
  /// @param _minter The new contract authorized to mint reward tokens.
  /// @dev Caller must be the contract owner. The new minter must grant this contract permission
  /// to mint tokens before rewards can be distributed.
  function setMinter(IMintable _minter) external {
    _checkOwner();
    _setMinter(_minter);
  }

  /// @notice Internal helper method which sets a new minter contract.
  /// @param _newMinter The new contract authorized to mint reward tokens.
  function _setMinter(IMintable _newMinter) internal {
    emit MinterSet(minter, _newMinter);
    minter = _newMinter;
  }

  /// @inheritdoc RewardTokenNotifierBase
  /// @notice Mints exactly rewardAmount tokens directly to the receiver using the minter contract.
  /// @dev The minter must have granted this contract permission to mint tokens.
  /// @dev The call to `mint` **must revert** if it fails to provide tokens to the receiver.
  function _sendTokensToReceiver() internal virtual override {
    minter.mint(address(RECEIVER), rewardAmount);
  }
}

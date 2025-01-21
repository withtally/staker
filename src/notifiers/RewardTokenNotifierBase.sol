// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver, IERC20} from "src/interfaces/INotifiableRewardReceiver.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

abstract contract RewardTokenNotifierBase is Ownable {
  event RewardAmountSet(uint256 oldRewardAmount, uint256 newRewardAmount);
  event RewardIntervalSet(uint256 oldRewardAmount, uint256 newRewardAmount);
  event Notified(uint256 rewardAmount, uint256 nextRewardTime);

  error RewardTokenNotifierBase__RewardIntervalNotElapsed();

  INotifiableRewardReceiver public immutable RECEIVER;
  IERC20 public immutable TOKEN;

  uint256 public rewardAmount;
  uint256 public rewardInterval;
  uint256 public nextRewardTime = 0;

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

  function notify() external virtual {
    if (block.timestamp < nextRewardTime) {
      revert RewardTokenNotifierBase__RewardIntervalNotElapsed();
    }

    nextRewardTime = block.timestamp + rewardInterval;
    _sendTokensToReceiver();
    RECEIVER.notifyRewardAmount(rewardAmount);
    emit Notified(rewardAmount, nextRewardTime);
  }

  function setRewardAmount(uint256 _newRewardAmount) external virtual {
    _checkOwner();
    _setRewardAmount(_newRewardAmount);
  }

  function setRewardInterval(uint256 _newRewardInterval) external virtual {
    _checkOwner();
    _setRewardInterval(_newRewardInterval);
  }

  function _setRewardAmount(uint256 _newRewardAmount) internal {
    emit RewardAmountSet(rewardAmount, _newRewardAmount);
    rewardAmount = _newRewardAmount;
  }

  function _setRewardInterval(uint256 _newRewardInterval) internal {
    emit RewardIntervalSet(rewardInterval, _newRewardInterval);
    rewardInterval = _newRewardInterval;
  }

  function _sendTokensToReceiver() internal virtual;
}

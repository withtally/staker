// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver, IERC20} from "src/interfaces/INotifiableRewardReceiver.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract TransferFromRewardNotifier is Ownable {
  event RewardAmountSet(uint256 oldRewardAmount, uint256 newRewardAmount);
  event RewardIntervalSet(uint256 oldRewardAmount, uint256 newRewardAmount);
  event RewardSourceSet(address oldRewardSource, address newRewardSource);
  event Notified(uint256 rewardAmount, uint256 nextRewardTime);

  error TransferFromRewardNotifier__RewardIntervalNotElapsed();

  INotifiableRewardReceiver public immutable RECEIVER;
  IERC20 public immutable TOKEN;

  uint256 public rewardAmount;
  uint256 public rewardInterval;
  address public rewardSource;
  uint256 public nextRewardTime = 0;

  constructor(
    INotifiableRewardReceiver _receiver,
    uint256 _initialRewardAmount,
    uint256 _initialRewardInterval,
    address _initialRewardSource,
    address _initialOwner
  ) Ownable(_initialOwner) {
    RECEIVER = _receiver;
    TOKEN = _receiver.REWARD_TOKEN();
    _setRewardAmount(_initialRewardAmount);
    _setRewardInterval(_initialRewardInterval);
    _setRewardSource(_initialRewardSource);
  }

  function notify() external {
    if (block.timestamp < nextRewardTime) {
      revert TransferFromRewardNotifier__RewardIntervalNotElapsed();
    }

    nextRewardTime = block.timestamp + rewardInterval;
    SafeERC20.safeTransferFrom(TOKEN, rewardSource, address(RECEIVER), rewardAmount);
    RECEIVER.notifyRewardAmount(rewardAmount);
    emit Notified(rewardAmount, nextRewardTime);
  }

  function setRewardAmount(uint256 _newRewardAmount) external {
    _checkOwner();
    _setRewardAmount(_newRewardAmount);
  }

  function setRewardInterval(uint256 _newRewardInterval) external {
    _checkOwner();
    _setRewardInterval(_newRewardInterval);
  }

  function setRewardSource(address _newRewardSource) external {
    _checkOwner();
    _setRewardSource(_newRewardSource);
  }

  function _setRewardAmount(uint256 _newRewardAmount) internal {
    emit RewardAmountSet(rewardAmount, _newRewardAmount);
    rewardAmount = _newRewardAmount;
  }

  function _setRewardInterval(uint256 _newRewardInterval) internal {
    emit RewardIntervalSet(rewardInterval, _newRewardInterval);
    rewardInterval = _newRewardInterval;
  }

  function _setRewardSource(address _newRewardSource) internal {
    emit RewardSourceSet(rewardSource, _newRewardSource);
    rewardSource = _newRewardSource;
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver, IERC20} from "src/interfaces/INotifiableRewardReceiver.sol";
import {RewardTokenNotifierBase} from "src/notifiers/RewardTokenNotifierBase.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract TransferFromRewardNotifier is RewardTokenNotifierBase {
  using SafeERC20 for IERC20;

  event RewardSourceSet(address oldRewardSource, address newRewardSource);

  address public rewardSource;

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

  function setRewardSource(address _newRewardSource) external {
    _checkOwner();
    _setRewardSource(_newRewardSource);
  }

  function _setRewardSource(address _newRewardSource) internal {
    emit RewardSourceSet(rewardSource, _newRewardSource);
    rewardSource = _newRewardSource;
  }

  function _sendTokensToReceiver() internal virtual override {
    TOKEN.transferFrom(rewardSource, address(RECEIVER), rewardAmount);
  }
}

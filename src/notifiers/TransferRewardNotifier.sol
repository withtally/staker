// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver, IERC20} from "src/interfaces/INotifiableRewardReceiver.sol";
import {RewardTokenNotifierBase} from "src/notifiers/RewardTokenNotifierBase.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract TransferRewardNotifier is RewardTokenNotifierBase {
  using SafeERC20 for IERC20;

  constructor(
    INotifiableRewardReceiver _receiver,
    uint256 _initialRewardAmount,
    uint256 _initialRewardInterval,
    address _initialOwner
  )
    RewardTokenNotifierBase(_receiver, _initialRewardAmount, _initialRewardInterval)
    Ownable(_initialOwner)
  {}

  function _sendTokensToReceiver() internal virtual override {
    TOKEN.transfer(address(RECEIVER), rewardAmount);
  }
}

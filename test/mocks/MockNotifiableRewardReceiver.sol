// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {
  INotifiableRewardReceiver, IERC20
} from "../../src/interfaces/INotifiableRewardReceiver.sol";

contract MockNotifiableRewardReceiver is INotifiableRewardReceiver {
  IERC20 public immutable REWARD_TOKEN;

  uint256 public lastParam_notifyRewardAmount_amount;

  constructor(IERC20 _rewardToken) {
    REWARD_TOKEN = _rewardToken;
  }

  function notifyRewardAmount(uint256 _amount) external {
    lastParam_notifyRewardAmount_amount = _amount;
  }
}

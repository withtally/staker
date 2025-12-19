// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Staker} from "src/Staker.sol";
import {APRRewardNotifier} from "src/notifiers/APRRewardNotifier.sol";

contract APRRewardNotifierHarness is APRRewardNotifier {
  constructor(Staker _receiver, IERC20 _rewardToken, uint16 _multiple, address _owner)
    APRRewardNotifier(_receiver, _rewardToken, _multiple, _owner)
  {}

  function exposed_currentScaledAPR() public view returns (uint256) {
    return _currentScaledAPR();
  }

  function exposed_remainingScaledReward() public view returns (uint256) {
    return _remainingScaledReward();
  }

  function exposed_targetScaledRewardRate() public view returns (uint256) {
    return _targetScaledRewardRate();
  }
}

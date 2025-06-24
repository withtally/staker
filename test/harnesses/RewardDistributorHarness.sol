// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEarningPowerCalculator} from "../../src/interfaces/IEarningPowerCalculator.sol";
import {RewardDistributor} from "../../src/RewardDistributor.sol";
import {RewardDistributorDelegateInitializer} from
  "../../src/RewardDistributorDelegateInitializer.sol";

contract RewardDistributorHarness is RewardDistributor, RewardDistributorDelegateInitializer {
  constructor(
    IERC20 _rewardToken,
    IEarningPowerCalculator _earningPowerCalculator,
    uint256 _maxBumpTip,
    address _admin
  ) RewardDistributor(_rewardToken, _earningPowerCalculator, _maxBumpTip, _admin) {}
}

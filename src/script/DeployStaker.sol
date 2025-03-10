// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DeployBase} from "./DeployBase.sol";
import {IEarningPowerCalculator} from "../interfaces/IEarningPowerCalculator.sol";
import {Staker} from "../Staker.sol";

abstract contract DeployStaker is DeployBase {
  struct StakerConfiguration {
    IERC20 rewardToken;
    IERC20 stakeToken;
    IEarningPowerCalculator earningPowerCalculator;
    uint256 maxBumpTip;
    address admin;
  }

  function _deployStakerConfiguration(IEarningPowerCalculator _earningPowerCalculator)
    internal
    virtual
    returns (StakerConfiguration memory);
}

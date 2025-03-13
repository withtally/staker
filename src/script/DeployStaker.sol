// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DeployBase} from "./DeployBase.sol";
import {IEarningPowerCalculator} from "../interfaces/IEarningPowerCalculator.sol";
import {Staker} from "../Staker.sol";

abstract contract DeployStaker is DeployBase {
  /// @notice The configuration for the Staker contract.
  /// @param rewardToken The reward token for Staker.
  /// @param stakeToken The stake token for Staker.
  /// @param earningPowerCalculator The earning power calculator for Staker.
  /// @param maxBumpTip The max bump tip for Staker.
  struct StakerConfiguration {
    IERC20 rewardToken;
    IERC20 stakeToken;
    IEarningPowerCalculator earningPowerCalculator;
    uint256 maxBumpTip;
  }

  /// @notice An interface method that returns a the configuration for the Staker contract.
  /// @param _earningPowerCalculator The deployed earning power calculator.
  /// @return The staker configration.
  function _deployStakerConfiguration(IEarningPowerCalculator _earningPowerCalculator)
    internal
    virtual
    returns (StakerConfiguration memory);
}

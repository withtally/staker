// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {DeployBase} from "../DeployBase.sol";
import {IdentityEarningPowerCalculator} from "../../calculators/IdentityEarningPowerCalculator.sol";
import {IEarningPowerCalculator} from "../../interfaces/IEarningPowerCalculator.sol";

/// @title DeployIdentityEarningPowerCalculator
/// @author [ScopeLift](https://scopelift.co)
/// @notice An abstract contract that has the interface and logic necessary to
/// deploy an `IdentityEarningPowerCalculator` contract. This contract is part of our modular
/// deployment system and can be combined with other script contracts in order to deploy
/// an entire Staker system.
abstract contract DeployIdentityEarningPowerCalculator is DeployBase {
  /// @notice Deploys an identity earning power calculator.
  /// @inheritdoc DeployBase
  function _deployEarningPowerCalculator()
    internal
    virtual
    override
    returns (IEarningPowerCalculator)
  {
    return new IdentityEarningPowerCalculator();
  }
}

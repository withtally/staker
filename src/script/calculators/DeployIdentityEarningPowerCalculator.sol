// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {DeployBase} from "../DeployBase.sol";
import {IdentityEarningPowerCalculator} from "../../calculators/IdentityEarningPowerCalculator.sol";
import {IEarningPowerCalculator} from "../../interfaces/IEarningPowerCalculator.sol";

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

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {DeployBase} from "../DeployBase.sol";
import {BinaryEligibilityOracleEarningPowerCalculator} from
  "../../calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";
import {IEarningPowerCalculator} from "../../interfaces/IEarningPowerCalculator.sol";

abstract contract DeployBinaryEligibilityOracleEarningPowerCalculator is DeployBase {
  /// @notice The configuration for the binary eligibility oracle earning power calculator.
  /// @param owner The DAO governor address.
  /// @param scoreOracle The address of the trusted oracle address.
  /// @param staleOracleWindow The length of oracle downtime before, all stakers' earning power will
  /// be set to 100% of their staked amounts.
  /// @param oraclePauseGuardian The address of a caller that can prevent the oracle from updating
  /// delegate scores.
  /// @param delegateeScoreEligibilityThreshold The threshold for delegatee score eligibility to
  /// have the full earning power.
  /// @param updateEligibilityDelay The delay required between delegatee earning power updates after
  /// falling below the eligibility threshold.
  struct BinaryEligibilityOracleEarningPowerCalculatorConfiguration {
    address owner;
    address scoreOracle;
    uint256 staleOracleWindow;
    address oraclePauseGuardian;
    uint256 delegateeScoreEligibilityThreshold;
    uint256 updateEligibilityDelay;
  }

  /// @notice An interface method that returns the configuration for the binary eligibility oracle
  /// earning power calculator.
  function _binaryEligibilityOracleEarningPowerCalculatorConfiguration()
    internal
    virtual
    returns (BinaryEligibilityOracleEarningPowerCalculatorConfiguration memory);

  /// @notice Deploys a binary eligibility oracle earning power calculator.
  /// @inheritdoc DeployBase
  function _deployEarningPowerCalculator()
    internal
    virtual
    override
    returns (IEarningPowerCalculator)
  {
    BinaryEligibilityOracleEarningPowerCalculatorConfiguration memory _config =
      _binaryEligibilityOracleEarningPowerCalculatorConfiguration();
    return new BinaryEligibilityOracleEarningPowerCalculator(
      _config.owner,
      _config.scoreOracle,
      _config.staleOracleWindow,
      _config.oraclePauseGuardian,
      _config.delegateeScoreEligibilityThreshold,
      _config.updateEligibilityDelay
    );
  }
}

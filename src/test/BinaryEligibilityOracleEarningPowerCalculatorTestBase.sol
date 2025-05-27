// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.23;

import {BinaryEligibilityOracleEarningPowerCalculator} from
  "src/calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";
import {MintRewardNotifier} from "../notifiers/MintRewardNotifier.sol";
import {StakerTestBase} from "./StakerTestBase.sol";
import {Staker} from "../Staker.sol";

/// @title BinaryEligibilityOracleEarningPowerCalculatorTestBase
/// @author [ScopeLift](https://scopelift.co)
/// @notice The base contract for testing BinaryEligibilityOracleEarningPowerCalculator. Contains
/// test setup and helper functions for testing the calculator's behavior when delegatees meet
/// the eligibility threshold. This includes stake management and eligibility threshold testing
/// functionality. This contract is designed to be used in conjunction with the deployment scripts
/// in
/// `src/script/calculators/DeployBinaryEligibilityOracleEarningPowerCalculator.sol`.
abstract contract BinaryEligibilityOracleEarningPowerCalculatorTestBase is StakerTestBase {
  BinaryEligibilityOracleEarningPowerCalculator calculator;
  MintRewardNotifier mintRewardNotifier;

  /// @notice Helper to set a delegatee's score above the eligibility threshold.
  /// @dev This should be called after a delegatee is known but before checking their earning power.
  /// @param delegatee The address of the delegatee whose score will be set above threshold.
  function _setDelegateeScoreAboveThreshold(address delegatee) internal {
    vm.startPrank(calculator.scoreOracle());
    calculator.updateDelegateeScore(delegatee, calculator.delegateeEligibilityThresholdScore() + 1);
    vm.stopPrank();
  }

  /// @notice A test helper that wraps calling the `stake` function on the underlying Staker
  /// contract.
  /// @dev When the delegatee is below threshold, this function automatically sets their score above
  /// threshold and bumps the earning power to ensure proper test setup.
  /// @param _depositor The address of the depositor.
  /// @param _amount The amount to stake.
  /// @param _delegatee The address that will receive the voting power of the stake.
  /// @return _depositId The id of the created deposit.
  function _stake(address _depositor, uint256 _amount, address _delegatee)
    internal
    virtual
    override
    returns (Staker.DepositIdentifier _depositId)
  {
    _depositId = StakerTestBase._stake(_depositor, _amount, _delegatee);

    // This should only be triggered on the first call. Subsequent calls will have the delegatee
    // score already above threshold, so their stakes should be full already.
    if (calculator.delegateeScores(_delegatee) < calculator.delegateeEligibilityThresholdScore()) {
      _setDelegateeScoreAboveThreshold(_delegatee);
      vm.startPrank(_depositor);
      staker.bumpEarningPower(_depositId, _depositor, 0);
      vm.stopPrank();
    }
  }

  /// @notice Bound the mint amount to a realistic value.
  /// @dev Override of the base contract's function to set appropriate bounds for this calculator.
  /// @param _amount The unbounded mint amount.
  /// @return The bounded mint amount.
  function _boundMintAmount(uint256 _amount) internal pure virtual override returns (uint256) {
    return bound(_amount, 1, 100_000_000e18);
  }
}

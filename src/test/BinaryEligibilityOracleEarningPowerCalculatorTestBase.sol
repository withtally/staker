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
/// functionality.
/// @dev This contract requires an initialized instance of
/// `BinaryEligibilityOracleEarningPowerCalculator`. Initialization is typically handled by a
/// deployment script such as
/// `src/script/calculators/DeployBinaryEligibilityOracleEarningPowerCalculator.sol`.
abstract contract BinaryEligibilityOracleEarningPowerCalculatorTestBase is StakerTestBase {
  BinaryEligibilityOracleEarningPowerCalculator calculator;
  MintRewardNotifier mintRewardNotifier;

  /// @notice A helper function that updates the delegatee score for a given deposit to a random
  /// value between 0 and twice the eligibility threshold, facilitating tests for both eligible and
  /// ineligible delegatee scenarios.
  /// @param _depositId The identifier of the deposit whose delegatee's score is to be updated.
  function _updateEarningPower(Staker.DepositIdentifier _depositId) internal virtual override {
    uint256 _delegateeeScore = vm.randomUint(0, calculator.delegateeEligibilityThresholdScore() * 2);
    Staker.Deposit memory _deposit = _fetchDeposit(_depositId);
    vm.startPrank(calculator.scoreOracle());
    calculator.updateDelegateeScore(_deposit.delegatee, _delegateeeScore);
    vm.stopPrank();
  }

  /// @notice Bound the mint amount to a realistic value.
  /// @dev Override of the base contract's function to set appropriate bounds for this calculator.
  /// @param _amount The unbounded mint amount.
  /// @return The bounded mint amount.
  function _boundMintAmount(uint256 _amount) internal pure virtual override returns (uint256) {
    return bound(_amount, 1, 100_000_000e18);
  }
}

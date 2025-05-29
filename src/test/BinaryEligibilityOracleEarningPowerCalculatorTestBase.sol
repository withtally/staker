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

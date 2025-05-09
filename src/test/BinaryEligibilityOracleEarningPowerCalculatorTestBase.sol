// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {BinaryEligibilityOracleEarningPowerCalculator} from
  "src/calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";
import {MintRewardNotifier} from "../notifiers/MintRewardNotifier.sol";
import {StakerTestBase} from "./StakerTestBase.sol";
import {Staker} from "../Staker.sol";

abstract contract BinaryEligibilityOracleEarningPowerCalculatorTestBase is StakerTestBase {
  BinaryEligibilityOracleEarningPowerCalculator calculator;
  MintRewardNotifier mintRewardNotifier;

  function _notifyRewardAmount(uint256 _amount) public override {
    address _owner = mintRewardNotifier.owner();

    vm.prank(_owner);
    mintRewardNotifier.setRewardAmount(_amount);

    mintRewardNotifier.notify();
  }

  /// !Fix Natspec
  /// @notice Helper to set a delegatee's score above threshold
  /// @dev This should be called after a delegatee is known but before checking their earning power
  function _setDelegateeScoreAboveThreshold(address delegatee) internal {
    vm.startPrank(calculator.scoreOracle());
    calculator.updateDelegateeScore(delegatee, calculator.delegateeEligibilityThresholdScore() + 1);
    vm.stopPrank();
  }

  /// !Fix Natspec
  /// @notice A test helper that wraps calling the `stake` function on the underlying Staker
  /// contract.
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
    vm.assume(_delegatee != address(0));

    vm.startPrank(_depositor);
    STAKE_TOKEN.approve(address(staker), _amount);
    _depositId = staker.stake(_amount, _delegatee);
    vm.stopPrank();

    // Called after the stake so the surrogate will exist
    _assumeSafeDepositorAndSurrogate(_depositor, _delegatee);

    // This should only be triggered on the first call. Subsequent calls will have the
    // delegateeScore already above threshold, so their stakes should be full already.
    if (calculator.delegateeScores(_delegatee) < calculator.delegateeEligibilityThresholdScore()) {
      _setDelegateeScoreAboveThreshold(_delegatee);
      vm.startPrank(_depositor);
      staker.bumpEarningPower(_depositId, _depositor, 0);
      vm.stopPrank();
    }
  }

  /// !Fix Natspec
  /// @notice Bound the mint amount to a realistic value.
  /// @param _amount The unbounded mint amount.
  /// @return The bounded mint amount.
  function _boundMintAmount(uint256 _amount) internal pure virtual override returns (uint256) {
    return bound(_amount, 1, 100_000_000e18);
  }
}

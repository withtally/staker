// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {IdentityEarningPowerCalculator} from "../src/calculators/IdentityEarningPowerCalculator.sol";

contract IdentityEarningPowerCalculatorTest is Test {
  IdentityEarningPowerCalculator calculator;

  function setUp() public {
    calculator = new IdentityEarningPowerCalculator();
  }
}

contract GetEarningPower is IdentityEarningPowerCalculatorTest {
  function testFuzz_ReturnsAmountStaked(uint256 _amountStaked, address _staker, address _delegatee)
    public
    view
  {
    assertEq(calculator.getEarningPower(_amountStaked, _staker, _delegatee), _amountStaked);
  }
}

contract GetNewEarningPower is IdentityEarningPowerCalculatorTest {
  function testFuzz_ReturnsAmountStakedAndNeverQualifiesForBump(
    uint256 _amountStaked,
    address _staker,
    address _delegatee,
    uint256 _oldEarningPower
  ) public view {
    (uint256 _earningPower, bool _isQualifiedForUpdate) =
      calculator.getNewEarningPower(_amountStaked, _staker, _delegatee, _oldEarningPower);

    assertEq(_earningPower, _amountStaked);
    assertEq(_isQualifiedForUpdate, false);
  }
}

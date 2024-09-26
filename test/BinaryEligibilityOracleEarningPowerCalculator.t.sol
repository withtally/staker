// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {BinaryEligibilityOracleEarningPowerCalculator as EarningPowerCalculator} from
  "src/BinaryEligibilityOracleEarningPowerCalculator.sol";

contract EarningPowerCalculatorTest is Test {
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event DelegateeScoreUpdated(address indexed delegatee, uint256 oldScore, uint256 newScore);
  event DelegateeScoreLockSet(address indexed delegatee, bool oldState, bool newState);
  event ScoreOracleSet(address indexed oldScoreOracle, address indexed newScoreOracle);
  event UpdateEligibilityDelaySet(uint256 oldDelay, uint256 newDelay);
  event DelegateeScoreEligibilityThresholdSet(uint256 oldThreshold, uint256 newThreshold);

  error OwnableUnauthorizedAccount(address account);

  address public owner;
  address public scoreOracle;
  uint256 public delegateeScoreEligibilityThreshold;
  uint256 public updateEligibilityDelay;
  EarningPowerCalculator public calculator;

  function setUp() public {
    owner = makeAddr("owner");
    scoreOracle = makeAddr("scoreOracle");
    delegateeScoreEligibilityThreshold = 50;
    updateEligibilityDelay = 7 days;

    calculator = new EarningPowerCalculator(
      owner, scoreOracle, delegateeScoreEligibilityThreshold, updateEligibilityDelay
    );
  }
}

contract Constructor is EarningPowerCalculatorTest {
  function test_SetsOwnerAndContractParametersCorrectly() public view {
    assertEq(calculator.owner(), owner);
    assertEq(calculator.scoreOracle(), scoreOracle);
    assertEq(calculator.delegateeScoreEligibilityThreshold(), delegateeScoreEligibilityThreshold);
    assertEq(calculator.updateEligibilityDelay(), updateEligibilityDelay);
  }

  function testFuzz_SetsOwnerAndContractParametersToArbitraryValues(
    address _owner,
    address _scoreOracle,
    uint256 _delegateeScoreEligibilityThreshold,
    uint256 _updateEligibilityDelay
  ) public {
    vm.assume(_owner != address(0));
    EarningPowerCalculator _calculator = new EarningPowerCalculator(
      _owner, _scoreOracle, _delegateeScoreEligibilityThreshold, _updateEligibilityDelay
    );
    assertEq(_calculator.owner(), _owner);
    assertEq(_calculator.scoreOracle(), _scoreOracle);
    assertEq(_calculator.delegateeScoreEligibilityThreshold(), _delegateeScoreEligibilityThreshold);
    assertEq(_calculator.updateEligibilityDelay(), _updateEligibilityDelay);
  }

  function testFuzz_EmitsEventsWhenOwnerAndContractParametersAreSetToArbitraryValues(
    address _owner,
    address _scoreOracle,
    uint256 _delegateeScoreEligibilityThreshold,
    uint256 _updateEligibilityDelay
  ) public {
    vm.assume(_owner != address(0));

    vm.expectEmit();
    emit OwnershipTransferred(address(0), _owner);
    vm.expectEmit();
    emit ScoreOracleSet(address(0), _scoreOracle);
    vm.expectEmit();
    emit DelegateeScoreEligibilityThresholdSet(0, _delegateeScoreEligibilityThreshold);
    vm.expectEmit();
    emit UpdateEligibilityDelaySet(0, _updateEligibilityDelay);

    EarningPowerCalculator _calculator = new EarningPowerCalculator(
      _owner, _scoreOracle, _delegateeScoreEligibilityThreshold, _updateEligibilityDelay
    );
  }
}

contract GetEarningPower is EarningPowerCalculatorTest {
  function testFuzz_ReturnsAmountStakedAsEarningPowerWhenStaleOracleWindowHasPassed(
    uint256 _amountStaked,
    address _staker,
    address _delegatee,
    uint256 _delegateeScore,
    uint256 _timeSinceLastOracleUpdate
  ) public {
    _timeSinceLastOracleUpdate = bound(
      _timeSinceLastOracleUpdate,
      calculator.STALE_ORACLE_WINDOW() + 1,
      type(uint256).max - block.timestamp
    );
    vm.prank(scoreOracle);
    calculator.updateDelegateeScore(_delegatee, _delegateeScore);

    vm.warp(block.timestamp + _timeSinceLastOracleUpdate);
    assertEq(calculator.getEarningPower(_amountStaked, _staker, _delegatee), _amountStaked);
  }

  function testFuzz_ReturnsZeroEarningPowerWhenDelegateeScoreIsBelowEligibilityThreshold(
    uint256 _delegateeScore,
    uint256 _amountStaked,
    address _staker,
    address _delegatee
  ) public {
    _delegateeScore = bound(_delegateeScore, 0, calculator.delegateeScoreEligibilityThreshold() - 1);
    vm.prank(scoreOracle);
    calculator.updateDelegateeScore(_delegatee, _delegateeScore);
    assertEq(calculator.getEarningPower(_amountStaked, _staker, _delegatee), 0);
  }

  function testFuzz_ReturnsAmountStakedAsEarningPowerWhenDelegateScoreIsAboveTheEligibilityThreshold(
    uint256 _delegateeScore,
    uint256 _amountStaked,
    address _staker,
    address _delegatee
  ) public {
    _delegateeScore =
      bound(_delegateeScore, calculator.delegateeScoreEligibilityThreshold() + 1, type(uint256).max);
    vm.prank(scoreOracle);
    calculator.updateDelegateeScore(_delegatee, _delegateeScore);
    assertEq(calculator.getEarningPower(_amountStaked, _staker, _delegatee), _amountStaked);
  }
}

contract GetNewEarningPower is EarningPowerCalculatorTest {
  function testFuzz_ReturnsAmountStakedAndEligibleWhenStaleOracleWindowHasPassed(
    uint256 _amountStaked,
    address _staker,
    address _delegatee,
    uint256 _oldEarningPower,
    uint256 _delegateeScore,
    uint256 _timeSinceLastOracleUpdate
  ) public {
    _timeSinceLastOracleUpdate = bound(
      _timeSinceLastOracleUpdate,
      calculator.STALE_ORACLE_WINDOW() + 1,
      type(uint256).max - block.timestamp
    );
    vm.prank(scoreOracle);
    calculator.updateDelegateeScore(_delegatee, _delegateeScore);

    vm.warp(block.timestamp + _timeSinceLastOracleUpdate);
    (uint256 _earningPower, bool _isQualifiedForUpdate) =
      calculator.getNewEarningPower(_amountStaked, _staker, _delegatee, _oldEarningPower);
    assertEq(_earningPower, _amountStaked);
    assertEq(_isQualifiedForUpdate, true);
  }

  // Test Case:
  // 1. Score >= Threshold: Delegatee is Eligible for full earning power.
  // 2. Score < Threshold: Updated delegatee score falls below threshold.
  // 4. _updateEligibilityDelay is NOT reached.
  // Result: We expect 0 earning power and false for _isQualifiedForUpdate.
  function testFuzz_ReturnsZeroEarningPowerAndNotEligibleWhenDelegateScoreFallsBelowEligibilityThresholdButWithinTheUpdateEligibilityDelay(
    uint256 _amountStaked,
    address _staker,
    address _delegatee,
    uint256 _oldEarningPower,
    uint256 _delegateeScoreAboveThreshold,
    uint256 _newDelegateeScoreBelowThreshold,
    uint256 _timeShorterThanUpdateEligibilityDelay
  ) public {
    _delegateeScoreAboveThreshold = bound(
      _delegateeScoreAboveThreshold,
      calculator.delegateeScoreEligibilityThreshold(),
      type(uint256).max
    );
    _newDelegateeScoreBelowThreshold = bound(
      _newDelegateeScoreBelowThreshold, 0, calculator.delegateeScoreEligibilityThreshold() - 1
    );
    // time shorter than the eligibility delay but at least 1 because vm.wrap can't take 0.
    _timeShorterThanUpdateEligibilityDelay =
      bound(_timeShorterThanUpdateEligibilityDelay, 1, calculator.updateEligibilityDelay() - 1);

    vm.startPrank(scoreOracle);
    // First becomes an eligible delegatee
    calculator.updateDelegateeScore(_delegatee, _delegateeScoreAboveThreshold);
    // But then falls below the threshold.
    calculator.updateDelegateeScore(_delegatee, _newDelegateeScoreBelowThreshold);
    vm.stopPrank();

    vm.warp(
      calculator.lastDelegateeEligibilityChangeTime(_delegatee)
        + _timeShorterThanUpdateEligibilityDelay
    );
    (uint256 _earningPower, bool _isQualifiedForUpdate) =
      calculator.getNewEarningPower(_amountStaked, _staker, _delegatee, _oldEarningPower);
    assertEq(_earningPower, 0);
    assertEq(_isQualifiedForUpdate, false);
  }

  function testFuzz_ReturnsZeroEarningPowerAndEligibleWhenDelegateScoreIsBelowEligibilityThresholdButOutsideTheUpdateEligibilityDelay(
    uint256 _amountStaked,
    address _staker,
    address _delegatee,
    uint256 _oldEarningPower,
    uint256 _delegateeScore,
    uint256 _timeLengthBetweenUpdateEligibilityDelayAndStaleOracleWindow
  ) public {
    _delegateeScore = bound(_delegateeScore, 0, calculator.delegateeScoreEligibilityThreshold() - 1);
    _timeLengthBetweenUpdateEligibilityDelayAndStaleOracleWindow = bound(
      _timeLengthBetweenUpdateEligibilityDelayAndStaleOracleWindow,
      calculator.updateEligibilityDelay(),
      calculator.STALE_ORACLE_WINDOW()
    );
    vm.prank(scoreOracle);
    calculator.updateDelegateeScore(_delegatee, _delegateeScore);

    vm.warp(block.timestamp + _timeLengthBetweenUpdateEligibilityDelayAndStaleOracleWindow);
    (uint256 _earningPower, bool _isQualifiedForUpdate) =
      calculator.getNewEarningPower(_amountStaked, _staker, _delegatee, _oldEarningPower);
    assertEq(_earningPower, 0);
    assertEq(_isQualifiedForUpdate, true);
  }

  // Test Case:
  // 1. Score >= Threshold: Delegatee is Eligible for full earning power.
  // 2. Score < Threshold: Updated delegatee score falls below threshold.
  // 3. Score < Threshold: Right before the updateEligibilityDelay is reached, updated delegatee
  // score is still below threshold
  // 4. _updateEligibilityDelay is reached.
  // Result: We expect 0 earning power and true for _isQualifiedForUpdate.
  function testFuzz_ReturnsZeroEarningPowerAndEligibleWhenDelegateScoreFallsBelowEligibilityThresholdButOutsideTheUpdateEligibilityDelayWithRecentBelowThresholdScoreUpdate(
    uint256 _amountStaked,
    address _staker,
    address _delegatee,
    uint256 _oldEarningPower,
    uint256 _delegateeScore,
    uint256 _newDelegateeScore,
    uint256 _updatedDelegateeScore,
    uint256 _timeBetweenUpdateEligibilityDelayAndStaleOracleWindow,
    uint256 _timeBeforeEligibilityDelay
  ) public {
    _delegateeScore =
      bound(_delegateeScore, calculator.delegateeScoreEligibilityThreshold(), type(uint256).max);
    _newDelegateeScore =
      bound(_newDelegateeScore, 0, calculator.delegateeScoreEligibilityThreshold() - 1);
    _updatedDelegateeScore =
      bound(_updatedDelegateeScore, 0, calculator.delegateeScoreEligibilityThreshold() - 1);

    _timeBeforeEligibilityDelay =
      bound(_timeBeforeEligibilityDelay, 0, calculator.updateEligibilityDelay() - 1);

    _timeBetweenUpdateEligibilityDelayAndStaleOracleWindow = bound(
      _timeBetweenUpdateEligibilityDelayAndStaleOracleWindow,
      calculator.updateEligibilityDelay(),
      calculator.STALE_ORACLE_WINDOW()
    );

    vm.startPrank(scoreOracle);
    // First becomes an eligible delegatee
    calculator.updateDelegateeScore(_delegatee, _delegateeScore);
    // But then falls below the threshold.
    calculator.updateDelegateeScore(_delegatee, _newDelegateeScore);
    vm.stopPrank();

    // Updating the delegate score before `updateEligibilityDelay` with a score below the
    // `delegateeScoreEligibilityThreshold` shouldn't affect the `_isQualifiedForUpdate` value.
    vm.warp(block.timestamp + _timeBeforeEligibilityDelay);
    vm.prank(scoreOracle);
    calculator.updateDelegateeScore(_delegatee, _updatedDelegateeScore);

    // Warp to block.timestamp + _timeBetweenUpdateEligibilityDelayAndStaleOracleWindow;
    vm.warp(
      block.timestamp - _timeBeforeEligibilityDelay
        + _timeBetweenUpdateEligibilityDelayAndStaleOracleWindow
    );
    (uint256 _earningPower, bool _isQualifiedForUpdate) =
      calculator.getNewEarningPower(_amountStaked, _staker, _delegatee, _oldEarningPower);
    assertEq(_earningPower, 0);
    assertEq(_isQualifiedForUpdate, true);
  }

  function testFuzz_ReturnsStakedAmountAsEarningPowerAndEligibleWhenDelegateScoreIsAboveEligibilityThresholdNotMatterTheTimeSinceLastDelegateeEligibilityChangeTime(
    uint256 _amountStaked,
    address _staker,
    address _delegatee,
    uint256 _oldEarningPower,
    uint256 _delegateeScore,
    uint256 _timeSinceLastDelegateeEligibilityChangeTime
  ) public {
    _delegateeScore =
      bound(_delegateeScore, calculator.delegateeScoreEligibilityThreshold(), type(uint256).max);
    _timeSinceLastDelegateeEligibilityChangeTime =
      bound(_timeSinceLastDelegateeEligibilityChangeTime, 0, type(uint256).max - block.timestamp);
    vm.prank(scoreOracle);
    calculator.updateDelegateeScore(_delegatee, _delegateeScore);

    vm.warp(block.timestamp + _timeSinceLastDelegateeEligibilityChangeTime);
    (uint256 _earningPower, bool _isQualifiedForUpdate) =
      calculator.getNewEarningPower(_amountStaked, _staker, _delegatee, _oldEarningPower);
    assertEq(_earningPower, _amountStaked);
    assertEq(_isQualifiedForUpdate, true);
  }
}

contract LastDelegateeEligibilityChangeTime is EarningPowerCalculatorTest {
  // Score below the threshold => above threshold; lastDelegateeEligibilityChangeTime is updated;
  function testFuzz_SetsLastDelegateeEligibilityChangeTimeWhenADelegateBecomesEligible(
    address _delegatee,
    uint256 _delegateeScoreAboveThreshold,
    uint256 _randomTimestamp
  ) public {
    _delegateeScoreAboveThreshold = bound(
      _delegateeScoreAboveThreshold,
      calculator.delegateeScoreEligibilityThreshold(),
      type(uint256).max
    );
    vm.warp(_randomTimestamp);
    vm.prank(scoreOracle);
    calculator.updateDelegateeScore(_delegatee, _delegateeScoreAboveThreshold);
    assertEq(calculator.lastDelegateeEligibilityChangeTime(_delegatee), _randomTimestamp);
  }

  // Score above the threshold => below threshold; lastDelegateeEligibilityChangeTime is updated;
  function testFuzz_SetsLastDelegateeEligibilityChangeTimeWhenADelegateBecomesIneligible(
    address _delegatee,
    uint256 _delegateeScoreAboveThreshold,
    uint256 _delegateeScoreBelowThreshold,
    uint256 _randomTimestamp
  ) public {
    _delegateeScoreAboveThreshold = bound(
      _delegateeScoreAboveThreshold,
      calculator.delegateeScoreEligibilityThreshold(),
      type(uint256).max
    );
    _delegateeScoreBelowThreshold =
      bound(_delegateeScoreBelowThreshold, 0, calculator.delegateeScoreEligibilityThreshold() - 1);

    vm.prank(scoreOracle);
    calculator.updateDelegateeScore(_delegatee, _delegateeScoreAboveThreshold);

    vm.warp(_randomTimestamp);
    vm.prank(scoreOracle);
    calculator.updateDelegateeScore(_delegatee, _delegateeScoreBelowThreshold);
    assertEq(calculator.lastDelegateeEligibilityChangeTime(_delegatee), _randomTimestamp);
  }

  // Score >= threshold to score < threshold; lastDelegateeEligibilityChangeTime is not
  // updated.
  function testFuzz_KeepsLastDelegateeEligibilityChangeTimeWhenAnIneligibleDelegateScoreIsUpdatedScoreBelowThreshold(
    address _delegatee,
    uint256 _delegateeScoreAboveThreshold,
    uint256 _delegateeScoreBelowThreshold,
    uint256 _updatedDelegateeScoreBelowThreshold,
    uint256 _expectedTimestamp,
    uint256 _randomTimestamp
  ) public {
    _delegateeScoreAboveThreshold = bound(
      _delegateeScoreAboveThreshold,
      calculator.delegateeScoreEligibilityThreshold(),
      type(uint256).max
    );
    _delegateeScoreBelowThreshold =
      bound(_delegateeScoreBelowThreshold, 0, calculator.delegateeScoreEligibilityThreshold() - 1);
    _updatedDelegateeScoreBelowThreshold = bound(
      _updatedDelegateeScoreBelowThreshold, 0, calculator.delegateeScoreEligibilityThreshold() - 1
    );
    vm.assume(_expectedTimestamp < _randomTimestamp);

    vm.startPrank(scoreOracle);
    calculator.updateDelegateeScore(_delegatee, _delegateeScoreAboveThreshold);

    // First time _delegatee becomes ineligible
    vm.warp(_expectedTimestamp);
    calculator.updateDelegateeScore(_delegatee, _delegateeScoreBelowThreshold);
    console2.log(_expectedTimestamp);

    // Since the delegatee is already ineligible, a score update that's below the threshold
    // shouldn't change the lastDelegateeEligibilityChangeTime to _randomTimestamp.
    vm.warp(_randomTimestamp);
    calculator.updateDelegateeScore(_delegatee, _updatedDelegateeScoreBelowThreshold);
    vm.stopPrank();

    assertEq(calculator.lastDelegateeEligibilityChangeTime(_delegatee), _expectedTimestamp);
  }
}

contract UpdateDelegateScore is EarningPowerCalculatorTest {
  function testFuzz_UpdatesDelegateScore(address _delegatee, uint256 _newScore) public {
    vm.prank(scoreOracle);
    calculator.updateDelegateeScore(_delegatee, _newScore);
    assertEq(calculator.delegateeScores(_delegatee), _newScore);
    assertEq(calculator.lastOracleUpdateTime(), block.timestamp);
  }

  function testFuzz_UpdatesExistingDelegateScore(
    address _delegatee,
    uint256 _firstScore,
    uint256 _secondScore,
    uint256 _timeInBetween
  ) public {
    vm.startPrank(scoreOracle);
    calculator.updateDelegateeScore(_delegatee, _firstScore);
    assertEq(calculator.delegateeScores(_delegatee), _firstScore);
    assertEq(calculator.lastOracleUpdateTime(), block.timestamp);

    vm.warp(_timeInBetween);

    calculator.updateDelegateeScore(_delegatee, _secondScore);
    assertEq(calculator.delegateeScores(_delegatee), _secondScore);
    assertEq(calculator.lastOracleUpdateTime(), _timeInBetween);
    vm.stopPrank();
  }

  function testFuzz_EmitsAnEventWhenDelegatesScoreIsUpdated(address _delegatee, uint256 _newScore)
    public
  {
    vm.prank(scoreOracle);
    vm.expectEmit();
    emit DelegateeScoreUpdated(_delegatee, 0, _newScore);
    calculator.updateDelegateeScore(_delegatee, _newScore);
  }

  function testFuzz_RevertIf_CallerIsNotTheScoreOracle(
    address _caller,
    address _delegatee,
    uint256 _newScore
  ) public {
    vm.assume(_caller != scoreOracle);
    vm.prank(_caller);
    vm.expectRevert(
      abi.encodeWithSelector(
        EarningPowerCalculator.Unauthorized.selector, bytes32("not oracle"), _caller
      )
    );
    calculator.updateDelegateeScore(_delegatee, _newScore);
  }

  function testFuzz_RevertIf_DelegateeScoreLocked(
    address _delegatee,
    uint256 _overrideScore,
    uint256 _newScore
  ) public {
    vm.prank(owner);
    calculator.overrideDelegateeScore(_delegatee, _overrideScore);
    vm.prank(scoreOracle);
    vm.expectRevert(
      abi.encodeWithSelector(EarningPowerCalculator.DelegateeScoreLocked.selector, _delegatee)
    );
    calculator.updateDelegateeScore(_delegatee, _newScore);
  }
}

contract OverrideDelegateScore is EarningPowerCalculatorTest {
  function testFuzz_OverrideDelegateScore(address _delegatee, uint256 _newScore, uint256 _timestamp)
    public
  {
    vm.warp(_timestamp);
    vm.prank(owner);
    calculator.overrideDelegateeScore(_delegatee, _newScore);
    assertEq(calculator.delegateeScores(_delegatee), _newScore);
    assertEq(calculator.delegateeScoreLock(_delegatee), true);
  }

  function testFuzz_EmitsEventWhenDelegateScoreIsOverridden(
    address _delegatee,
    uint256 _newScore,
    uint256 _timestamp
  ) public {
    vm.warp(_timestamp);
    vm.prank(owner);
    vm.expectEmit();
    emit DelegateeScoreUpdated(_delegatee, 0, _newScore);
    vm.expectEmit();
    emit DelegateeScoreLockSet(_delegatee, false, true);
    calculator.overrideDelegateeScore(_delegatee, _newScore);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(
    address _caller,
    address _delegatee,
    uint256 _newScore
  ) public {
    vm.assume(_caller != owner);
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _caller));
    calculator.overrideDelegateeScore(_delegatee, _newScore);
    assertEq(calculator.delegateeScoreLock(_delegatee), false);
  }
}

contract SetDelegateeScoreLock is EarningPowerCalculatorTest {
  function testFuzz_LocksOrUnlocksADelegateeScore(address _delegatee, bool _isLocked) public {
    vm.prank(owner);
    calculator.setDelegateeScoreLock(_delegatee, _isLocked);
    assertEq(calculator.delegateeScoreLock(_delegatee), _isLocked);
  }

  function testFuzz_EmitsAnEventWhenDelegateScoreIsLockedOrUnlocked(
    address _delegatee,
    bool _isLocked
  ) public {
    vm.expectEmit();
    emit DelegateeScoreLockSet(_delegatee, calculator.delegateeScoreLock(_delegatee), _isLocked);
    vm.prank(owner);
    calculator.setDelegateeScoreLock(_delegatee, _isLocked);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(address _caller, address _delegatee, bool _isLocked)
    public
  {
    vm.assume(_caller != owner);
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _caller));
    calculator.setDelegateeScoreLock(_delegatee, _isLocked);
  }
}

contract SetScoreOracle is EarningPowerCalculatorTest {
  function testFuzz_SetsTheScoreOracleAddress(address _newScoreOracle) public {
    vm.prank(owner);
    calculator.setScoreOracle(_newScoreOracle);
    assertEq(calculator.scoreOracle(), _newScoreOracle);
  }

  function testFuzz_EmitsAnEventWhenScoreOracleIsUpdated(address _newScoreOracle) public {
    vm.prank(owner);
    vm.expectEmit();
    emit ScoreOracleSet(scoreOracle, _newScoreOracle);
    calculator.setScoreOracle(_newScoreOracle);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(address _caller, address _newScoreOracle) public {
    vm.assume(_caller != owner);
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _caller));
    calculator.setScoreOracle(_newScoreOracle);
  }
}

contract SetUpdateEligibilityDelay is EarningPowerCalculatorTest {
  function testFuzz_SetsTheUpdateEligibilityDelay(uint256 _newUpdateEligibilityDelay) public {
    vm.prank(owner);
    calculator.setUpdateEligibilityDelay(_newUpdateEligibilityDelay);
    assertEq(calculator.updateEligibilityDelay(), _newUpdateEligibilityDelay);
  }

  function testFuzz_EmitsAnEventWhenUpdateEligibilityDelayIsUpdated(
    uint256 _newUpdateEligibilityDelay
  ) public {
    vm.prank(owner);
    vm.expectEmit();
    emit UpdateEligibilityDelaySet(updateEligibilityDelay, _newUpdateEligibilityDelay);
    calculator.setUpdateEligibilityDelay(_newUpdateEligibilityDelay);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(address _caller, uint256 _newUpdateEligibilityDelay)
    public
  {
    vm.assume(_caller != owner);
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _caller));
    calculator.setUpdateEligibilityDelay(_newUpdateEligibilityDelay);
  }
}

contract SetDelegateScoreEligibilityThreshold is EarningPowerCalculatorTest {
  function testFuzz_SetsTheDelegateScoreEligibilityThreshold(
    uint256 _newDelegateScoreEligibilityThreshold
  ) public {
    vm.prank(owner);
    calculator.setDelegateeScoreEligibilityThreshold(_newDelegateScoreEligibilityThreshold);
    assertEq(calculator.delegateeScoreEligibilityThreshold(), _newDelegateScoreEligibilityThreshold);
  }

  function testFuzz_EmitsAnEventWhenDelegateScoreEligibilityThresholdIsUpdated(
    uint256 _newDelegateScoreEligibilityThreshold
  ) public {
    vm.prank(owner);
    vm.expectEmit();
    emit DelegateeScoreEligibilityThresholdSet(
      delegateeScoreEligibilityThreshold, _newDelegateScoreEligibilityThreshold
    );
    calculator.setDelegateeScoreEligibilityThreshold(_newDelegateScoreEligibilityThreshold);
  }

  function testFuzz_RevertIf_CallerIsNotOwner(
    address _caller,
    uint256 _newDelegateScoreEligibilityThreshold
  ) public {
    vm.assume(_caller != owner);
    vm.prank(_caller);
    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, _caller));
    calculator.setDelegateeScoreEligibilityThreshold(_newDelegateScoreEligibilityThreshold);
  }
}

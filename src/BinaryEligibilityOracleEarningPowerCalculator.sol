// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEarningPowerCalculator} from "src/interfaces/IEarningPowerCalculator.sol";

/// @title BinaryEligibilityOracleEarningPowerCalculator
/// @author [ScopeLift](https://scopelift.co)
/// @notice This contract calculates the earning power of a staker based on their delegatee's score.
contract BinaryEligibilityOracleEarningPowerCalculator is Ownable, IEarningPowerCalculator {
  /// @notice Emitted when a delegatee's score is updated.
  /// @param delegatee The address of the delegatee whose score was updated.
  /// @param oldScore The previous score of the delegatee.
  /// @param newScore The new score assigned to the delegatee.
  event DelegateeScoreUpdated(address indexed delegatee, uint256 oldScore, uint256 newScore);

  /// @notice Emitted when a delegatee's score lock status is updated.
  /// @param delegatee The address of the delegatee whose score lock status was updated.
  /// @param oldState The previous lock state of the delegatee's score.
  /// @param newState The new lock state of the delegatee's score.
  event DelegateeScoreLockStatusSet(address indexed delegatee, bool oldState, bool newState);

  /// @notice Emitted when the `scoreOracle` address is updated.
  /// @param oldScoreOracle The address of the previous `scoreOracle`.
  /// @param newScoreOracle The address of the new `scoreOracle`.
  event ScoreOracleSet(address indexed oldScoreOracle, address indexed newScoreOracle);

  /// @notice Emitted when the oracle pause guardian address is updated.
  /// @param oldOraclePauseGuardian The address of the previous oracle pause guardian.
  /// @param newOraclePauseGuardian The address of the new oracle pause guardian.
  event OraclePauseGuardianSet(
    address indexed oldOraclePauseGuardian, address indexed newOraclePauseGuardian
  );

  /// @notice Emitted when the oracle pause state is updated.
  /// @param oldStatus The previous pause state of the oracle.
  /// @param newStatus The new pause state of the oracle.
  event OraclePausedStatusUpdated(bool oldStatus, bool newStatus);

  /// @notice Emitted when the update eligibility delay is changed.
  /// @param oldDelay The previous update eligibility delay value.
  /// @param newDelay The new update eligibility delay value.
  event UpdateEligibilityDelaySet(uint256 oldDelay, uint256 newDelay);

  /// @notice Emitted when the eligibility threshold score to earn full earning power is updated.
  /// @param oldThreshold The previous threshold value.
  /// @param newThreshold The new threshold value.
  event DelegateeEligibilityThresholdScoreSet(uint256 oldThreshold, uint256 newThreshold);

  /// @notice Error thrown when a non-score oracle address tries to call the `updateDelegateeScore`
  /// function.
  error BinaryEligibilityOracleEarningPowerCalculator__Unauthorized(bytes32 reason, address caller);

  /// @notice Error thrown when an attempt is made to update the score of a delegate when the oracle
  /// is paused by the oraclePauseGuardian.
  error BinaryEligibilityOracleEarningPowerCalculator__DisallowedWhilePaused();

  /// @notice Error thrown when an attempt is made to update the score of a locked delegatee score.
  error BinaryEligibilityOracleEarningPowerCalculator__DelegateeScoreLocked(address delegatee);

  /// @notice The length of oracle downtime before, all stakers' earning power will be set to 100%
  /// of their staked amounts.
  uint256 public immutable STALE_ORACLE_WINDOW;

  /// @notice The address with the authority to update delegatee scores.
  address public scoreOracle;

  /// @notice The address of a caller that can prevent the oracle from updating delegate scores.
  address public oraclePauseGuardian;

  /// @notice A flag indicating whether the oracle's ability to update delegate scores is paused.
  /// @dev When set to true, the `updateDelegateScore` function will not execute, preventing score
  /// updates.
  /// @dev This can be used as a safety measure in case of oracle malfunction or other emergencies.
  bool public isOraclePaused;

  /// @notice The timestamp of the last delegatee score update.
  uint256 public lastOracleUpdateTime;

  /// @notice The minimum score a delegatee must have to be eligible for earning power.
  /// @dev This threshold is used in the `getEarningPower` and `getNewEarningPower` functions.
  /// @dev Delegates with scores below this threshold will have an earning power of 0, and scores
  /// equal or above this threshold will have 100% earning power equal to the staked amount.
  uint256 public delegateeEligibilityThresholdScore;

  /// @notice The minimum delay required between staker earning power updates.
  /// @dev This delay helps stakers react to changes in their delegatee's score without immediate
  /// impact to their earning power.
  uint256 public updateEligibilityDelay;

  /// @notice Mapping to store delegatee scores.
  mapping(address delegatee => uint256 delegateeScore) public delegateeScores;

  /// @notice Mapping to store the last score update timestamp where a delegatee became ineligible.
  /// @dev Key is the delegatee's address, value is the block.timestamp of when a delegatee's score
  /// went below the `delegateeEligibilityThresholdScore`.
  mapping(address delegatee => uint256 timestamp) public timeOfIneligibility;

  /// @notice Mapping to store the lock status of delegate scores.
  mapping(address delegate => bool isLocked) public delegateeScoreLockStatus;

  /// @notice Initializes the EarningPowerCalculator contract.
  /// @param _owner The DAO governor address.
  /// @param _scoreOracle The address of the trusted oracle address.
  /// @param _delegateeScoreEligibilityThreshold The threshold for delegatee score eligibility to
  /// have the full earning power.
  /// @param _updateEligibilityDelay The delay required between delegatee earning power
  /// updates after falling below the eligibility threshold.
  constructor(
    address _owner,
    address _scoreOracle,
    uint256 _staleOracleWindow,
    address _oraclePauseGuardian,
    uint256 _delegateeScoreEligibilityThreshold,
    uint256 _updateEligibilityDelay
  ) Ownable(_owner) {
    _setScoreOracle(_scoreOracle);
    STALE_ORACLE_WINDOW = _staleOracleWindow;
    _setOraclePauseGuardian(_oraclePauseGuardian);
    _setDelegateeScoreEligibilityThreshold(_delegateeScoreEligibilityThreshold);
    _setUpdateEligibilityDelay(_updateEligibilityDelay);
    lastOracleUpdateTime = block.timestamp;
  }

  /// @notice Calculates the earning power for a given delegatee and staking amount.
  /// @param _amountStaked The amount of tokens staked.
  /// @param /* _staker */ The address of the staker.
  /// @param _delegatee The address of the delegatee.
  /// @return The calculated earning power.
  function getEarningPower(uint256 _amountStaked, address, /* _staker */ address _delegatee)
    external
    view
    returns (uint256)
  {
    if (_isOracleStale() || isOraclePaused) return _amountStaked;
    return _isDelegateeEligible(_delegatee) ? _amountStaked : 0;
  }

  /// @notice Calculates the new earning power and determines if it qualifies for an update.`
  /// @param _amountStaked The amount of tokens staked.
  /// @param /* _staker */ The address of the staker.
  /// @param _delegatee The address of the delegatee.
  /// @param /* _oldEarningPower */ The previous earning power value.
  /// @return The newly calculated earning power.
  /// @return Boolean indicating if the new earning power qualifies for an update.
  function getNewEarningPower(
    uint256 _amountStaked,
    address, /* _staker */
    address _delegatee,
    uint256 /* _oldEarningPower */
  ) external view returns (uint256, bool) {
    if (_isOracleStale() || isOraclePaused) return (_amountStaked, true);

    if (!_isDelegateeEligible(_delegatee)) {
      bool _isUpdateDelayElapsed =
        (timeOfIneligibility[_delegatee] + updateEligibilityDelay) <= block.timestamp;
      return (0, _isUpdateDelayElapsed);
    }

    return (_amountStaked, true);
  }

  /// @notice Updates the eligibility score of a delegatee.
  /// @dev This function can only be called by the authorized `scoreOracle` address.
  /// @dev If the delegatee's score is locked, the update will be reverted.
  /// @param _delegatee The address of the delegatee whose score is being updated.
  /// @param _newScore The new score to be assigned to the delegatee.
  function updateDelegateeScore(address _delegatee, uint256 _newScore) public {
    if (msg.sender != scoreOracle) {
      revert BinaryEligibilityOracleEarningPowerCalculator__Unauthorized("not oracle", msg.sender);
    }
    if (delegateeScoreLockStatus[_delegatee]) {
      revert BinaryEligibilityOracleEarningPowerCalculator__DelegateeScoreLocked(_delegatee);
    }
    if (isOraclePaused) {
      revert BinaryEligibilityOracleEarningPowerCalculator__DisallowedWhilePaused();
    }
    _updateDelegateeScore(_delegatee, _newScore);
    lastOracleUpdateTime = block.timestamp;
  }

  /// @notice Overrides the score of a delegatee and locks it.
  /// @dev This function can only be called by the contract owner.
  /// @dev It updates the delegatee's score and then locks it to prevent further updates by the
  /// `scoreOracle`.
  /// @param _delegatee The address of the delegatee whose score is being overridden.
  /// @param _newScore The new score to be assigned to the delegatee.
  function overrideDelegateeScore(address _delegatee, uint256 _newScore) public {
    _checkOwner();
    _updateDelegateeScore(_delegatee, _newScore);
    _setDelegateeScoreLock(_delegatee, true);
  }

  /// @notice Sets or removes the lock on a delegatee's score.
  /// @dev This function can only be called by the contract owner.
  /// @dev When a delegatee's score is locked, it cannot be updated by the `scoreOracle`.
  /// @dev This function is useful for manually overriding and protecting a delegatee's score.
  /// @param _delegatee The address of the delegatee whose score lock status is being modified.
  /// @param _isLocked The new lock status to set. True to lock the score, false to unlock.
  function setDelegateeScoreLock(address _delegatee, bool _isLocked) public {
    _checkOwner();
    _setDelegateeScoreLock(_delegatee, _isLocked);
  }

  /// @notice Sets a new address as the ScoreOracle contract.
  /// @dev This function can only be called by the contract owner.
  /// @param _newScoreOracle The address of the new ScoreOracle contract.
  function setScoreOracle(address _newScoreOracle) public {
    _checkOwner();
    _setScoreOracle(_newScoreOracle);
  }

  /// @notice Sets a new update eligibility delay.
  /// @dev This function can only be called by the contract owner.
  /// @param _newUpdateEligibilityDelay The new delay value to set.
  function setUpdateEligibilityDelay(uint256 _newUpdateEligibilityDelay) public {
    _checkOwner();
    _setUpdateEligibilityDelay(_newUpdateEligibilityDelay);
  }

  /// @notice Sets a new delegatee score eligibility threshold.
  /// @dev This function can only be called by the contract owner.
  /// @param _newDelegateeScoreEligibilityThreshold The new threshold value to set.
  function setDelegateeScoreEligibilityThreshold(uint256 _newDelegateeScoreEligibilityThreshold)
    public
  {
    _checkOwner();
    _setDelegateeScoreEligibilityThreshold(_newDelegateeScoreEligibilityThreshold);
  }

  /// @notice Internal function to update a delegatee's score.
  /// @dev This function updates the delegatee's score, emits an event, and records the update time.
  /// @param _delegatee The address of the delegatee whose score is being updated.
  /// @param _newScore The new score to be assigned to the delegatee.
  function _updateDelegateeScore(address _delegatee, uint256 _newScore) internal {
    uint256 _oldScore = delegateeScores[_delegatee];
    bool _previouslyEligible = _oldScore >= delegateeEligibilityThresholdScore;
    bool _newlyEligible = _newScore >= delegateeEligibilityThresholdScore;
    emit DelegateeScoreUpdated(_delegatee, _oldScore, _newScore);
    // Record the time if the new score crosses the eligibility threshold.
    if (_previouslyEligible && !_newlyEligible) timeOfIneligibility[_delegatee] = block.timestamp;
    delegateeScores[_delegatee] = _newScore;
  }

  /// @notice Sets the pause state of the oracle.
  /// @dev This function can only be called by the oraclePauseGuardian.
  /// @dev When the oracle is paused, delegate scores cannot be updated via updateDelegateScore.
  /// @param _pauseOracle The new pause state to set for the oracle.
  function setOracleState(bool _pauseOracle) public {
    if (msg.sender != oraclePauseGuardian) {
      revert BinaryEligibilityOracleEarningPowerCalculator__Unauthorized(
        "not oracle pause guardian", msg.sender
      );
    }
    emit OraclePausedStatusUpdated(isOraclePaused, _pauseOracle);
    isOraclePaused = _pauseOracle;
  }

  /// @notice Sets a new address as the Oracle Pause Guardian.
  /// @dev This function can only be called by the contract owner.
  /// @dev The Oracle Pause Guardian has the authority to pause the oracle's ability to update
  /// delegate scores.
  /// @param _newOraclePauseGuardian The address of the new Oracle Pause Guardian to be set.
  function setOraclePauseGuardian(address _newOraclePauseGuardian) public {
    _checkOwner();
    _setOraclePauseGuardian(_newOraclePauseGuardian);
  }

  /// @notice Checks if the oracle's last update is considered stale.
  /// @dev An oracle is considered stale if the time since its last update exceeds the
  /// STALE_ORACLE_WINDOW.
  /// @return bool Returns true if the oracle is stale, false otherwise.
  function _isOracleStale() internal view returns (bool) {
    return block.timestamp - lastOracleUpdateTime > STALE_ORACLE_WINDOW;
  }

  /// @notice Determines if a delegatee is eligible based on their score.
  /// @dev A delegatee is considered eligible if their score is greater than or equal to the
  /// eligibility threshold.
  /// @param _delegatee The address of the delegatee to check.
  /// @return bool Returns true if the delegatee is eligible, false otherwise.
  function _isDelegateeEligible(address _delegatee) internal view returns (bool) {
    return delegateeScores[_delegatee] >= delegateeEligibilityThresholdScore;
  }

  /// @notice Internal function to set a new oracle pause guardian address.
  /// @dev This function updates the oraclePauseGuardian address and emits an event.
  /// @dev The oracle pause guardian has the authority to pause the oracle's ability to update
  /// delegate scores.
  /// @param _newOraclePauseGuardian The address of the new oracle pause guardian.
  function _setOraclePauseGuardian(address _newOraclePauseGuardian) internal {
    emit OraclePauseGuardianSet(oraclePauseGuardian, _newOraclePauseGuardian);
    oraclePauseGuardian = _newOraclePauseGuardian;
  }

  /// @notice Internal function to set or remove the lock on a delegatee's score.
  /// @dev This function updates the lock status of a delegatee's score and emits an event.
  /// @dev When a delegatee's score is locked, it cannot be updated by the `scoreOracle`.
  /// @param _delegatee The address of the delegatee whose score lock status is being modified.
  /// @param _isLocked The new lock status to set. True to lock the score, false to unlock.
  function _setDelegateeScoreLock(address _delegatee, bool _isLocked) internal {
    emit DelegateeScoreLockStatusSet(_delegatee, delegateeScoreLockStatus[_delegatee], _isLocked);
    delegateeScoreLockStatus[_delegatee] = _isLocked;
  }

  /// @notice Internal function to set a new score oracle address.
  /// @dev This function updates the scoreOracle address and emits an event.
  /// @param _newScoreOracle The address of the new score oracle.
  function _setScoreOracle(address _newScoreOracle) internal {
    emit ScoreOracleSet(scoreOracle, _newScoreOracle);
    scoreOracle = _newScoreOracle;
  }

  /// @notice Internal function to set a new update eligibility delay.
  /// @dev This function updates the updateEligibilityDelay and emits an event.
  /// @param _newUpdateEligibilityDelay The new delay value to set.
  function _setUpdateEligibilityDelay(uint256 _newUpdateEligibilityDelay) internal {
    emit UpdateEligibilityDelaySet(updateEligibilityDelay, _newUpdateEligibilityDelay);
    updateEligibilityDelay = _newUpdateEligibilityDelay;
  }

  /// @notice Internal function to set a new delegatee score eligibility threshold.
  /// @dev This function updates the delegateeEligibilityThresholdScore and emits an event.
  /// @param _newDelegateeScoreEligibilityThreshold The new threshold value to set.
  function _setDelegateeScoreEligibilityThreshold(uint256 _newDelegateeScoreEligibilityThreshold)
    internal
  {
    emit DelegateeEligibilityThresholdScoreSet(
      delegateeEligibilityThresholdScore, _newDelegateeScoreEligibilityThreshold
    );
    delegateeEligibilityThresholdScore = _newDelegateeScoreEligibilityThreshold;
  }
}

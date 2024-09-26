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
  event DelegateeScoreLockSet(address indexed delegatee, bool oldState, bool newState);

  /// @notice Emitted when the ScoreOracle address is updated.
  /// @param oldScoreOracle The address of the previous ScoreOracle.
  /// @param newScoreOracle The address of the new ScoreOracle.
  event ScoreOracleSet(address indexed oldScoreOracle, address indexed newScoreOracle);

  /// @notice Emitted when the update eligibility delay is changed.
  /// @param oldDelay The previous update eligibility delay value.
  /// @param newDelay The new update eligibility delay value.
  event UpdateEligibilityDelaySet(uint256 oldDelay, uint256 newDelay);

  /// @notice Emitted when the delegatee score eligibility threshold to earn the full earning power
  /// for its stakers is updated.
  /// @param oldThreshold The previous threshold value.
  /// @param newThreshold The new threshold value set.
  event DelegateeScoreEligibilityThresholdSet(uint256 oldThreshold, uint256 newThreshold);

  /// @notice Error thrown when a non-scoreOracle address tries to call the updateDelegateeScore
  /// function.
  error Unauthorized(bytes32 reason, address caller);

  /// @notice Error thrown when an attempt is made to update the score of a locked delegatee score.
  error DelegateeScoreLocked(address delegatee);

  /// @notice After the 7-day stale oracle window, all stakers' earning power will be set to 100% of
  /// their staked amounts.
  uint256 public constant STALE_ORACLE_WINDOW = 7 days; // TODO: Update to appropriate time frame.

  /// @notice The address with the authority to update delegatee scores.
  address public scoreOracle;

  /// @notice The timestamp of the last delegatee score update.
  uint256 public lastOracleUpdateTime;

  /// @notice The minimum score a delegatee must have to be eligible for earning power.
  /// @dev This threshold is used in the getEarningPower and getNewEarningPower functions.
  /// @dev Delegates with scores below this threshold will have an earning power of 0, and scores
  /// equal or above this threshold will have 100% earning power equal to the staked amount.
  uint256 public delegateeScoreEligibilityThreshold;

  /// @notice The minimum delay required between staker earning power updates.
  /// @dev This delay helps stakers react to changes in their delegatee's score without immediate
  /// impact to their earning power.
  uint256 public updateEligibilityDelay;

  /// @notice Mapping to store delegatee scores.
  mapping(address delegatee => uint256 delegateeScore) public delegateeScores;

  /// @notice Mapping to store the last score update timestamp where a delegatee's eligibility
  /// changed.
  /// @dev Key is the delegatee's address, value is the block.timestamp of the last eligibility
  /// update.
  mapping(address delegatee => uint256 timestamp) public lastDelegateeEligibilityChangeTime;

  /// @notice Mapping to store the lock status of delegate scores.
  mapping(address delegate => bool isLocked) public delegateeScoreLock;

  /// @notice Initializes the EarningPowerCalculator contract.
  /// @param _owner The DAO governor address.
  /// @param _scoreOracle The address of the trusted Karma address.
  /// @param _delegateeScoreEligibilityThreshold The threshold for delegatee score eligibility to
  /// have
  /// the full earning power.
  /// @param _updateEligibilityDelay The delay required between delegatee earning power
  /// updates after falling below the eligibility threshold.
  constructor(
    address _owner,
    address _scoreOracle,
    uint256 _delegateeScoreEligibilityThreshold,
    uint256 _updateEligibilityDelay
  ) Ownable(_owner) {
    scoreOracle = _scoreOracle;
    delegateeScoreEligibilityThreshold = _delegateeScoreEligibilityThreshold;
    updateEligibilityDelay = _updateEligibilityDelay;

    emit ScoreOracleSet(address(0), _scoreOracle);
    emit DelegateeScoreEligibilityThresholdSet(0, _delegateeScoreEligibilityThreshold);
    emit UpdateEligibilityDelaySet(0, _updateEligibilityDelay);
  }

  /// @notice Calculates the earning power for a given delegatee and staking amount.
  /// @param _amountStaked The amount of tokens staked.
  /// @param _staker The address of the staker.
  /// @param _delegatee The address of the delegatee.
  /// @return _earningPower The calculated earning power.
  function getEarningPower(uint256 _amountStaked, address _staker, address _delegatee)
    external
    view
    returns (uint256 _earningPower)
  {
    // If the oracle has not been updated for more than the stale oracle window, return full earning
    // power and is qualified for update.
    if (block.timestamp - lastOracleUpdateTime > STALE_ORACLE_WINDOW) _earningPower = _amountStaked;
    // If the delegatee's score is below the eligibility threshold, return 0 earning power.
    else if (delegateeScores[_delegatee] < delegateeScoreEligibilityThreshold) _earningPower = 0;
    // If the delegatee's score is above the eligibility threshold, return full earning power.
    else _earningPower = _amountStaked;
  }

  /// @notice Calculates the new earning power and determines if it qualifies for an update.`
  /// @param _amountStaked The amount of tokens staked.
  /// @param _staker The address of the staker.
  /// @param _delegatee The address of the delegatee.
  /// @param _oldEarningPower The previous earning power value.
  /// @return _newEarningPower The newly calculated earning power.
  /// @return _isQualifiedForUpdate Boolean indicating if the new earning power qualifies for an
  /// update.
  function getNewEarningPower(
    uint256 _amountStaked,
    address _staker,
    address _delegatee,
    uint256 _oldEarningPower
  ) external view returns (uint256 _newEarningPower, bool _isQualifiedForUpdate) {
    // If the oracle has not been updated for more than the stale oracle window, return full earning
    // power and is qualified for update.
    if (block.timestamp - lastOracleUpdateTime > STALE_ORACLE_WINDOW) {
      _newEarningPower = _amountStaked;
      _isQualifiedForUpdate = true;
      // If the delegatee's score is below the eligibility threshold, return 0 earning power.
    } else if (delegateeScores[_delegatee] < delegateeScoreEligibilityThreshold) {
      // check if the update eligibility has passed, if it hasn't, it's not qualified for an update.
      if (
        (lastDelegateeEligibilityChangeTime[_delegatee] + updateEligibilityDelay) > block.timestamp
      ) _isQualifiedForUpdate = false;
      // If the update eligibility has passed then it's qualified for an update.
      else _isQualifiedForUpdate = true;
      _newEarningPower = 0;
      // If the delegatee's score is above the eligibility threshold, return full earning power and
      // is qualified for an update.
    } else {
      _newEarningPower = _amountStaked;
      _isQualifiedForUpdate = true;
    }
  }

  /// @notice Updates the score of a delegatee.
  /// @dev This function can only be called by the authorized scoreOracle address.
  /// @dev If the delegatee's score is locked, the update will be reverted.
  /// @param _delegatee The address of the delegatee whose score is being updated.
  /// @param _newScore The new score to be assigned to the delegatee.
  function updateDelegateeScore(address _delegatee, uint256 _newScore) public {
    if (msg.sender != scoreOracle) revert Unauthorized("not oracle", msg.sender);
    if (delegateeScoreLock[_delegatee]) revert DelegateeScoreLocked(_delegatee);
    _updateDelegateeScore(_delegatee, _newScore);
    lastOracleUpdateTime = block.timestamp;
  }

  /// @notice Overrides the score of a delegatee and locks it.
  /// @dev This function can only be called by the contract owner.
  /// @dev It updates the delegatee's score and then locks it to prevent further updates by the
  /// scoreOracle.
  /// @param _delegatee The address of the delegatee whose score is being overridden.
  /// @param _newScore The new score to be assigned to the delegatee.
  function overrideDelegateeScore(address _delegatee, uint256 _newScore) public onlyOwner {
    _updateDelegateeScore(_delegatee, _newScore);
    setDelegateeScoreLock(_delegatee, true);
  }

  /// @notice Sets or removes the lock on a delegatee's score.
  /// @dev This function can only be called by the contract owner.
  /// @dev When a delegatee's score is locked, it cannot be updated by the scoreOracle.
  /// @dev This function is useful for manually overriding and protecting a delegatee's score.
  /// @param _delegatee The address of the delegatee whose score lock status is being modified.
  /// @param _isLocked The new lock status to set. True to lock the score, false to unlock.
  function setDelegateeScoreLock(address _delegatee, bool _isLocked) public onlyOwner {
    emit DelegateeScoreLockSet(_delegatee, delegateeScoreLock[_delegatee], _isLocked);
    delegateeScoreLock[_delegatee] = _isLocked;
  }

  /// @notice Sets a new address as the ScoreOracle contract.
  /// @dev This function can only be called by the contract owner.
  /// @param _newScoreOracle The address of the new ScoreOracle contract.
  function setScoreOracle(address _newScoreOracle) public onlyOwner {
    emit ScoreOracleSet(scoreOracle, _newScoreOracle);
    scoreOracle = _newScoreOracle;
  }

  /// @notice Sets a new update eligibility delay.
  /// @dev This function can only be called by the contract owner.
  /// @param _newUpdateEligibilityDelay The new delay value to set.
  function setUpdateEligibilityDelay(uint256 _newUpdateEligibilityDelay) public onlyOwner {
    emit UpdateEligibilityDelaySet(updateEligibilityDelay, _newUpdateEligibilityDelay);
    updateEligibilityDelay = _newUpdateEligibilityDelay;
  }

  function setDelegateeScoreEligibilityThreshold(uint256 _newDelegateeScoreEligibilityThreshold)
    public
    onlyOwner
  {
    emit DelegateeScoreEligibilityThresholdSet(
      delegateeScoreEligibilityThreshold, _newDelegateeScoreEligibilityThreshold
    );
    delegateeScoreEligibilityThreshold = _newDelegateeScoreEligibilityThreshold;
  }

  /// @notice Internal function to update a delegatee's score.
  /// @dev This function updates the delegatee's score, emits an event, and records the update time.
  /// @param _delegatee The address of the delegatee whose score is being updated.
  /// @param _newScore The new score to be assigned to the delegatee.
  function _updateDelegateeScore(address _delegatee, uint256 _newScore) internal {
    uint256 _currentDelegateeScore = delegateeScores[_delegatee];
    bool _currentlyEligible = _currentDelegateeScore >= delegateeScoreEligibilityThreshold;
    bool _newlyEligible = _newScore >= delegateeScoreEligibilityThreshold;
    emit DelegateeScoreUpdated(_delegatee, _currentDelegateeScore, _newScore);
    // Record the time if the new score crosses the eligibility threshold.
    if (_currentlyEligible != _newlyEligible) {
      lastDelegateeEligibilityChangeTime[_delegatee] = block.timestamp;
    }
    delegateeScores[_delegatee] = _newScore;
  }
}

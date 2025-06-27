// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {BinaryEligibilityOracleEarningPowerCalculator} from
  "./BinaryEligibilityOracleEarningPowerCalculator.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract BinaryVotingPowerEarningPowerCalculator is BinaryEligibilityOracleEarningPowerCalculator {
  uint48 public votingPowerUpdateFrequency;
  uint48 public immutable UPDATE_START_TIME;
  address public immutable VOTING_POWER_TOKEN;

  constructor(
    address _owner,
    address _scoreOracle,
    uint256 _staleOracleWindow,
    address _oraclePauseGuardian,
    uint256 _delegateeScoreEligibilityThreshold,
    uint256 _updateEligibilityDelay,
    uint48 _votingPowerUpdateFrequency,
    address _votingPowerToken
  )
    BinaryEligibilityOracleEarningPowerCalculator(
      _owner,
      _scoreOracle,
      _staleOracleWindow,
      _oraclePauseGuardian,
      _delegateeScoreEligibilityThreshold,
      _updateEligibilityDelay
    )
  {
    _setVotingPowerUpdateFrequency(_votingPowerUpdateFrequency);
    UPDATE_START_TIME = uint48(block.number);
    VOTING_POWER_TOKEN = _votingPowerToken;
  }

  function getEarningPower(uint256, /* _amountStaked */ address, /* _staker */ address _delegatee)
    external
    view
    virtual
    override
    returns (uint256)
  {
    uint48 _votingPowerTimepoint = _getVotingPowerTimepoint();
    uint256 _votingPower =
      IVotes(VOTING_POWER_TOKEN).getPastVotes(_delegatee, _votingPowerTimepoint);

    if (_isOracleStale() || isOraclePaused) return _votingPower;
    return _isDelegateeEligible(_delegatee) ? _votingPower : 0;
  }

  function getNewEarningPower(
    uint256, /* _amountStaked */
    address, /* _staker */
    address _delegatee,
    uint256 /* _oldEarningPower */
  ) external view virtual override returns (uint256, bool) {
    uint48 _votingPowerTimepoint = _getVotingPowerTimepoint();
    uint256 _votingPower =
      IVotes(VOTING_POWER_TOKEN).getPastVotes(_delegatee, _votingPowerTimepoint);

    // TODO: Do we want the same fallback behavior.
    // Should we instead accept the stale values if paused?
    if (_isOracleStale() || isOraclePaused) return (_votingPower, true);

    if (!_isDelegateeEligible(_delegatee)) {
      bool _isUpdateDelayElapsed =
        (timeOfIneligibility[_delegatee] + updateEligibilityDelay) <= block.timestamp;
      return (0, _isUpdateDelayElapsed);
    }

    return (_votingPower, true);
  }

  // Add method to set rolling timepoint
  function setVotingPowerUpdateFrequency(uint48 _updateFrequency) external {
    _checkOwner();
    _setVotingPowerUpdateFrequency(_updateFrequency);
  }

  function _setVotingPowerUpdateFrequency(uint48 _updateFrequency) internal {
    votingPowerUpdateFrequency = _updateFrequency;
  }

  // Add method to get the score at that rolling timepoint
  function _getVotingPowerTimepoint() internal view returns (uint48) {
    return uint48(block.number - ((block.number - UPDATE_START_TIME) % votingPowerUpdateFrequency));
  }
}

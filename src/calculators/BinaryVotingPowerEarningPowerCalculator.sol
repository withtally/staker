// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {BinaryEligibilityOracleEarningPowerCalculator} from
  "./BinaryEligibilityOracleEarningPowerCalculator.sol";
import {IEarningPowerCalculator} from "../interfaces/IEarningPowerCalculator.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BinaryVotingPowerEarningPowerCalculator is Ownable, IEarningPowerCalculator {
  uint48 public votingPowerUpdateFrequency;
  uint48 public immutable UPDATE_START_TIME;
  address public immutable VOTING_POWER_TOKEN;
  BinaryEligibilityOracleEarningPowerCalculator public eligibilityModule;

  constructor(
    address _owner,
    address _eligibilityAddress,
    address _votingPowerToken,
    uint48 _votingPowerUpdateFrequency
  ) Ownable(_owner) {
    _setVotingPowerUpdateFrequency(_votingPowerUpdateFrequency);
    eligibilityModule = BinaryEligibilityOracleEarningPowerCalculator(_eligibilityAddress);
    UPDATE_START_TIME = uint48(block.number);
    VOTING_POWER_TOKEN = _votingPowerToken;
  }

  function getEarningPower(uint256, /* _amountStaked */ address, /* _staker */ address _delegatee)
    external
    view
    virtual
    returns (uint256)
  {
    uint48 _votingPowerTimepoint = _getVotingPowerTimepoint();
    uint256 _votingPower =
      IVotes(VOTING_POWER_TOKEN).getPastVotes(_delegatee, _votingPowerTimepoint);

    if (_isOracleStale() || eligibilityModule.isOraclePaused()) return _votingPower;

    return _isDelegateeEligible(_delegatee) ? _votingPower : 0;
  }

  function getNewEarningPower(
    uint256, /* _amountStaked */
    address, /* _staker */
    address _delegatee,
    uint256 /* _oldEarningPower */
  ) external view virtual returns (uint256, bool) {
    uint48 _votingPowerTimepoint = _getVotingPowerTimepoint();
    uint256 _votingPower =
      IVotes(VOTING_POWER_TOKEN).getPastVotes(_delegatee, _votingPowerTimepoint);

    // TODO: Do we want the same fallback behavior.
    // Should we instead accept the stale values if paused?
    if (_isOracleStale() || eligibilityModule.isOraclePaused()) return (_votingPower, true);

    return _isDelegateeEligible(_delegatee) ? (_votingPower, true) : (0, true);
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

  function _isOracleStale() internal view returns (bool) {
    return block.timestamp - eligibilityModule.lastOracleUpdateTime()
      > eligibilityModule.STALE_ORACLE_WINDOW();
  }

  function _isDelegateeEligible(address _delegatee) internal view returns (bool) {
    return eligibilityModule.delegateeScores(_delegatee)
      >= eligibilityModule.delegateeEligibilityThresholdScore();
  }
}

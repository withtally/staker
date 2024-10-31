// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {DelegationSurrogate} from "src/DelegationSurrogate.sol";
import {DelegationSurrogateVotes} from "src/DelegationSurrogateVotes.sol";
import {GovernanceStaker} from "src/GovernanceStaker.sol";

abstract contract GovernanceStakerDelegateSurrogateVotes is GovernanceStaker {
  /// @notice Emitted when a surrogate contract is deployed.
  event SurrogateDeployed(address indexed delegatee, address indexed surrogate);

  /// @notice Internal method which finds the existing surrogate contract—or deploys a new one if
  /// none exists—for a given delegatee.
  /// @param _delegatee Account for which a surrogate is sought.
  /// @return _surrogate The address of the surrogate contract for the delegatee.
  function _fetchOrDeploySurrogate(address _delegatee)
    internal
    virtual
    override
    returns (DelegationSurrogate _surrogate)
  {
    _surrogate = surrogates[_delegatee];

    if (address(_surrogate) == address(0)) {
      _surrogate = new DelegationSurrogateVotes(STAKE_TOKEN, _delegatee);
      surrogates[_delegatee] = _surrogate;
      emit SurrogateDeployed(_delegatee, address(_surrogate));
    }
  }
}

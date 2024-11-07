// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {DelegationSurrogate} from "src/DelegationSurrogate.sol";
import {DelegationSurrogateVotes} from "src/DelegationSurrogateVotes.sol";
import {GovernanceStaker} from "src/GovernanceStaker.sol";
import {IERC20Staking} from "src/interfaces/IERC20Staking.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";

abstract contract GovernanceStakerDelegateSurrogateVotes is GovernanceStaker {
  IERC20Delegates private VOTING_TOKEN;

  /// @notice Thrown if an inheritor uses a seperate staking token.
  error UnauthorizedToken();

  constructor(IERC20Delegates _votingToken) {
    if (address(STAKE_TOKEN) != address(_votingToken)) revert UnauthorizedToken();
    VOTING_TOKEN = _votingToken;
  }

  /// @notice Emitted when a surrogate contract is deployed.
  event SurrogateDeployed(address indexed delegatee, address indexed surrogate);

  /// @notice Maps the account of each governance delegate with the surrogate contract which holds
  /// the staked tokens from deposits which assign voting weight to said delegate.
  mapping(address delegatee => DelegationSurrogate surrogate) private storedSurrogates;

  function surrogates(address _delegatee) public view override returns (DelegationSurrogate) {
    return storedSurrogates[_delegatee];
  }

  /// @inheritdoc GovernanceStaker
  function _fetchOrDeploySurrogate(address _delegatee)
    internal
    virtual
    override
    returns (DelegationSurrogate _surrogate)
  {
    _surrogate = storedSurrogates[_delegatee];

    if (address(_surrogate) == address(0)) {
      _surrogate = new DelegationSurrogateVotes(VOTING_TOKEN, _delegatee);
      storedSurrogates[_delegatee] = _surrogate;
      emit SurrogateDeployed(_delegatee, address(_surrogate));
    }
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {DelegationSurrogate} from "src/DelegationSurrogate.sol";
import {DelegationSurrogateVotes} from "src/DelegationSurrogateVotes.sol";
import {GovernanceStaker} from "src/GovernanceStaker.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";

/// @title GovernaceStakerDelegateSurrogateVotes
/// @author [ScopeLift](https://scopelift.co)
/// @notice This contract extension adds delegation surrogates to the GovernanceStaker base
/// contract,
/// allowing staked tokens to be delegated to a specific delegate.
abstract contract GovernanceStakerDelegateSurrogateVotes is GovernanceStaker {
  /// @notice A staking token that conforms to the interface needed for this extension.
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

  /// @inheritdoc GovernanceStaker
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

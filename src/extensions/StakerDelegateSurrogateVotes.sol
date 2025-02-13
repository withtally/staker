// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {DelegationSurrogate} from "src/DelegationSurrogate.sol";
import {DelegationSurrogateVotes} from "src/DelegationSurrogateVotes.sol";
import {Staker} from "src/Staker.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";

/// @title StakerDelegateSurrogateVotes
/// @author [ScopeLift](https://scopelift.co)
/// @notice This contract extension adds delegation surrogates to the Staker base
/// contract, allowing staked tokens to be delegated to a specific delegate.
abstract contract StakerDelegateSurrogateVotes is Staker {
  /// @notice Emitted when a surrogate contract is deployed.
  event SurrogateDeployed(address indexed delegatee, address indexed surrogate);

  /// @notice Maps the account of each governance delegate with the surrogate contract which holds
  /// the staked tokens from deposits which assign voting weight to said delegate.
  mapping(address delegatee => DelegationSurrogate surrogate) private storedSurrogates;

  /// @notice Thrown if an inheritor misconfigures the staking token on deployment.
  error StakerDelegateSurrogateVotes__UnauthorizedToken();

  /// @param _votingToken The token that is used for voting, which must be the same as the parent
  /// Staker's STAKE_TOKEN.
  constructor(IERC20Delegates _votingToken) {
    if (address(STAKE_TOKEN) != address(_votingToken)) {
      revert StakerDelegateSurrogateVotes__UnauthorizedToken();
    }
  }

  /// @inheritdoc Staker
  function surrogates(address _delegatee) public view override returns (DelegationSurrogate) {
    return storedSurrogates[_delegatee];
  }

  /// @inheritdoc Staker
  function _fetchOrDeploySurrogate(address _delegatee)
    internal
    virtual
    override
    returns (DelegationSurrogate _surrogate)
  {
    _surrogate = storedSurrogates[_delegatee];

    if (address(_surrogate) == address(0)) {
      _surrogate = new DelegationSurrogateVotes(IERC20Delegates(address(STAKE_TOKEN)), _delegatee);
      storedSurrogates[_delegatee] = _surrogate;
      emit SurrogateDeployed(_delegatee, address(_surrogate));
    }
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {DelegationSurrogate} from "../DelegationSurrogate.sol";
import {DelegationSurrogateVotes} from "../DelegationSurrogateVotes.sol";
import {StakerUpgradeable} from "../StakerUpgradeable.sol";
import {IERC20Delegates} from "../interfaces/IERC20Delegates.sol";

/// @title StakerDelegateSurrogateVotes
/// @author [ScopeLift](https://scopelift.co)
/// @notice This contract extension adds delegation surrogates to the Staker base
/// contract, allowing staked tokens to be delegated to a specific delegate.
abstract contract StakerDelegateSurrogateVotesUpgradeable is StakerUpgradeable {
  /// @notice Emitted when a surrogate contract is deployed.
  event SurrogateDeployed(address indexed delegatee, address indexed surrogate);

  /// @notice Thrown if an inheritor misconfigures the staking token on deployment.
  error StakerDelegateSurrogateVotesUpgradeable__UnauthorizedToken();

  struct StakerDelegateSurrogateVotesStorage {
    /// @notice Maps the account of each governance delegate with the surrogate contract which holds
    /// the staked tokens from deposits which assign voting weight to said delegate.
    mapping(address delegatee => DelegationSurrogate surrogate) _storedSurrogates;
  }

  // keccak256(abi.encode(uint256(keccak256("storage.scopelift.StakerDelegateSurrogateVotes")) - 1))
  // &~bytes32(uint256(0xff))
  bytes32 private constant STAKER_DELEGATE_SURROGATE_STORAGE_LOCATION =
    0x010103b2a019a28f51fa63a98fe162dac866120b721518e29f318125463ff100;

  function _getStakerDelegateSurrogateStorage()
    private
    pure
    returns (StakerDelegateSurrogateVotesStorage storage $)
  {
    assembly {
      $.slot := STAKER_DELEGATE_SURROGATE_STORAGE_LOCATION
    }
  }

  /// @notice Initializes the `StakerDelegateSurrogateVotesUpgradeable` contract.
  /// @param _votingToken The token that is used for voting, which must be the same as the parent
  /// Staker's STAKE_TOKEN.
  function __StakerDelegateSurrogateVotesUpgradeable_init(IERC20Delegates _votingToken)
    internal
    onlyInitializing
  {
    __StakerDelegateSurrogateVotesUpgradeable_init_unchained(_votingToken);
  }

  /// @notice Initializes the `StakerDelegateSurrogateVotesUpgradeable` contract.
  /// @param _votingToken The token that is used for voting, which must be the same as the parent
  /// Staker's STAKE_TOKEN.
  function __StakerDelegateSurrogateVotesUpgradeable_init_unchained(IERC20Delegates _votingToken)
    internal
    onlyInitializing
  {
    if (address(STAKE_TOKEN()) != address(_votingToken)) {
      revert StakerDelegateSurrogateVotesUpgradeable__UnauthorizedToken();
    }
  }

  /// @inheritdoc StakerUpgradeable
  function surrogates(address _delegatee) public view override returns (DelegationSurrogate) {
    StakerDelegateSurrogateVotesStorage storage $ = _getStakerDelegateSurrogateStorage();
    return $._storedSurrogates[_delegatee];
  }

  /// @notice Maps the account of each governance delegate with the surrogate contract.
  /// @param _delegatee The address of the delegatee.
  /// @return The surrogate contract address for the given delegatee.
  function storedSurrogates(address _delegatee) public view returns (DelegationSurrogate) {
    StakerDelegateSurrogateVotesStorage storage $ = _getStakerDelegateSurrogateStorage();
    return $._storedSurrogates[_delegatee];
  }

  /// @inheritdoc StakerUpgradeable
  function _fetchOrDeploySurrogate(address _delegatee)
    internal
    virtual
    override
    returns (DelegationSurrogate _surrogate)
  {
    StakerDelegateSurrogateVotesStorage storage $ = _getStakerDelegateSurrogateStorage();
    _surrogate = $._storedSurrogates[_delegatee];

    if (address(_surrogate) == address(0)) {
      _surrogate = new DelegationSurrogateVotes(IERC20Delegates(address(STAKE_TOKEN())), _delegatee);
      $._storedSurrogates[_delegatee] = _surrogate;
      emit SurrogateDeployed(_delegatee, address(_surrogate));
    }
  }
}

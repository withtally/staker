// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {GovernanceStaker} from "src/GovernanceStaker.sol";
import {SignatureChecker} from "openzeppelin/utils/cryptography/SignatureChecker.sol";
import {EIP712} from "openzeppelin/utils/cryptography/EIP712.sol";
import {Nonces} from "openzeppelin/utils/Nonces.sol";

/// @title GovernanceStakerOnBehalf
/// @author [ScopeLift](https://scopelift.co)
/// @notice This contract extension adds signature execution functionality to the GovernanceStaker
/// base contract, allowing key operations to be executed via signatures rather than requiring the
/// owner or claimer to execute transactions directly. This includes staking, withdrawing,
/// altering delegatees and claimers, and claiming rewards. Each operation requires a unique
/// signature that is validated against the appropriate signer (owner or claimer) before
/// execution.
abstract contract GovernanceStakerOnBehalf is GovernanceStaker, EIP712, Nonces {
  /// @notice Thrown when an onBehalf method is called with a deadline that has expired.
  error GovernanceStakerOnBehalf__ExpiredDeadline();

  /// @notice Thrown if a caller supplies an invalid signature to a method that requires one.
  error GovernanceStakerOnBehalf__InvalidSignature();

  /// @notice Type hash used when encoding data for `stakeOnBehalf` calls.
  bytes32 public constant STAKE_TYPEHASH = keccak256(
    "Stake(uint256 amount,address delegatee,address claimer,address depositor,uint256 nonce,uint256 deadline)"
  );
  /// @notice Type hash used when encoding data for `stakeMoreOnBehalf` calls.
  bytes32 public constant STAKE_MORE_TYPEHASH = keccak256(
    "StakeMore(uint256 depositId,uint256 amount,address depositor,uint256 nonce,uint256 deadline)"
  );
  /// @notice Type hash used when encoding data for `alterDelegateeOnBehalf` calls.
  bytes32 public constant ALTER_DELEGATEE_TYPEHASH = keccak256(
    "AlterDelegatee(uint256 depositId,address newDelegatee,address depositor,uint256 nonce,uint256 deadline)"
  );
  /// @notice Type hash used when encoding data for `alterClaimerOnBehalf` calls.
  bytes32 public constant ALTER_CLAIMER_TYPEHASH = keccak256(
    "AlterClaimer(uint256 depositId,address newClaimer,address depositor,uint256 nonce,uint256 deadline)"
  );
  /// @notice Type hash used when encoding data for `withdrawOnBehalf` calls.
  bytes32 public constant WITHDRAW_TYPEHASH = keccak256(
    "Withdraw(uint256 depositId,uint256 amount,address depositor,uint256 nonce,uint256 deadline)"
  );
  /// @notice Type hash used when encoding data for `claimRewardOnBehalf` calls.
  bytes32 public constant CLAIM_REWARD_TYPEHASH =
    keccak256("ClaimReward(uint256 depositId,uint256 nonce,uint256 deadline)");

  /// @notice Returns the domain separator used in the encoding of the signatures for this contract.
  /// @return The domain separator, as a bytes32 value, used for EIP-712 signatures.
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparatorV4();
  }

  /// @notice Allows an address to increment their nonce and therefore invalidate any pending signed
  /// actions.
  function invalidateNonce() external virtual {
    _useNonce(msg.sender);
  }

  /// @notice Stake tokens to a new deposit on behalf of a user, using a signature to validate the
  /// user's intent. The caller must pre-approve the staking contract to spend at least the
  /// would-be staked amount of the token.
  /// @param _amount Quantity of the staking token to stake.
  /// @param _delegatee Address to assign the governance voting weight of the staked tokens.
  /// @param _claimer Address that will accrue rewards for this stake.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _deadline The timestamp after which the signature should expire.
  /// @param _signature Signature of the user authorizing this stake.
  /// @return _depositId Unique identifier for this deposit.
  /// @dev Neither the delegatee nor the claimer may be the zero address.
  function stakeOnBehalf(
    uint256 _amount,
    address _delegatee,
    address _claimer,
    address _depositor,
    uint256 _deadline,
    bytes memory _signature
  ) external virtual returns (DepositIdentifier _depositId) {
    _revertIfPastDeadline(_deadline);
    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            STAKE_TYPEHASH,
            _amount,
            _delegatee,
            _claimer,
            _depositor,
            _useNonce(_depositor),
            _deadline
          )
        )
      ),
      _signature
    );
    _depositId = _stake(_depositor, _amount, _delegatee, _claimer);
  }

  /// @notice Add more staking tokens to an existing deposit on behalf of a user, using a signature
  /// to validate the user's intent. A staker should call this method when they have an existing
  /// deposit, and wish to stake more while retaining the same delegatee and claimer.
  /// @param _depositId Unique identifier of the deposit to which stake will be added.
  /// @param _amount Quantity of stake to be added.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _deadline The timestamp after which the signature should expire.
  /// @param _signature Signature of the user authorizing this stake.
  function stakeMoreOnBehalf(
    DepositIdentifier _depositId,
    uint256 _amount,
    address _depositor,
    uint256 _deadline,
    bytes memory _signature
  ) external virtual {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, _depositor);
    _revertIfPastDeadline(_deadline);
    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            STAKE_MORE_TYPEHASH, _depositId, _amount, _depositor, _useNonce(_depositor), _deadline
          )
        )
      ),
      _signature
    );

    _stakeMore(deposit, _depositId, _amount);
  }

  /// @notice For an existing deposit, change the address to which governance voting power is
  /// assigned on behalf of a user, using a signature to validate the user's intent.
  /// @param _depositId Unique identifier of the deposit which will have its delegatee altered.
  /// @param _newDelegatee Address of the new governance delegate.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _deadline The timestamp after which the signature should expire.
  /// @param _signature Signature of the user authorizing this stake.
  /// @dev The new delegatee may not be the zero address.
  function alterDelegateeOnBehalf(
    DepositIdentifier _depositId,
    address _newDelegatee,
    address _depositor,
    uint256 _deadline,
    bytes memory _signature
  ) external virtual {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, _depositor);
    _revertIfPastDeadline(_deadline);
    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            ALTER_DELEGATEE_TYPEHASH,
            _depositId,
            _newDelegatee,
            _depositor,
            _useNonce(_depositor),
            _deadline
          )
        )
      ),
      _signature
    );

    _alterDelegatee(deposit, _depositId, _newDelegatee);
  }

  /// @notice For an existing deposit, change the claimer account which has the right to
  /// withdraw staking rewards accruing on behalf of a user, using a signature to validate the
  /// user's intent.
  /// @param _depositId Unique identifier of the deposit which will have its claimer altered.
  /// @param _newClaimer Address of the new claimer.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _deadline The timestamp after which the signature should expire.
  /// @param _signature Signature of the user authorizing this stake.
  /// @dev The new claimer may not be the zero address.
  function alterClaimerOnBehalf(
    DepositIdentifier _depositId,
    address _newClaimer,
    address _depositor,
    uint256 _deadline,
    bytes memory _signature
  ) external virtual {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, _depositor);
    _revertIfPastDeadline(_deadline);
    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            ALTER_CLAIMER_TYPEHASH,
            _depositId,
            _newClaimer,
            _depositor,
            _useNonce(_depositor),
            _deadline
          )
        )
      ),
      _signature
    );

    _alterClaimer(deposit, _depositId, _newClaimer);
  }

  /// @notice Withdraw staked tokens from an existing deposit on behalf of a user, using a
  /// signature to validate the user's intent.
  /// @param _depositId Unique identifier of the deposit from which stake will be withdrawn.
  /// @param _amount Quantity of staked token to withdraw.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _deadline The timestamp after which the signature should expire.
  /// @param _signature Signature of the user authorizing this stake.
  /// @dev Stake is withdrawn to the deposit owner's account.
  function withdrawOnBehalf(
    DepositIdentifier _depositId,
    uint256 _amount,
    address _depositor,
    uint256 _deadline,
    bytes memory _signature
  ) external virtual {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, _depositor);
    _revertIfPastDeadline(_deadline);
    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            WITHDRAW_TYPEHASH, _depositId, _amount, _depositor, _useNonce(_depositor), _deadline
          )
        )
      ),
      _signature
    );

    _withdraw(deposit, _depositId, _amount);
  }

  /// @notice Claim reward tokens earned by a given deposit, using a signature to validate the
  /// caller's intent. The signer must be the claimer address of the deposit Tokens are sent to
  /// the claimer.
  /// @param _depositId The identifier for the deposit for which to claim rewards.
  /// @param _deadline The timestamp after which the signature should expire.
  /// @param _signature Signature of the claimer authorizing this reward claim.
  /// @return Amount of reward tokens claimed, after the fee has been assessed.
  function claimRewardOnBehalf(
    DepositIdentifier _depositId,
    uint256 _deadline,
    bytes memory _signature
  ) external virtual returns (uint256) {
    _revertIfPastDeadline(_deadline);
    Deposit storage deposit = deposits[_depositId];
    bytes32 _claimerHash = _hashTypedDataV4(
      keccak256(abi.encode(CLAIM_REWARD_TYPEHASH, _depositId, nonces(deposit.claimer), _deadline))
    );
    bool _isValidClaimerClaim =
      SignatureChecker.isValidSignatureNow(deposit.claimer, _claimerHash, _signature);
    if (_isValidClaimerClaim) {
      _useNonce(deposit.claimer);
      return _claimReward(_depositId, deposit, deposit.claimer);
    }

    bytes32 _ownerHash = _hashTypedDataV4(
      keccak256(abi.encode(CLAIM_REWARD_TYPEHASH, _depositId, _useNonce(deposit.owner), _deadline))
    );
    bool _isValidOwnerClaim =
      SignatureChecker.isValidSignatureNow(deposit.owner, _ownerHash, _signature);
    if (!_isValidOwnerClaim) revert GovernanceStakerOnBehalf__InvalidSignature();
    return _claimReward(_depositId, deposit, deposit.owner);
  }

  /// @notice Internal helper method which reverts if the provided deadline has passed.
  /// @param _deadline The timestamp that represents when the operation should no longer be valid.
  function _revertIfPastDeadline(uint256 _deadline) internal view virtual {
    if (block.timestamp > _deadline) revert GovernanceStakerOnBehalf__ExpiredDeadline();
  }

  /// @notice Internal helper method which reverts with GovernanceStaker__InvalidSignature if the
  /// signature is invalid.
  /// @param _signer Address of the signer.
  /// @param _hash Hash of the message.
  /// @param _signature Signature to validate.
  function _revertIfSignatureIsNotValidNow(address _signer, bytes32 _hash, bytes memory _signature)
    internal
    view
    virtual
  {
    bool _isValid = SignatureChecker.isValidSignatureNow(_signer, _hash, _signature);
    if (!_isValid) revert GovernanceStakerOnBehalf__InvalidSignature();
  }
}

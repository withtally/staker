// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {GovernanceStaker} from "src/GovernanceStaker.sol";
import {IERC20Permit} from "openzeppelin/token/ERC20/extensions/IERC20Permit.sol";

/// @title GovernanceStakerPermitAndStake
/// @author [ScopeLift](https://scopelift.co)
/// @notice This contract extension adds permit functionality to the GovernanceStaker base contract,
/// allowing token approvals to happen via signatures rather than requiring a separate transaction.
/// The permit functionality is used in conjunction with staking operations, improving UX by
/// enabling users to approve and stake tokens in a single transaction.
/// Note that this extension requires the stake token to support EIP-2612 permit functionality.
abstract contract GovernanceStakerPermitAndStake is GovernanceStaker {
  /// @notice Thrown if an inheritor uses a seperate staking token.
  error GovernanceStakerPermitAndStake__UnauthorizedToken();

  constructor(IERC20Permit _permitToken) {
    if (address(STAKE_TOKEN) != address(_permitToken)) {
      revert GovernanceStakerPermitAndStake__UnauthorizedToken();
    }
  }

  /// @notice Method to stake tokens to a new deposit. Before the staking operation occurs, a
  /// signature is passed to the token contract's permit method to spend the would-be staked amount
  /// of the token.
  /// @param _amount Quantity of the staking token to stake.
  /// @param _delegatee Address to assign the governance voting weight of the staked tokens.
  /// @param _claimer Address that will accrue rewards for this stake.
  /// @param _deadline The timestamp after which the permit signature should expire.
  /// @param _v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param _r ECDSA signature component: x-coordinate of `R`
  /// @param _s ECDSA signature component: `s` value of the signature
  /// @return _depositId Unique identifier for this deposit.
  /// @dev Neither the delegatee nor the claimer may be the zero address. The deposit will be
  /// owned by the message sender.
  function permitAndStake(
    uint256 _amount,
    address _delegatee,
    address _claimer,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external virtual returns (DepositIdentifier _depositId) {
    try IERC20Permit(address(STAKE_TOKEN)).permit(
      msg.sender, address(this), _amount, _deadline, _v, _r, _s
    ) {} catch {}
    _depositId = _stake(msg.sender, _amount, _delegatee, _claimer);
  }

  /// @notice Add more staking tokens to an existing deposit. A staker should call this method when
  /// they have an existing deposit, and wish to stake more while retaining the same delegatee and
  /// claimer. Before the staking operation occurs, a signature is passed to the token
  /// contract's permit method to spend the would-be staked amount of the token.
  /// @param _depositId Unique identifier of the deposit to which stake will be added.
  /// @param _amount Quantity of stake to be added.
  /// @param _deadline The timestamp after which the permit signature should expire.
  /// @param _v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param _r ECDSA signature component: x-coordinate of `R`
  /// @param _s ECDSA signature component: `s` value of the signature
  /// @dev The message sender must be the owner of the deposit.
  function permitAndStakeMore(
    DepositIdentifier _depositId,
    uint256 _amount,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external virtual {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, msg.sender);

    try IERC20Permit(address(STAKE_TOKEN)).permit(
      msg.sender, address(this), _amount, _deadline, _v, _r, _s
    ) {} catch {}
    _stakeMore(deposit, _depositId, _amount);
  }
}

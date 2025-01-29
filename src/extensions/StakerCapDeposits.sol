// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Staker} from "src/Staker.sol";

/// @title StakerCapDeposits
/// @author [ScopeLift](https://scopelift.co)
/// @notice A Staker extension that enforces a cap on the global total amount of tokens that can be
/// staked.
///
/// The contract allows the admin to configure a total stake cap that applies across all deposits.
/// Any attempt to stake tokens that would cause the total staked amount to exceed this cap will
/// revert.
abstract contract StakerCapDeposits is Staker {
  /// @notice Emitted when the total stake cap is changed.
  /// @param oldTotalStakeCap The previous maximum total stake allowed.
  /// @param newTotalStakeCap The new maximum total stake allowed.
  event TotalStakeCapSet(uint256 oldTotalStakeCap, uint256 newTotalStakeCap);

  /// @notice Thrown when a staking operation would cause the total staked amount to exceed the
  /// cap.
  error StakerCapDeposits__CapExceeded();

  /// @notice The maximum total amount of tokens that can be staked across all deposits.
  uint256 public totalStakeCap;

  /// @param _initialTotalStakeCap The initial maximum total stake allowed.
  constructor(uint256 _initialTotalStakeCap) {
    _setTotalStakeCap(_initialTotalStakeCap);
  }

  /// @notice Sets a new maximum total stake cap.
  /// @param _newTotalStakeCap The new maximum total stake allowed.
  /// @dev Caller must be the current admin.
  function setTotalStakeCap(uint256 _newTotalStakeCap) external {
    _revertIfNotAdmin();
    _setTotalStakeCap(_newTotalStakeCap);
  }

  /// @notice Internal helper method which sets a new total stake cap.
  /// @param _newTotalStakeCap The new maximum total stake allowed.
  function _setTotalStakeCap(uint256 _newTotalStakeCap) internal {
    emit TotalStakeCapSet(totalStakeCap, _newTotalStakeCap);
    totalStakeCap = _newTotalStakeCap;
  }

  /// @inheritdoc Staker
  /// @dev Checks if the stake would exceed the total stake cap before proceeding.
  function _stake(address _depositor, uint256 _amount, address _delegatee, address _claimer)
    internal
    virtual
    override(Staker)
    returns (DepositIdentifier _depositId)
  {
    _revertIfCapExceeded(_amount);
    return Staker._stake(_depositor, _amount, _delegatee, _claimer);
  }

  /// @inheritdoc Staker
  /// @dev Checks if the additional stake would exceed the total stake cap before proceeding.
  function _stakeMore(Deposit storage deposit, DepositIdentifier _depositId, uint256 _amount)
    internal
    virtual
    override(Staker)
  {
    _revertIfCapExceeded(_amount);
    Staker._stakeMore(deposit, _depositId, _amount);
  }

  /// @notice Internal helper method which reverts if adding a given stake amount would exceed the
  /// total cap.
  /// @param _amount The amount of stake which would be added.
  /// @dev Reverts with StakerCapDeposits__CapExceeded if the amount would cause total stake to
  /// exceed the cap.
  function _revertIfCapExceeded(uint256 _amount) internal view virtual {
    if ((totalStaked + _amount) > totalStakeCap) revert StakerCapDeposits__CapExceeded();
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {StakerUpgradeable} from "../StakerUpgradeable.sol";

/// @title StakerCapDeposits
/// @author [ScopeLift](https://scopelift.co)
/// @notice A Staker extension that enforces a cap on the global total amount of tokens that can be
/// staked.
///
/// The contract allows the admin to configure a total stake cap that applies across all deposits.
/// Any attempt to stake tokens that would cause the total staked amount to exceed this cap will
/// revert.
abstract contract StakerCapDepositsUpgradeable is StakerUpgradeable {
  /// @notice Emitted when the total stake cap is changed.
  /// @param oldTotalStakeCap The previous maximum total stake allowed.
  /// @param newTotalStakeCap The new maximum total stake allowed.
  event TotalStakeCapSet(uint256 oldTotalStakeCap, uint256 newTotalStakeCap);

  /// @notice Thrown when a staking operation would cause the total staked amount to exceed the
  /// cap.
  error StakerCapDepositsUpgradeable__CapExceeded();

  struct StakerCapDepositsStorage {
    /// @notice The maximum total amount of tokens that can be staked across all deposits.
    uint256 _totalStakeCap;
  }

  // keccak256(abi.encode(uint256(keccak256("storage.StakerCapDeposits")) - 1))
  // &~bytes32(uint256(0xff))
  bytes32 private constant STAKER_CAP_DEPOSITS_STORAGE_LOCATION =
    0x46a81a56bebd29f7ac25bcccfeb503450824f0cb51e1dc37a6009eb410111900;

  // constructor(uint256 _initialTotalStakeCap) {
  //   _setTotalStakeCap(_initialTotalStakeCap);
  // }

  function _getStakerCapDepositsStorage() private pure returns (StakerCapDepositsStorage storage $) {
    assembly {
      $.slot := STAKER_CAP_DEPOSITS_STORAGE_LOCATION
    }
  }

  /// @param _initialTotalStakeCap The initial maximum total stake allowed.
  function __StakerCapDepositsUpgradeable_init(uint256 _initialTotalStakeCap)
    internal
    onlyInitializing
  {
    __StakerCapDepositsUpgradeable_init_unchained(_initialTotalStakeCap);
  }

  function __StakerCapDepositsUpgradeable_init_unchained(uint256 _initialTotalStakeCap)
    internal
    onlyInitializing
  {
    _setTotalStakeCap(_initialTotalStakeCap);
  }

  /// @notice Sets a new maximum total stake cap.
  /// @param _newTotalStakeCap The new maximum total stake allowed.
  /// @dev Caller must be the current admin.
  function setTotalStakeCap(uint256 _newTotalStakeCap) external {
    _revertIfNotAdmin();
    _setTotalStakeCap(_newTotalStakeCap);
  }

  /// @notice The maximum total amount of tokens that can be staked across all deposits.
  function totalStakeCap() public view returns (uint256) {
    StakerCapDepositsStorage storage $ = _getStakerCapDepositsStorage();
    return $._totalStakeCap;
  }

  /// @notice Internal helper method which sets a new total stake cap.
  /// @param _newTotalStakeCap The new maximum total stake allowed.
  function _setTotalStakeCap(uint256 _newTotalStakeCap) internal {
    StakerCapDepositsStorage storage $ = _getStakerCapDepositsStorage();
    emit TotalStakeCapSet($._totalStakeCap, _newTotalStakeCap);
    $._totalStakeCap = _newTotalStakeCap;
  }

  /// @inheritdoc StakerUpgradeable
  /// @dev Checks if the stake would exceed the total stake cap before proceeding.
  function _stake(address _depositor, uint256 _amount, address _delegatee, address _claimer)
    internal
    virtual
    override(StakerUpgradeable)
    returns (DepositIdentifier _depositId)
  {
    _revertIfCapExceeded(_amount);
    return StakerUpgradeable._stake(_depositor, _amount, _delegatee, _claimer);
  }

  /// @inheritdoc StakerUpgradeable
  /// @dev Checks if the additional stake would exceed the total stake cap before proceeding.
  function _stakeMore(Deposit storage deposit, DepositIdentifier _depositId, uint256 _amount)
    internal
    virtual
    override(StakerUpgradeable)
  {
    _revertIfCapExceeded(_amount);
    StakerUpgradeable._stakeMore(deposit, _depositId, _amount);
  }

  /// @notice Internal helper method which reverts if adding a given stake amount would exceed the
  /// total cap.
  /// @param _amount The amount of stake which would be added.
  /// @dev Reverts with StakerCapDeposits__CapExceeded if the amount would cause total stake to
  /// exceed the cap.
  function _revertIfCapExceeded(uint256 _amount) internal view virtual {
    StakerCapDepositsStorage storage $ = _getStakerCapDepositsStorage();
    if ((totalStaked() + _amount) > $._totalStakeCap) {
      revert StakerCapDepositsUpgradeable__CapExceeded();
    }
  }
}

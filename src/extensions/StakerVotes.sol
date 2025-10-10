// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {StakerDelegateSurrogateVotes} from "./StakerDelegateSurrogateVotes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEarningPowerCalculator} from "../interfaces/IEarningPowerCalculator.sol";
import {IERC20Delegates} from "../interfaces/IERC20Delegates.sol";
import {Staker} from "../Staker.sol";

contract StakerVotes is IVotes, StakerDelegateSurrogateVotes {
  using Checkpoints for Checkpoints.Trace208;

  constructor(
    IERC20 _rewardToken,
    IERC20 _stakeToken,
    IEarningPowerCalculator _earningPowerCalculator,
    uint256 _maxBumpTip,
    address _admin
  )
    Staker(IERC20(_rewardToken), IERC20(_stakeToken), _earningPowerCalculator, _maxBumpTip, _admin)
    StakerDelegateSurrogateVotes(IERC20Delegates(address(_stakeToken)))
  {}

  mapping(address delegatee => Checkpoints.Trace208) private _delegateCheckpoints;
  Checkpoints.Trace208 private _totalSupplyCheckpoints;

  function getVotes(address account) external view override returns (uint256) {
    return _delegateCheckpoints[account].latest();
  }

  /// @notice Returns the historical total voting power delegated to an account at a specific
  /// timepoint.
  /// @param account The address of the delegatee.
  /// @param timepoint The block number or timestamp to query.
  function getPastVotes(address account, uint256 timepoint)
    external
    view
    override
    returns (uint256)
  {
    // TODO: Need clock() and/or _validateTimepoint() from Votes.sol
    require(timepoint < block.timestamp, "ERC5805: future lookup");
    return _delegateCheckpoints[account].upperLookupRecent(uint48(timepoint));
  }

  /// @notice Returns the total supply of staked tokens at a specific timepoint.
  function getPastTotalSupply(uint256 timepoint) external view override returns (uint256) {
    require(timepoint < block.timestamp, "ERC5805: future lookup");
    return _totalSupplyCheckpoints.upperLookupRecent(uint48(timepoint));
  }

  /// @dev Not supported. Delegation is managed per-deposit via stake() and alterDelegatee().
  function delegate(address /* delegatee */ ) external pure override {
    revert("Staker: Use stake() or alterDelegatee() for delegation");
  }

  /// @dev Not supported. Delegation is managed per-deposit.
  function delegateBySig(
    address, /* delegatee */
    uint256, /* nonce */
    uint256, /* expiry */
    uint8, /* v */
    bytes32, /* r */
    bytes32 /* s */
  ) external virtual override {
    revert("Staker: Use stake() or alterDelegatee() for delegation");
  }

  /// @dev Not applicable in a per-deposit model as a staker can have multiple delegates. And we
  /// don't have a reverse lookup of surrogate -> delegatee either.
  function delegates(address /* account */ ) external pure override returns (address) {
    // This function cannot return a single delegatee for a staker.
    // Returning address(0) is a safe default.
    return address(0);
  }

  /// @dev Moves voting power between delegatees and updates their checkpoints.
  function _moveDelegateVotes(address from, address to, uint256 amount) internal {
    if (from != to && amount > 0) {
      if (from != address(0)) {
        _delegateCheckpoints[from].push(
          uint48(block.timestamp), uint208(_delegateCheckpoints[from].latest() - amount)
        );
      }
      if (to != address(0)) {
        _delegateCheckpoints[to].push(
          uint48(block.timestamp), uint208(_delegateCheckpoints[to].latest() + amount)
        );
      }

      // Update total supply checkpoint when tokens are staked/unstaked
      if (from == address(0) || to == address(0)) {
        _totalSupplyCheckpoints.push(uint48(block.timestamp), uint208(totalStaked));
      }
    }
  }

  function _stake(address _depositor, uint256 _amount, address _delegatee, address _claimer)
    internal
    virtual
    override
    returns (DepositIdentifier _depositId)
  {
    _depositId = Staker._stake(_depositor, _amount, _delegatee, _claimer);
    _moveDelegateVotes(address(0), _delegatee, _amount);
    return _depositId;
  }

  function _stakeMore(Deposit storage deposit, DepositIdentifier _depositId, uint256 _amount)
    internal
    virtual
    override
  {
    Staker._stakeMore(deposit, _depositId, _amount);
    _moveDelegateVotes(address(0), deposit.delegatee, _amount);
  }

  function _withdraw(Deposit storage deposit, DepositIdentifier _depositId, uint256 _amount)
    internal
    virtual
    override
  {
    Staker._withdraw(deposit, _depositId, _amount);
    _moveDelegateVotes(deposit.delegatee, address(0), _amount);
  }

  function _alterDelegatee(
    Deposit storage deposit,
    DepositIdentifier _depositId,
    address _newDelegatee
  ) internal virtual override {
    address _oldDelegatee = deposit.delegatee;
    Staker._alterDelegatee(deposit, _depositId, _newDelegatee);
    _moveDelegateVotes(_oldDelegatee, _newDelegatee, deposit.balance);
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Staker} from "./Staker.sol";
import {DelegationSurrogate} from "./DelegationSurrogate.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

abstract contract DelegateCompensationStaker is Staker {
  using SafeCast for uint256;
  // override

  function alterDelegatee(Staker.DepositIdentifier, address) public pure override {
    revert();
  }

  function stake(uint256, address) external pure override returns (Staker.DepositIdentifier) {
    revert();
  }

  function stake(uint256, address, address)
    external
    pure
    override
    returns (Staker.DepositIdentifier)
  {
    revert();
  }

  function stakeMore(Staker.DepositIdentifier, uint256) external pure override {
    revert();
  }

  function surrogates(address) public pure override returns (DelegationSurrogate) {
    revert();
  }

  function withdraw(Staker.DepositIdentifier, uint256) public pure override {
    revert();
  }

  function initializeDelegateReward(address _delegate) external virtual returns (DepositIdentifier) {
    _checkpointGlobalReward();

    DepositIdentifier _depositId = _useDepositId();
    Staker.Deposit storage _delegateReward = deposits[_depositId];
    // TODO cleanupo
    if (_delegateReward.owner != address(0)) revert();

    uint256 _earningPower = earningPowerCalculator.getEarningPower(0, _delegate, _delegate);
    totalEarningPower += _earningPower;
    depositorTotalEarningPower[_delegate] += _earningPower;
    deposits[_depositId] = Deposit({
      balance: 0,
      delegatee: _delegate, // so if used in earning power calculator it is the same
      earningPower: _earningPower.toUint96(),
      claimer: _delegate,
      owner: _delegate,
      rewardPerTokenCheckpoint: rewardPerTokenAccumulatedCheckpoint,
      scaledUnclaimedRewardCheckpoint: 0
    });
    // TODO: Add event
    return _depositId;
  }

  function _fetchOrDeploySurrogate(address) internal pure override returns (DelegationSurrogate) {
    revert();
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {RewardDistributor} from "./RewardDistributor.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

abstract contract RewardDistributorDelegateInitializer is RewardDistributor {
  using SafeCast for uint256;

  function initializeDelegateReward(address _delegate) external virtual override returns (DepositIdentifier) {
    _checkpointGlobalReward();

    DepositIdentifier _depositId = _useDepositId();
    DelegateReward storage _delegateReward = delegateRewards[_depositId];
    // TODO cleanupo
    if (_delegateReward.owner != address(0)) revert();

    uint256 _earningPower = earningPowerCalculator.getEarningPower(0, _delegate, _delegate);
    totalEarningPower += _earningPower;
    depositorTotalEarningPower[_delegate] += _earningPower;
    delegateRewards[_depositId] = DelegateReward({
      earningPower: _earningPower.toUint96(),
      claimer: _delegate,
      owner: _delegate,
      rewardPerTokenCheckpoint: rewardPerTokenAccumulatedCheckpoint,
      scaledUnclaimedRewardCheckpoint: 0
    });
    // TODO: Add event
	return _depositId;
  }
}

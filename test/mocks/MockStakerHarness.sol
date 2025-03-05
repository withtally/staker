// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Staker} from "../../src/Staker.sol";
import {StakerPermitAndStake} from "../../src/extensions/StakerPermitAndStake.sol";
import {StakerDelegateSurrogateVotes} from "../../src/extensions/StakerDelegateSurrogateVotes.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Staking} from "../../src/interfaces/IERC20Staking.sol";
import {IEarningPowerCalculator} from "../../src/interfaces/IEarningPowerCalculator.sol";
import {DelegationSurrogate} from "../../src/DelegationSurrogate.sol";

/// @dev Mock version of StakerHarness that accepts different stake tokens for each inherited
/// contract, unlike StakerHarness which uses the same token. This contract is used to test reverts
/// when stake tokens mismatch.
contract MockStakerHarness is Staker, StakerPermitAndStake, StakerDelegateSurrogateVotes {
  constructor(
    IERC20 _rewardsToken,
    IERC20Staking _stakerStakeToken,
    IERC20Staking _permitAndStakeStakeToken,
    IERC20Staking _delegateSurrogateVotesStakeToken,
    IEarningPowerCalculator _earningPowerCalculator,
    uint256 _maxBumpTip,
    address _admin
  )
    Staker(_rewardsToken, _stakerStakeToken, _earningPowerCalculator, _maxBumpTip, _admin)
    StakerPermitAndStake(_permitAndStakeStakeToken)
    StakerDelegateSurrogateVotes(_delegateSurrogateVotesStakeToken)
  {
    MAX_CLAIM_FEE = 1e18;
    _setClaimFeeParameters(ClaimFeeParameters({feeAmount: 0, feeCollector: address(0)}));
  }

  function exposed_useDepositId() external returns (DepositIdentifier _depositId) {
    _depositId = _useDepositId();
  }

  function exposed_fetchOrDeploySurrogate(address delegatee)
    external
    returns (DelegationSurrogate _surrogate)
  {
    _surrogate = _fetchOrDeploySurrogate(delegatee);
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Staker} from "../Staker.sol";
import {StakerDelegateSurrogateVotes} from "../extensions/StakerDelegateSurrogateVotes.sol";
import {StakerPermitAndStake} from "../extensions/StakerPermitAndStake.sol";
import {StakerOnBehalf} from "../extensions/StakerOnBehalf.sol";
import {IEarningPowerCalculator} from "../interfaces/IEarningPowerCalculator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Delegates} from "../interfaces/IERC20Delegates.sol";
import {IERC20Staking} from "../interfaces/IERC20Staking.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title FullStaker
/// @notice Combines the base Staker contract with the three most-commonly-used extensions
/// (`StakerDelegateSurrogateVotes`, `StakerPermitAndStake`, `StakerOnBehalf`). This contract is
/// intended to be deployed by `StakerFactory` so that users can spin up an entire staking system
/// with one transaction.
contract FullStaker is Staker, StakerDelegateSurrogateVotes, StakerPermitAndStake, StakerOnBehalf {
  /// @notice Constructs a fully-featured Staker instance.
  /// @param _rewardsToken The ERC20 token distributed as rewards.
  /// @param _stakeToken  The ERC20 token being staked (must support votes + permit).
  /// @param _earningPowerCalculator The calculator determining earning power.
  /// @param _maxBumpTip  Initial max bump tip value.
  /// @param _admin  Address with admin rights.
  constructor(
    IERC20 _rewardsToken,
    IERC20Staking _stakeToken,
    IEarningPowerCalculator _earningPowerCalculator,
    uint256 _maxBumpTip,
    address _admin,
    uint256 _maxClaimFee
  )
    Staker(_rewardsToken, IERC20(_stakeToken), _earningPowerCalculator, _maxBumpTip, _admin)
    StakerDelegateSurrogateVotes(IERC20Delegates(address(_stakeToken)))
    StakerPermitAndStake(_stakeToken)
    EIP712("FullStaker", "1")
  {
    // Set the maximum reward token fee for claiming rewards based on the parameter
    MAX_CLAIM_FEE = _maxClaimFee;
    // Start with no reward claiming fee configured
    _setClaimFeeParameters(ClaimFeeParameters({feeAmount: 0, feeCollector: address(0)}));
  }
}

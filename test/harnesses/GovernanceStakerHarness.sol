// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {DelegationSurrogateVotes} from "src/DelegationSurrogateVotes.sol";
import {GovernanceStaker} from "src/GovernanceStaker.sol";
import {GovernanceStakerPermitAndStake} from "src/extensions/GovernanceStakerPermitAndStake.sol";
import {GovernanceStakerOnBehalf} from "src/extensions/GovernanceStakerOnBehalf.sol";
import {GovernanceStakerDelegateSurrogateVotes} from
  "src/GovernanceStakerDelegateSurrogateVotes.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "openzeppelin/utils/cryptography/EIP712.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";
import {IEarningPowerCalculator} from "src/interfaces/IEarningPowerCalculator.sol";
import {DelegationSurrogate} from "src/DelegationSurrogate.sol";

contract GovernanceStakerHarness is
  GovernanceStaker,
  GovernanceStakerPermitAndStake,
  GovernanceStakerOnBehalf,
  GovernanceStakerDelegateSurrogateVotes
{
  constructor(
    IERC20 _rewardsToken,
    IERC20Delegates _stakeToken,
    IEarningPowerCalculator _earningPowerCalculator,
    uint256 _maxBumpTip,
    address _admin,
    string memory _name
  )
    GovernanceStaker(_rewardsToken, _stakeToken, _earningPowerCalculator, _maxBumpTip, _admin)
    EIP712(_name, "1")
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

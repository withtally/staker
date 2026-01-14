// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {StakerUpgradeable} from "../../src/StakerUpgradeable.sol";
import {StakerPermitAndStakeUpgradeable} from
  "../../src/extensions/StakerPermitAndStakeUpgradeable.sol";
import {StakerDelegateSurrogateVotesUpgradeable} from
  "../../src/extensions/StakerDelegateSurrogateVotesUpgradeable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Staking} from "../../src/interfaces/IERC20Staking.sol";
import {IEarningPowerCalculator} from "../../src/interfaces/IEarningPowerCalculator.sol";
import {DelegationSurrogate} from "../../src/DelegationSurrogate.sol";

/// @dev Mock version of StakerHarness that accepts different stake tokens for each inherited
/// contract, unlike StakerHarness which uses the same token. This contract is used to test reverts
/// when stake tokens mismatch.
contract MockStakerHarness is
  StakerUpgradeable,
  StakerPermitAndStakeUpgradeable,
  StakerDelegateSurrogateVotesUpgradeable
{
  constructor() {
    _disableInitializers();
  }

  function initialize(
    IERC20 _rewardsToken,
    IERC20Staking _stakeToken,
    IERC20Staking _permitAndStakeStakeToken,
    IERC20Staking _delegateSurrogateVotesStakeToken,
    IEarningPowerCalculator _earningPowerCalculator,
    address _admin,
    uint256 _maxBumpTip
  ) public initializer {
    __StakerUpgradeable_init(
      _rewardsToken, _stakeToken, 1e18, _admin, _maxBumpTip, _earningPowerCalculator
    );
    __StakerPermitAndStakeUpgradeable_init(_permitAndStakeStakeToken);
    __StakerDelegateSurrogateVotesUpgradeable_init(_delegateSurrogateVotesStakeToken);
    _setMaxClaimFee(1e18);
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

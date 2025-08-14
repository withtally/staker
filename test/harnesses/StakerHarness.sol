// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {StakerUpgradeable} from "../../src/StakerUpgradeable.sol";
import {StakerPermitAndStakeUpgradeable} from
  "../../src/extensions/StakerPermitAndStakeUpgradeable.sol";
import {StakerOnBehalfUpgradeable} from "../../src/extensions/StakerOnBehalfUpgradeable.sol";
import {StakerDelegateSurrogateVotesUpgradeable} from
  "../../src/extensions/StakerDelegateSurrogateVotesUpgradeable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IERC20Staking} from "../../src/interfaces/IERC20Staking.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20Delegates} from "../../src/interfaces/IERC20Delegates.sol";
import {IEarningPowerCalculator} from "../../src/interfaces/IEarningPowerCalculator.sol";
import {DelegationSurrogate} from "../../src/DelegationSurrogate.sol";

contract StakerHarness is
  StakerUpgradeable,
  StakerPermitAndStakeUpgradeable,
  StakerOnBehalfUpgradeable,
  StakerDelegateSurrogateVotesUpgradeable
{
  constructor() {
    _disableInitializers();
  }

  function initialize(
    IERC20 _rewardToken,
    IERC20 _stakeToken,
    uint256 _maxClaimFee,
    address _admin,
    uint256 _maxBumpTip,
    IEarningPowerCalculator _earningPowerCalculator,
    string memory _name
  ) public initializer {
    __StakerUpgradeable_init(
      _rewardToken, _stakeToken, _maxClaimFee, _admin, _maxBumpTip, _earningPowerCalculator
    );
    __StakerPermitAndStakeUpgradeable_init(IERC20Permit(address(_stakeToken)));
    __StakerDelegateSurrogateVotesUpgradeable_init(IERC20Delegates(address(_stakeToken)));
    __EIP712_init(_name, "1");
    __Nonces_init();
    _setMaxClaimFee(_maxClaimFee);
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

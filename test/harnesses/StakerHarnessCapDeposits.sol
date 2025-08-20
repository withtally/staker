// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {StakerUpgradeable} from "../../src/StakerUpgradeable.sol";
import {StakerCapDepositsUpgradeable} from "../../src/extensions/StakerCapDepositsUpgradeable.sol";
import {StakerHarness} from "../../test/harnesses/StakerHarness.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Staking} from "../../src/interfaces/IERC20Staking.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20Delegates} from "../../src/interfaces/IERC20Delegates.sol";
import {IEarningPowerCalculator} from "../../src/interfaces/IEarningPowerCalculator.sol";

contract StakerHarnessCapDeposits is StakerHarness, StakerCapDepositsUpgradeable {
  function initialize(
    IERC20 _rewardToken,
    IERC20 _stakeToken,
    uint256 _maxClaimFee,
    address _admin,
    uint256 _maxBumpTip,
    IEarningPowerCalculator _earningPowerCalculator,
    string memory _name,
    uint256 _initialStakeCap
  ) public initializer {
    __StakerUpgradeable_init(
      _rewardToken, _stakeToken, _maxClaimFee, _admin, _maxBumpTip, _earningPowerCalculator
    );
    __StakerPermitAndStakeUpgradeable_init(IERC20Permit(address(_stakeToken)));
    __StakerDelegateSurrogateVotesUpgradeable_init(IERC20Delegates(address(_stakeToken)));
    __EIP712_init(_name, "1");
    __StakerCapDepositsUpgradeable_init(_initialStakeCap);
    __Nonces_init();
    _setMaxClaimFee(_maxClaimFee);
    _setClaimFeeParameters(ClaimFeeParameters({feeAmount: 0, feeCollector: address(0)}));
  }

  function _stake(address _depositor, uint256 _amount, address _delegatee, address _claimer)
    internal
    virtual
    override(StakerUpgradeable, StakerCapDepositsUpgradeable)
    returns (DepositIdentifier _depositId)
  {
    return StakerCapDepositsUpgradeable._stake(_depositor, _amount, _delegatee, _claimer);
  }

  function _stakeMore(Deposit storage deposit, DepositIdentifier _depositId, uint256 _amount)
    internal
    virtual
    override(StakerUpgradeable, StakerCapDepositsUpgradeable)
  {
    StakerCapDepositsUpgradeable._stakeMore(deposit, _depositId, _amount);
  }
}

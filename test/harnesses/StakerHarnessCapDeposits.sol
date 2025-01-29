// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Staker} from "src/Staker.sol";
import {StakerCapDeposits} from "src/extensions/StakerCapDeposits.sol";
import {StakerHarness} from "test/harnesses/StakerHarness.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Staking} from "src/interfaces/IERC20Staking.sol";
import {IEarningPowerCalculator} from "src/interfaces/IEarningPowerCalculator.sol";

contract StakerHarnessCapDeposits is StakerHarness, StakerCapDeposits {
  constructor(
    IERC20 _rewardsToken,
    IERC20Staking _stakeToken,
    IEarningPowerCalculator _earningPowerCalculator,
    uint256 _maxBumpTip,
    address _admin,
    string memory _name,
    uint256 _initialStakeCap
  )
    StakerHarness(_rewardsToken, _stakeToken, _earningPowerCalculator, _maxBumpTip, _admin, _name)
    StakerCapDeposits(_initialStakeCap)
  {}

  function _stake(address _depositor, uint256 _amount, address _delegatee, address _claimer)
    internal
    virtual
    override(Staker, StakerCapDeposits)
    returns (DepositIdentifier _depositId)
  {
    return StakerCapDeposits._stake(_depositor, _amount, _delegatee, _claimer);
  }

  function _stakeMore(Deposit storage deposit, DepositIdentifier _depositId, uint256 _amount)
    internal
    virtual
    override(Staker, StakerCapDeposits)
  {
    StakerCapDeposits._stakeMore(deposit, _depositId, _amount);
  }
}

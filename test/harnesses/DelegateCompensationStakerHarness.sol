// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, stdError} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEarningPowerCalculator} from "../../src/interfaces/IEarningPowerCalculator.sol";
import {DelegateCompensationStaker} from "../../src/DelegateCompensationStaker.sol";
import {Staker} from "../../src/Staker.sol";

contract DelegateCompensationStakerHarness is DelegateCompensationStaker {
  constructor(
    IERC20 _rewardToken,
    IEarningPowerCalculator _earningPowerCalculator,
    uint256 _maxBumpTip,
    address _admin
  ) Staker(_rewardToken, IERC20(address(0)), _earningPowerCalculator, _maxBumpTip, _admin) {}
}

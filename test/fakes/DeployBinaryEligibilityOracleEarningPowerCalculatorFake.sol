// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {DeployBase} from "../../src/script/DeployBase.sol";
import {DeployStaker} from "../../src/script/DeployStaker.sol";
import {DeployMinterRewardNotifier} from "../../src/script/notifiers/DeployMinterRewardNotifier.sol";
import {DeployBinaryEligibilityOracleEarningPowerCalculator} from
  "../../src/script/calculators/DeployBinaryEligibilityOracleEarningPowerCalculator.sol";
import {IEarningPowerCalculator} from "../../src/interfaces/IEarningPowerCalculator.sol";
import {IMintable} from "../../src/interfaces/IMintable.sol";
import {Staker} from "../../src/Staker.sol";
import {StakerHarness} from "../harnesses/StakerHarness.sol";
import {IERC20Staking} from "../../src/interfaces/IERC20Staking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployBinaryEligibilityOracleEarningPowerCalculatorFake is
  DeployBase,
  DeployStaker,
  DeployMinterRewardNotifier,
  DeployBinaryEligibilityOracleEarningPowerCalculator
{
  address public admin = makeAddr("Staker admin");
  address public owner = makeAddr("owner");
  address public notifierOwner = makeAddr("Notifier owner");
  address public notifierMinter = makeAddr("Notifier minter");
  address public scoreOracle = makeAddr("scoreOracle");
  address public oraclePauseGuardian = makeAddr("oraclePauseGuardian");

  IERC20 rewardToken;
  IERC20 stakeToken;

  constructor(IERC20 _rewardToken, IERC20 _stakeToken) {
    rewardToken = _rewardToken;
    stakeToken = _stakeToken;
  }

  function _baseConfiguration() internal virtual override returns (BaseConfiguration memory) {
    return BaseConfiguration({admin: admin});
  }

  function _minterRewardNotifierConfiguration()
    internal
    virtual
    override
    returns (MinterRewardNotifierConfiguration memory)
  {
    return MinterRewardNotifierConfiguration({
      initialRewardAmount: 10e18,
      initialRewardInterval: 30 days,
      initialOwner: notifierOwner,
      minter: IMintable(notifierMinter)
    });
  }

  function _binaryEligibilityOracleEarningPowerCalculatorConfiguration()
    internal
    virtual
    override
    returns (BinaryEligibilityOracleEarningPowerCalculatorConfiguration memory)
  {
    return BinaryEligibilityOracleEarningPowerCalculatorConfiguration({
      owner: owner,
      scoreOracle: scoreOracle,
      staleOracleWindow: 7 days,
      oraclePauseGuardian: oraclePauseGuardian,
      delegateeScoreEligibilityThreshold: 50,
      updateEligibilityDelay: 7 days
    });
  }

  function _stakerConfiguration(IEarningPowerCalculator _earningPowerCalculator)
    internal
    virtual
    override
    returns (StakerConfiguration memory)
  {
    return StakerConfiguration({
      rewardToken: rewardToken,
      stakeToken: stakeToken,
      earningPowerCalculator: _earningPowerCalculator,
      maxBumpTip: 1e18
    });
  }

  function _deployStaker(IEarningPowerCalculator _earningPowerCalculator)
    internal
    virtual
    override
    returns (Staker)
  {
    StakerConfiguration memory _config = _stakerConfiguration(_earningPowerCalculator);
    return new StakerHarness(
      _config.rewardToken,
      IERC20Staking(address(_config.stakeToken)),
      _config.earningPowerCalculator,
      _config.maxBumpTip,
      deployer,
      "Harness"
    );
  }
}

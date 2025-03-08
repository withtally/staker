// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {DeployBase} from "../../src/script/DeployBase.sol";
import {DeployStaker} from "../../src/script/DeployStaker.sol";
import {DeployTransferFromRewardNotifier} from
  "../../src/script/notifiers/DeployTransferFromRewardNotifier.sol";
import {DeployIdentityEarningPowerCalculator} from
  "../../src/script/calculators/DeployIdentityEarningPowerCalculator.sol";
import {IEarningPowerCalculator} from "../../src/interfaces/IEarningPowerCalculator.sol";
import {Staker} from "../../src/Staker.sol";
import {StakerHarness} from "../harnesses/StakerHarness.sol";
import {IERC20Staking} from "../../src/interfaces/IERC20Staking.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployTransferFromRewardNotifierFake is
  DeployBase,
  DeployStaker,
  DeployTransferFromRewardNotifier,
  DeployIdentityEarningPowerCalculator
{
  address public admin = makeAddr("Staker admin");
  address public notifierOwner = makeAddr("Notifier owner");
  address public notifierRewardSource = makeAddr("Notifier reward source");
  uint256 public initialRewardAmount = 10e18;
  uint256 public initialRewardInterval = 30 days;
  uint256 public maxBumpTip = 1e18;
  string public name = "Harness";

  IERC20 rewardToken;
  IERC20 stakeToken;

  constructor(IERC20 _rewardToken, IERC20 _stakeToken) {
    rewardToken = _rewardToken;
    stakeToken = _stakeToken;
  }

  function _baseConfiguration() internal virtual override returns (BaseConfiguration memory) {
    return BaseConfiguration({admin: admin});
  }

  function _transferFromRewardNotifierConfiguration()
    internal
    virtual
    override
    returns (TransferFromRewardNotifierConfiguration memory)
  {
    return TransferFromRewardNotifierConfiguration({
      initialRewardAmount: initialRewardAmount,
      initialRewardInterval: initialRewardInterval,
      initialOwner: notifierOwner,
      initialRewardSource: notifierRewardSource
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
      maxBumpTip: maxBumpTip
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
      name
    );
  }
}

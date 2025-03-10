// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {IEarningPowerCalculator} from "../interfaces/IEarningPowerCalculator.sol";
import {Staker} from "../Staker.sol";

abstract contract DeployBase is Script {
  uint256 deployerPrivateKey;
  RewardNotifier[] internal rewardNotifiers;

  struct BaseConfiguration {
    address admin;
  }

  struct RewardNotifier {
    address rewardNotifier;
    bool isEnabled;
  }

  function setUp() public {
    deployerPrivateKey = vm.envOr(
      "DEPLOYER_PRIVATE_KEY",
      uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
    );
  }

  function _deployBaseConfiguration() internal virtual returns (BaseConfiguration memory);

  function _deployStaker(IEarningPowerCalculator _earningPowerCalculator)
    internal
    virtual
    returns (Staker);

  function _deployEarningPowerCalculator() internal virtual returns (IEarningPowerCalculator);

  //
  function _deployRewardNotifiers() internal virtual;

  function run() public {
    IEarningPowerCalculator _earningPowerCalculator = _deployEarningPowerCalculator();
    Staker _staker = _deployStaker(_earningPowerCalculator);

    for (uint256 i = 0; i < rewardNotifiers.length; i++) {
      _staker.setRewardNotifier(rewardNotifiers[i].rewardNotifier, rewardNotifiers[i].isEnabled);
    }

    BaseConfiguration memory _baseConfig = _deployBaseConfiguration();
    vm.broadcast(deployerPrivateKey);
    _staker.setAdmin(_baseConfig.admin);
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, console, stdError} from "forge-std/Test.sol";
import {Script} from "forge-std/Script.sol";

import {IEarningPowerCalculator} from "../interfaces/IEarningPowerCalculator.sol";
import {Staker} from "../Staker.sol";

abstract contract DeployBase is Script {
  uint256 deployerPrivateKey;
  address[] internal rewardNotifiers;
  address deployer;

  struct BaseConfiguration {
    address admin;
  }

  function _deployBaseConfiguration() internal virtual returns (BaseConfiguration memory);

  function _deployStaker(IEarningPowerCalculator _earningPowerCalculator)
    internal
    virtual
    returns (Staker);

  function _deployEarningPowerCalculator() internal virtual returns (IEarningPowerCalculator);

  //
  function _deployRewardNotifiers(Staker _staker) internal virtual;

  function run() public returns (IEarningPowerCalculator, Staker, address[] memory) {
    deployerPrivateKey = vm.envOr(
      "DEPLOYER_PRIVATE_KEY",
      uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
    );

    deployer = vm.rememberKey(deployerPrivateKey);
    vm.startBroadcast(deployer);
    IEarningPowerCalculator _earningPowerCalculator = _deployEarningPowerCalculator();
    Staker _staker = _deployStaker(_earningPowerCalculator);

    _deployRewardNotifiers(_staker);
    for (uint256 i = 0; i < rewardNotifiers.length; i++) {
      _staker.setRewardNotifier(rewardNotifiers[i], true);
    }

    BaseConfiguration memory _baseConfig = _deployBaseConfiguration();
    _staker.setAdmin(_baseConfig.admin);
    vm.stopBroadcast();
    return (_earningPowerCalculator, _staker, rewardNotifiers);
  }
}

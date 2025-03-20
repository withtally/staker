// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {IEarningPowerCalculator} from "../interfaces/IEarningPowerCalculator.sol";
import {Staker} from "../Staker.sol";

abstract contract DeployBase is Script {
  /// @notice An array of initial reward notifiers for Staker.
  address[] internal rewardNotifiers;
  /// @notice The address deploying the staking system.
  address deployer;

  /// @notice The configuration needed for this base script.
  /// @param admin The final admin of the staker contract.
  struct BaseConfiguration {
    address admin;
  }

  /// @notice An interface method that returns a set configuration for the base script.
  /// @return The base configuration for the staking system.
  function _baseConfiguration() internal virtual returns (BaseConfiguration memory);

  /// @notice An interface method that deploys the Staker contract for the staking system.
  /// @param _earningPowerCalculator The address of the deployed earning power calculator.
  /// @return The Staker contract for the staking system.
  function _deployStaker(IEarningPowerCalculator _earningPowerCalculator)
    internal
    virtual
    returns (Staker);

  /// @notice An interface method that deploys the earning power contract for the staking system.
  /// @return The earning power calculator contract.
  function _deployEarningPowerCalculator() internal virtual returns (IEarningPowerCalculator);

  /// @notice An interface method that deploys the reward notifiers.
  /// @param _staker The Staker for the staking system.
  function _deployRewardNotifiers(Staker _staker) internal virtual;

  /// @notice The method that is executed when the script runs which deploys the entire staking
  /// system.
  /// @return The Staker contract, earning power calculator, and array of reward notifiers.
  function run() public returns (IEarningPowerCalculator, Staker, address[] memory) {
    uint256 deployerPrivateKey = vm.envOr(
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

    BaseConfiguration memory _baseConfig = _baseConfiguration();
    _staker.setAdmin(_baseConfig.admin);
    vm.stopBroadcast();
    return (_earningPowerCalculator, _staker, rewardNotifiers);
  }
}

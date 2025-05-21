// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {IEarningPowerCalculator} from "../interfaces/IEarningPowerCalculator.sol";
import {Staker} from "../Staker.sol";

/// @title DeployBase
/// @author [ScopeLift](https://scopelift.co)
/// @notice The base contract for the Staker modular deployment system. Any deployment script or
/// extension should inherit from this contract as it defines all of the necessary pieces for
/// a Staker system deployment. These pieces are the staker contract, earning power calculator and
/// reward notifiers. Each of these components will have an implementation specific extension
/// that will be combined to create a concrete implementation of the deployment script. An example
/// of what this may look like can be found in test/fakes/DeployBaseFake.sol.
///
/// When deploying a Staker the initial owner must be the deployer and a new admin will be set
/// using the configuration defined in this base deployment script.
abstract contract DeployBase is Script {
  /// @notice An array of initial reward notifiers for Staker.
  address[] internal rewardNotifiers;
  /// @notice The address deploying the staking system.
  address deployer;

  /// @notice Thrown if the initial `Staker` admin is not the deployer.
  error DeployBase__InvalidInitialStakerAdmin();

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
  /// @dev When this method is overridden make sure to add the reward notifier to the
  /// `rewardNotifiers` array.
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
    if (_staker.admin() != deployer) revert DeployBase__InvalidInitialStakerAdmin();

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

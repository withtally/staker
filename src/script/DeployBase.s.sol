// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";

import {DeployInput} from "./DeployInput.sol";
import {StakerHarness} from "../../test/harnesses/StakerHarness.sol";
import {IERC20Staking} from "../interfaces/IERC20Staking.sol";
import {IEarningPowerCalculator} from "../interfaces/IEarningPowerCalculator.sol";
import {Staker} from "../Staker.sol";

// base config
// What if constructor has different args?
// - Script per script, should be handled via composition
//   - typing to handle specific args
// base base
// - Deploy staker
// - Deploy earning power calculator
// - Deploy and add reward notifiers
// - Set Admin
abstract contract StakerBaseDeploy is Script, DeployInput {
  uint256 deployerPrivateKey;
  RewardNotifier[] rewardNotifiers;

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

  function _deployStaker() internal virtual returns (Staker);

  function _deployEarningPowerCalculator() internal virtual returns (IEarningPowerCalculator);

  //
  function _deployRewardNotifiers() internal virtual;

  function run() public {
    Staker _staker = _deployStaker();

    for (uint256 i = 0; i < rewardNotifiers.length; i++) {
			_staker.setRewardNotifier(rewardNotifiers[i], );
	}

    BaseConfiguration memory _baseConfig = _deployBaseConfiguration();
    vm.broadcast(deployerPrivateKey);
    _staker.setAdmin(_baseConfig.admin);

    // vm.startBroadcast(deployerPrivateKey);
    // // Deploy the staking contract
    // StakerHarness govStaker = new StakerHarness(
    //   IERC20(PAYOUT_TOKEN_ADDRESS),
    //   IERC20Staking(STAKE_TOKEN_ADDRESS),
    //   IEarningPowerCalculator(address(0)),
    //   MAX_BUMP_TIP,
    //   vm.addr(deployerPrivateKey),
    //   "StakerHarness"
    // );

    // // Change Staker admin from `msg.sender` to the Governor timelock
    // govStaker.setAdmin(GOVERNOR_TIMELOCK);
    // vm.stopBroadcast();

    // return govStaker;
  }
}

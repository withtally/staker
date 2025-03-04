// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";

import {DeployInput} from "./DeployInput.sol";
import {StakerHarness} from "../../test/harnesses/StakerHarness.sol";
import {IERC20Staking} from "../interfaces/IERC20Staking.sol";
import {INotifiableRewardReceiver} from "../interfaces/INotifiableRewardReceiver.sol";
import {IEarningPowerCalculator} from "../interfaces/IEarningPowerCalculator.sol";

contract Deploy is Script, DeployInput {
  uint256 deployerPrivateKey;

  function setUp() public {
    deployerPrivateKey = vm.envOr(
      "DEPLOYER_PRIVATE_KEY",
      uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
    );
  }

  function run() public returns (StakerHarness) {
    vm.startBroadcast(deployerPrivateKey);
    // Deploy the staking contract
    StakerHarness govStaker = new StakerHarness(
      IERC20(PAYOUT_TOKEN_ADDRESS),
      IERC20Staking(STAKE_TOKEN_ADDRESS),
      IEarningPowerCalculator(address(0)),
      MAX_BUMP_TIP,
      vm.addr(deployerPrivateKey),
      "StakerHarness"
    );

    // Change Staker admin from `msg.sender` to the Governor timelock
    govStaker.setAdmin(GOVERNOR_TIMELOCK);
    vm.stopBroadcast();

    return govStaker;
  }
}

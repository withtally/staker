// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";

import {DeployInput} from "script/DeployInput.sol";
import {UniStaker} from "src/UniStaker.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";
import {INotifiableRewardReceiver} from "src/interfaces/INotifiableRewardReceiver.sol";

contract Deploy is Script, DeployInput {
  uint256 deployerPrivateKey;

  function setUp() public {
    deployerPrivateKey = vm.envOr(
      "DEPLOYER_PRIVATE_KEY",
      uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
    );
  }

  function run() public returns (UniStaker) {
    vm.startBroadcast(deployerPrivateKey);
    // Deploy the staking contract
    UniStaker uniStaker = new UniStaker(
      IERC20(PAYOUT_TOKEN_ADDRESS),
      IERC20Delegates(STAKE_TOKEN_ADDRESS),
      vm.addr(deployerPrivateKey)
    );

    // Change UniStaker admin from `msg.sender` to the Governor timelock
    uniStaker.setAdmin(UNISWAP_GOVERNOR_TIMELOCK);
    vm.stopBroadcast();

    return uniStaker;
  }
}

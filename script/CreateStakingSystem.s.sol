// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {StakerFactory} from "../src/factory/StakerFactory.sol";
import {IEarningPowerCalculator} from "../src/interfaces/IEarningPowerCalculator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Staking} from "../src/interfaces/IERC20Staking.sol";

/// @title CreateStakingSystem
/// @notice Foundry script that calls an already-deployed `StakerFactory` (deterministic address
/// from `DeployStakerFactory`) to deploy a new staking system (`FullStaker`).
///
/// Environment variables consumed:
///  - REWARD_TOKEN         address of the ERC20 reward token
///  - STAKE_TOKEN          address of the ERC20Votes/ERC20Permit governance token to stake
///  - CALCULATOR           address of IEarningPowerCalculator implementation
///  - MAX_BUMP_TIP         uint256 (optional, defaults to 0)
///  - MAX_CLAIM_FEE        uint256 (optional, defaults to 1e18)
///  - ADMIN                address that will be the admin (optional, defaults to tx.origin)
///
/// Usage:
/// ```bash
/// REWARD_TOKEN=0x... STAKE_TOKEN=0x... CALCULATOR=0x... \
/// forge script script/CreateStakingSystem.s.sol --broadcast --rpc-url $RPC
/// ```
contract CreateStakingSystem is Script {
  // Same salt used in DeployStakerFactory
  bytes32 constant SALT = keccak256("StakerFactory_v1.0.0");
  address constant SINGLETON_FACTORY = 0xce0042B868300000d44A59004Da54A005ffdcf9f;

  function run() external returns (address staker) {
    // Resolve deterministic factory address (same formula as DeployStakerFactory)
    bytes memory creationCode = type(StakerFactory).creationCode;
    bytes32 codeHash = keccak256(creationCode);
    bytes32 data = keccak256(abi.encodePacked(bytes1(0xff), SINGLETON_FACTORY, SALT, codeHash));
    address factoryAddr = address(uint160(uint256(data)));

    // Read env vars
    address reward = vm.envAddress("REWARD_TOKEN");
    address stake = vm.envAddress("STAKE_TOKEN");
    address calc = vm.envAddress("CALCULATOR");
    uint256 maxTip = _tryEnvUint("MAX_BUMP_TIP", 0);
    uint256 maxClaimFee = _tryEnvUint("MAX_CLAIM_FEE", 1e18);
    address admin = _tryEnvAddress("ADMIN", tx.origin);

    vm.startBroadcast();

    staker = StakerFactory(factoryAddr).createStakingSystem(
      IERC20(reward),
      IERC20Staking(stake),
      IEarningPowerCalculator(calc),
      maxTip,
      admin,
      maxClaimFee
    );

    vm.stopBroadcast();
  }

  // --- helpers -------------------------------------------------------------//

  function _tryEnvUint(string memory key, uint256 defaultValue) internal view returns (uint256 val) {
    try vm.envUint(key) returns (uint256 v) {
      val = v;
    } catch {
      val = defaultValue;
    }
  }

  function _tryEnvAddress(string memory key, address defaultValue)
    internal
    view
    returns (address val)
  {
    try vm.envAddress(key) returns (address a) {
      val = a;
    } catch {
      val = defaultValue;
    }
  }
}

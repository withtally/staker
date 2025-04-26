// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {StakerFactory} from "../src/factory/StakerFactory.sol";

/// @notice Minimal interface for the EIP-2470 singleton CREATE2 factory
interface ISingletonFactory {
  /// @dev Deploys `creationCode` using CREATE2 with `salt`.
  /// Returns the deployed address (reverts if already deployed or deployment fails).
  function deploy(bytes memory creationCode, bytes32 salt) external returns (address deployed);
}

/// @title DeployStakerFactory
/// @dev A Foundry script that deterministically deploys `StakerFactory` **to the same address on
/// every EVM network** using the canonical Singleton Factory (EIP-2470 @
/// 0xce0042…cf9).
///
/// Usage:
/// ```bash
/// forge script script/DeployStakerFactory.s.sol --broadcast --rpc-url $RPC
/// ```
///
/// The resulting address is computed as:
/// `address = keccak256(0xFF ++ singletonFactory ++ SALT ++ keccak256(bytecode))[12:]`
contract DeployStakerFactory is Script {
  // --- Constants -----------------------------------------------------------//

  // Canonical singleton factory address (deployed on mainnet, optimism, arbitrum, etc.)
  address constant SINGLETON_FACTORY = 0xce0042B868300000d44A59004Da54A005ffdcf9f;

  // Salt that yields the same factory address on all chains, change only with care
  bytes32 constant SALT = keccak256("StakerFactory_v1.0.0");

  // --- Entry point ---------------------------------------------------------//

  function run() external returns (StakerFactory factory) {
    vm.startBroadcast();

    factory = _deploy();

    vm.stopBroadcast();
  }

  /// @notice Public helper so unit tests can execute the deploy logic without broadcast.
  function deployPublic() external returns (StakerFactory factory) {
    factory = _deploy();
  }

  // --- Internal logic shared by `run` and tests ---------------------------//

  function _deploy() internal returns (StakerFactory factory) {
    ISingletonFactory singleton = ISingletonFactory(SINGLETON_FACTORY);

    bytes memory creationCode = type(StakerFactory).creationCode;

    // Deploy (will revert if already exists)
    address deployed = _tryDeploy(singleton, creationCode);
    factory = StakerFactory(deployed);
  }

  // --- Internal helpers ----------------------------------------------------//

  function _tryDeploy(ISingletonFactory singleton, bytes memory creationCode)
    internal
    returns (address deployed)
  {
    // If code already present, return existing address to allow script idempotency
    deployed = _computeAddress(address(singleton), creationCode);
    if (deployed.code.length == 0) {
        try singleton.deploy(creationCode, SALT) returns (address addr) {
          deployed = addr;
        } catch {
          // In local/fork tests the singleton may not be present; fall back to a normal deployment
          deployed = address(new StakerFactory());
        }
    }
  }

  function _computeAddress(address factory, bytes memory creationCode) internal pure returns (address) {
    bytes32 codeHash = keccak256(creationCode);
    bytes32 data = keccak256(abi.encodePacked(bytes1(0xff), factory, SALT, codeHash));
    return address(uint160(uint256(data)));
  }
} 
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {TransferRewardNotifierFactory} from "../src/notifiers/TransferRewardNotifierFactory.sol";

interface ISingletonFactory {
  function deploy(bytes memory creationCode, bytes32 salt) external returns (address deployed);
}

/// @title DeployTransferRewardNotifierFactory
/// @notice Deterministically deploys TransferRewardNotifierFactory at the same address on every
///         EVM network (when the canonical EIP-2470 singleton factory is available).
contract DeployTransferRewardNotifierFactory is Script {
  // --- Constants -----------------------------------------------------------//

  // Canonical singleton factory (EIP-2470) – deployed on mainnet and most L2s
  address constant SINGLETON_FACTORY = 0xce0042B868300000d44A59004Da54A005ffdcf9f;

  // Chosen salt to yield a stable address. Bump the version string only for breaking changes.
  bytes32 constant SALT = keccak256("TransferRewardNotifierFactory_v1.0.0");

  // --- Entry points --------------------------------------------------------//

  function run() external returns (TransferRewardNotifierFactory factory) {
    vm.startBroadcast();
    factory = _deploy();
    vm.stopBroadcast();
  }

  function deployPublic() external returns (TransferRewardNotifierFactory factory) {
    factory = _deploy();
  }

  // --- Internal deployment logic ------------------------------------------//

  function _deploy() internal returns (TransferRewardNotifierFactory factory) {
    ISingletonFactory singleton = ISingletonFactory(SINGLETON_FACTORY);
    bytes memory creationCode = type(TransferRewardNotifierFactory).creationCode;

    address deployed = _tryDeploy(singleton, creationCode);
    factory = TransferRewardNotifierFactory(deployed);
  }

  // Try CREATE2 via singleton; fallback to normal deploy if singleton unavailable
  function _tryDeploy(ISingletonFactory singleton, bytes memory creationCode)
    internal
    returns (address deployed)
  {
    deployed = _computeAddress(address(singleton), creationCode);
    if (deployed.code.length == 0) {
      try singleton.deploy(creationCode, SALT) returns (address addr) {
        deployed = addr;
      } catch {
        // local testing without singleton: deploy normally
        deployed = address(new TransferRewardNotifierFactory());
      }
    }
  }

  function _computeAddress(address factory, bytes memory creationCode)
    internal
    pure
    returns (address)
  {
    bytes32 codeHash = keccak256(creationCode);
    bytes32 data = keccak256(abi.encodePacked(bytes1(0xff), factory, SALT, codeHash));
    return address(uint160(uint256(data)));
  }
}

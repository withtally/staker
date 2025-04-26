// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {TransferFromRewardNotifierFactory} from
  "../src/notifiers/TransferFromRewardNotifierFactory.sol";

interface ISingletonFactory {
  function deploy(bytes memory creationCode, bytes32 salt) external returns (address deployed);
}

/// @title DeployTransferFromRewardNotifierFactory
/// @notice Deterministically deploys TransferFromRewardNotifierFactory across chains.
contract DeployTransferFromRewardNotifierFactory is Script {
  address constant SINGLETON_FACTORY = 0xce0042B868300000d44A59004Da54A005ffdcf9f;
  bytes32 constant SALT = keccak256("TransferFromRewardNotifierFactory_v1.0.0");

  function run() external returns (TransferFromRewardNotifierFactory factory) {
    vm.startBroadcast();
    factory = _deploy();
    vm.stopBroadcast();
  }

  function deployPublic() external returns (TransferFromRewardNotifierFactory factory) {
    factory = _deploy();
  }

  function _deploy() internal returns (TransferFromRewardNotifierFactory factory) {
    ISingletonFactory singleton = ISingletonFactory(SINGLETON_FACTORY);
    bytes memory creationCode = type(TransferFromRewardNotifierFactory).creationCode;
    address deployed = _tryDeploy(singleton, creationCode);
    factory = TransferFromRewardNotifierFactory(deployed);
  }

  function _tryDeploy(ISingletonFactory singleton, bytes memory creationCode)
    internal
    returns (address deployed)
  {
    deployed = _computeAddress(address(singleton), creationCode);
    if (deployed.code.length == 0) {
      try singleton.deploy(creationCode, SALT) returns (address addr) {
        deployed = addr;
      } catch {
        deployed = address(new TransferFromRewardNotifierFactory());
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

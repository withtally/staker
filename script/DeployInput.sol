// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

contract DeployInput {
  address constant GOVERNOR_TIMELOCK = 0x1a9C8182C09F50C8318d769245beA52c32BE35BC;
  address constant PAYOUT_TOKEN_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
  uint256 constant PAYOUT_AMOUNT = 10e18; // 10 (WETH)
  address constant STAKE_TOKEN_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984; // UNI
}

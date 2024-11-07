// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

interface IDelegates {
  function delegate(address delegatee) external;
  function delegates(address account) external view returns (address);
}

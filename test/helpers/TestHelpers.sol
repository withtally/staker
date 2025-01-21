// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

contract TestHelpers is Test {
  function _assumeSafeMockAddress(address _address) internal pure {
    // console.sol and console2.sol work by executing a staticcall to this address.
    address _console = 0x000000000000000000636F6e736F6c652e6c6f67;
    // If the fuzzer chooses one of these special addresses and we use `mockCall`, we subsequently
    // see test failures
    // stating that the selector does not exist. Use this helper on any address that will have a
    // mock call.
    vm.assume(_address != address(vm) && _address != address(_console));
  }
}

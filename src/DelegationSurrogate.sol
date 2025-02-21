// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title DelegationSurrogate
/// @author [ScopeLift](https://scopelift.co)
/// @notice A dead-simple contract whose only purpose is to hold ERC20 tokens which can always be
/// moved by the Surrogate's deployer.
abstract contract DelegationSurrogate {
  /// @param _token The token that will be held by this surrogate.
  constructor(IERC20 _token) {
    _token.approve(msg.sender, type(uint256).max);
  }
}

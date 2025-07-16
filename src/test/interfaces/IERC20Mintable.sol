// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Mintable is IERC20 {
  function mint(address _account, uint256 _value) external;
}

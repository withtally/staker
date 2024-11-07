// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IDelegates} from "src/interfaces/IDelegates.sol";

/// @notice A subset of the ERC20Votes-style governance token to which UNI conforms.
/// Methods related to standard ERC20 functionality and to delegation are included.
/// These methods are needed in the context of this system. Methods related to check pointing,
/// past voting weights, and other functionality are omitted.
interface IERC20Delegates is IERC20, IDelegates {}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20Delegates} from "./IERC20Delegates.sol";

/// @notice The interface of an ERC20 that supports a governor staker and all of the created
/// extensions.
interface IERC20Staking is IERC20Delegates, IERC20Permit {}

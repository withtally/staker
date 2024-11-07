// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IERC20Permit} from "openzeppelin/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";

interface IERC20Staking is IERC20Delegates, IERC20Permit {}

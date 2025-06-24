// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {RewardDistributor} from "../../src/RewardDistributor.sol";
import {RewardDistributorDelegateInitializer} from
  "../../src/RewardDistributorDelegateInitializer.sol";

contract RewardDistributorHarness is RewardDistributor, RewardDistributorDelegateInitializer {}

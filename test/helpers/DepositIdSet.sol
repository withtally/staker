// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.23;

import {StakerUpgradeable} from "../../src/StakerUpgradeable.sol";

struct DepositIdSet {
  StakerUpgradeable.DepositIdentifier[] ids;
  mapping(StakerUpgradeable.DepositIdentifier => bool) saved;
}

library LibDepositIdSet {
  function reduce(
    DepositIdSet storage s,
    uint256 acc,
    function(uint256,StakerUpgradeable.DepositIdentifier) external returns (uint256) func
  ) internal returns (uint256) {
    for (uint256 i; i < s.ids.length; ++i) {
      acc = func(acc, s.ids[i]);
    }
    return acc;
  }

  function add(DepositIdSet storage s, StakerUpgradeable.DepositIdentifier id) internal {
    if (!s.saved[id]) {
      s.ids.push(id);
      s.saved[id] = true;
    }
  }
}

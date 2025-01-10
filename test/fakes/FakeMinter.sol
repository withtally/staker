// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IMintable} from "src/interfaces/IMintable.sol";

contract FakeMinter is IMintable {
  IMintable public parentMinter;

  constructor(IMintable _parentMinter) {
    parentMinter = _parentMinter;
  }

  function mint(address _to, uint256 _amount) public override {
    parentMinter.mint(_to, _amount);
  }
}

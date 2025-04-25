pragma solidity ^0.8.28;

import {ERC20Fake} from "../fakes/ERC20Fake.sol";

contract MinterFake {
    ERC20Fake rewardToken;
    constructor(ERC20Fake _rewardToken) {
        rewardToken = _rewardToken;
    }
    function mint(address _to, uint256 _amount) external {
        rewardToken.mint(_to, _amount);
    }
}
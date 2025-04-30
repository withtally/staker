// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {MintRewardNotifierTestBase} from "../../src/test/MintRewardNotifierTestBase.sol";
import {StakeBase, WithdrawBase} from "../../src/test/StandardTestSuite.sol";
import {Staker} from "../../src/Staker.sol";
import {MintRewardNotifier} from "../../src/notifiers/MintRewardNotifier.sol";
import {DeployBaseFake} from "../fakes/DeployBaseFake.sol";
import {ERC20Fake} from "../fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "../mocks/MockERC20Votes.sol";
import {StakerTestBase} from "../../src/test/StakerTestBase.sol";

contract DeployMintRewardNotifierTestBase is MintRewardNotifierTestBase {
  DeployBaseFake DEPLOY_SCRIPT;

  function setUp() public virtual override {
    super.setUp();

    REWARD_TOKEN = new ERC20Fake();
    STAKE_TOKEN = new ERC20VotesMock();
    DEPLOY_SCRIPT = new DeployBaseFake(REWARD_TOKEN, STAKE_TOKEN);
    (, Staker _staker, address[] memory _rewardNotifiers) = DEPLOY_SCRIPT.run();
    mintRewardNotifier = MintRewardNotifier(_rewardNotifiers[0]);
    staker = _staker;
  }
}

contract Stake is StakeBase, DeployMintRewardNotifierTestBase {
  function setUp() public override(StakerTestBase, DeployMintRewardNotifierTestBase) {
    super.setUp();
  }
}

contract Withdraw is WithdrawBase, DeployMintRewardNotifierTestBase {
  function setUp() public override(StakerTestBase, DeployMintRewardNotifierTestBase) {
    super.setUp();
  }
}

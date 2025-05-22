// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {TransferRewardNotifierTestBase} from "../../src/test/TransferRewardNotifierTestBase.sol";
import {StakeBase, WithdrawBase} from "../../src/test/StandardTestSuite.sol";
import {Staker} from "../../src/Staker.sol";
import {TransferRewardNotifier} from "../../src/notifiers/TransferRewardNotifier.sol";
import {DeployTransferRewardNotifierFake} from "../fakes/DeployTransferRewardNotifierFake.sol";
import {ERC20Fake} from "../fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "../mocks/MockERC20Votes.sol";
import {StakerTestBase} from "../../src/test/StakerTestBase.sol";

contract DeployTransferRewardNotifierTestBase is TransferRewardNotifierTestBase {
  DeployTransferRewardNotifierFake DEPLOY_SCRIPT;

  function setUp() public virtual override {
    super.setUp();

    REWARD_TOKEN = new ERC20Fake();
    STAKE_TOKEN = new ERC20VotesMock();
    DEPLOY_SCRIPT = new DeployTransferRewardNotifierFake(REWARD_TOKEN, STAKE_TOKEN);
    (, Staker _staker, address[] memory _rewardNotifiers) = DEPLOY_SCRIPT.run();
    transferRewardNotifier = TransferRewardNotifier(_rewardNotifiers[0]);
    staker = _staker;
  }
}

contract Stake is StakeBase, DeployTransferRewardNotifierTestBase {
  function setUp() public override(StakerTestBase, DeployTransferRewardNotifierTestBase) {
    super.setUp();
  }
}

contract Withdraw is WithdrawBase, DeployTransferRewardNotifierTestBase {
  function setUp() public override(StakerTestBase, DeployTransferRewardNotifierTestBase) {
    super.setUp();
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {TransferFromRewardNotifierTestBase} from
  "../../src/test/TransferFromRewardNotifierTestBase.sol";
import {StakeBase, WithdrawBase} from "../../src/test/StandardTestSuite.sol";
import {Staker} from "../../src/Staker.sol";
import {TransferFromRewardNotifier} from "../../src/notifiers/TransferFromRewardNotifier.sol";
import {DeployTransferFromRewardNotifierFake} from
  "../fakes/DeployTransferFromRewardNotifierFake.sol";
import {ERC20Fake} from "../fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "../mocks/MockERC20Votes.sol";
import {StakerTestBase} from "../../src/test/StakerTestBase.sol";

contract DeployTransferFromRewardNotifierTestBase is TransferFromRewardNotifierTestBase {
  DeployTransferFromRewardNotifierFake DEPLOY_SCRIPT;

  function setUp() public virtual override {
    super.setUp();

    REWARD_TOKEN = new ERC20Fake();
    STAKE_TOKEN = new ERC20VotesMock();
    DEPLOY_SCRIPT = new DeployTransferFromRewardNotifierFake(REWARD_TOKEN, STAKE_TOKEN);
    (, Staker _staker, address[] memory _rewardNotifiers) = DEPLOY_SCRIPT.run();
    transferFromRewardNotifier = TransferFromRewardNotifier(_rewardNotifiers[0]);
    staker = _staker;
  }
}

contract Stake is StakeBase, DeployTransferFromRewardNotifierTestBase {
  function setUp() public override(StakerTestBase, DeployTransferFromRewardNotifierTestBase) {
    super.setUp();
  }
}

contract Withdraw is WithdrawBase, DeployTransferFromRewardNotifierTestBase {
  function setUp() public override(StakerTestBase, DeployTransferFromRewardNotifierTestBase) {
    super.setUp();
  }
}

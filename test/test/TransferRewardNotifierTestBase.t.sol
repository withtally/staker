// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {TransferRewardNotifierTestBase} from "../../src/test/TransferRewardNotifierTestBase.sol";
import {
  StakeBase,
  WithdrawBase,
  ClaimRewardBase,
  AlterClaimerBase,
  AlterDelegateeBase
} from "../../src/test/StakerForkTestSuite.sol";
import {Staker} from "../../src/Staker.sol";
import {TransferRewardNotifier} from "../../src/notifiers/TransferRewardNotifier.sol";
import {DeployTransferRewardNotifierFake} from "../fakes/DeployTransferRewardNotifierFake.sol";
import {ERC20Fake} from "../fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "../mocks/MockERC20Votes.sol";

contract DeployTransferRewardNotifierTestBase is TransferRewardNotifierTestBase {
  DeployTransferRewardNotifierFake DEPLOY_SCRIPT;

  function setUp() public virtual {
    REWARD_TOKEN = new ERC20Fake();
    STAKE_TOKEN = new ERC20VotesMock();
    DEPLOY_SCRIPT = new DeployTransferRewardNotifierFake(REWARD_TOKEN, STAKE_TOKEN);
    (, Staker _staker, address[] memory _rewardNotifiers) = DEPLOY_SCRIPT.run();
    transferRewardNotifier = TransferRewardNotifier(_rewardNotifiers[0]);
    staker = _staker;
  }
}

contract Stake is StakeBase, DeployTransferRewardNotifierTestBase {}

contract Withdraw is WithdrawBase, DeployTransferRewardNotifierTestBase {}

contract ClaimReward is ClaimRewardBase, DeployTransferRewardNotifierTestBase {}

contract AlterClaimer is AlterClaimerBase, DeployTransferRewardNotifierTestBase {}

contract AlterDelegatee is AlterDelegateeBase, DeployTransferRewardNotifierTestBase {}

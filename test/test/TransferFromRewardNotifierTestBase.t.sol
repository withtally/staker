// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {TransferFromRewardNotifierTestBase} from
  "../../src/test/TransferFromRewardNotifierTestBase.sol";
import {
  StakeBase,
  WithdrawBase,
  ClaimRewardBase,
  AlterClaimerBase,
  AlterDelegateeBase
} from "../../src/test/StakerForkTestSuite.sol";
import {Staker} from "../../src/Staker.sol";
import {TransferFromRewardNotifier} from "../../src/notifiers/TransferFromRewardNotifier.sol";
import {DeployTransferFromRewardNotifierFake} from
  "../fakes/DeployTransferFromRewardNotifierFake.sol";
import {ERC20Fake} from "../fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "../mocks/MockERC20Votes.sol";

contract DeployTransferFromRewardNotifierTestBase is TransferFromRewardNotifierTestBase {
  DeployTransferFromRewardNotifierFake DEPLOY_SCRIPT;

  function setUp() public virtual {
    REWARD_TOKEN = new ERC20Fake();
    STAKE_TOKEN = new ERC20VotesMock();
    DEPLOY_SCRIPT = new DeployTransferFromRewardNotifierFake(REWARD_TOKEN, STAKE_TOKEN);
    (, Staker _staker, address[] memory _rewardNotifiers) = DEPLOY_SCRIPT.run();
    transferFromRewardNotifier = TransferFromRewardNotifier(_rewardNotifiers[0]);
    staker = _staker;
  }
}

contract Stake is StakeBase, DeployTransferFromRewardNotifierTestBase {}

contract Withdraw is WithdrawBase, DeployTransferFromRewardNotifierTestBase {}

contract ClaimReward is ClaimRewardBase, DeployTransferFromRewardNotifierTestBase {}

contract AlterClaimer is AlterClaimerBase, DeployTransferFromRewardNotifierTestBase {}

contract AlterDelegatee is AlterDelegateeBase, DeployTransferFromRewardNotifierTestBase {}

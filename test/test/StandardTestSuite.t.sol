// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {StakerTestBase, IERC20Mintable} from "../../src/test/StakerTestBase.sol";
import {StakeBase} from "../../src/test/StandardTestSuite.sol";
import {Staker} from "../../src/Staker.sol";
import {MintRewardNotifier} from "../../src/notifiers/MintRewardNotifier.sol";
import {DeployBaseFake} from "../fakes/DeployBaseFake.sol";
import {ERC20Fake} from "../fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "../mocks/MockERC20Votes.sol";

contract DeployBaseHarnessTestBase is StakerTestBase {
  DeployBaseFake immutable DEPLOY_SCRIPT;
  MintRewardNotifier immutable REWARD_NOTIFIER;
  ERC20Fake REWARD_TOKEN;
  ERC20VotesMock STAKE_TOKEN;

  constructor() {
    REWARD_TOKEN = new ERC20Fake();
    STAKE_TOKEN = new ERC20VotesMock();
    DEPLOY_SCRIPT = new DeployBaseFake(REWARD_TOKEN, STAKE_TOKEN);
    (,Staker _staker, address[] memory _rewardNotifiers) = DEPLOY_SCRIPT.run();
    REWARD_NOTIFIER = MintRewardNotifier(_rewardNotifiers[0]);
	staker = _staker;
  }

  function _govToken() internal virtual override returns (IERC20Mintable) {
    return IERC20Mintable(address(STAKE_TOKEN));
  }

  function _mintTransferAndNotifyReward(uint256 _amount) public override virtual {
    vm.assume(address(REWARD_NOTIFIER) != address(0));
    REWARD_TOKEN.mint(address(REWARD_NOTIFIER), _amount);

    vm.startPrank(address(REWARD_NOTIFIER));
    REWARD_TOKEN.transfer(address(staker), _amount);
    staker.notifyRewardAmount(_amount);
    vm.stopPrank();
  }
}

contract Stake is StakeBase, DeployBaseHarnessTestBase  {}

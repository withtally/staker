// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {StakerFactory} from "../src/factory/StakerFactory.sol";
import {FullStaker} from "../src/factory/FullStaker.sol";
import {ERC20VotesMock} from "./mocks/MockERC20Votes.sol";
import {IdentityEarningPowerCalculator} from "../src/calculators/IdentityEarningPowerCalculator.sol";

contract StakerFactoryTest is Test {
  StakerFactory factory;
  ERC20VotesMock stakeToken;
  ERC20VotesMock rewardsToken;
  IdentityEarningPowerCalculator calc;

  function setUp() public {
    factory = new StakerFactory();
    stakeToken = new ERC20VotesMock();
    rewardsToken = new ERC20VotesMock();
    calc = new IdentityEarningPowerCalculator();

    // Mint tokens to this contract for later interactions
    stakeToken.mint(address(this), 1_000 ether);
    rewardsToken.mint(address(this), 1_000 ether);
  }

  function testCreateStakingSystem() public {
    address admin = address(this);
    address stakerAddr = factory.createStakingSystem(
      rewardsToken,
      stakeToken,
      calc,
      0,
      admin
    );

    assertGt(stakerAddr.code.length, 0, "Deployed staker should have code");

    // Verify factory bookkeeping
    assertEq(factory.allStakersLength(), 1);
    assertEq(factory.allStakers(0), stakerAddr);

    // Basic sanity: reward token matches
    FullStaker staker = FullStaker(stakerAddr);
    assertEq(address(staker.REWARD_TOKEN()), address(rewardsToken));
    assertEq(address(staker.STAKE_TOKEN()), address(stakeToken));
    assertEq(staker.admin(), admin);
  }

  /*//////////////////////////////////////////////////////////////
                              Edge cases
  //////////////////////////////////////////////////////////////*/

  function testRevertsIfAdminZeroAddress() public {
    vm.expectRevert();
    factory.createStakingSystem(rewardsToken, stakeToken, calc, 0, address(0));
  }

  function testLargeMaxBumpTip() public {
    uint256 largeTip = type(uint256).max;
    address stakerAddr = factory.createStakingSystem(
      rewardsToken,
      stakeToken,
      calc,
      largeTip,
      address(this)
    );
    FullStaker staker = FullStaker(stakerAddr);
    assertEq(staker.maxBumpTip(), largeTip);
  }

  /*//////////////////////////////////////////////////////////////
                        Multiple deployments
  //////////////////////////////////////////////////////////////*/

  function testMultipleDeployments() public {
    address admin = address(this);

    for (uint256 i = 0; i < 3; i++) {
      // new tokens each iteration to avoid clashes
      ERC20VotesMock stakeT = new ERC20VotesMock();
      ERC20VotesMock rewardT = new ERC20VotesMock();

      address stakerAddr = factory.createStakingSystem(
        rewardT,
        stakeT,
        calc,
        i, // vary bump tip
        admin
      );

      assertGt(stakerAddr.code.length, 0);
      assertEq(factory.allStakers(i), stakerAddr);
    }

    assertEq(factory.allStakersLength(), 3);
  }
} 
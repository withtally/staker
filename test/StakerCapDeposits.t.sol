// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, stdError} from "forge-std/Test.sol";
import {StakerTestBase} from "test/StakerTestBase.sol";
import {StakerHarnessCapDeposits} from "test/harnesses/StakerHarnessCapDeposits.sol";
import {Staker} from "../src/Staker.sol";
import {StakerCapDeposits} from "../src/extensions/StakerCapDeposits.sol";
import {DelegationSurrogate} from "../src/DelegationSurrogate.sol";

contract StakerCapDepositsTest is StakerTestBase {
  StakerHarnessCapDeposits govStaker;
  uint256 initialTotalStakeCap = 1_000_000e18;

  function _deployStaker() public virtual override(StakerTestBase) returns (Staker _staker) {
    return new StakerHarnessCapDeposits(
      rewardToken,
      govToken,
      earningPowerCalculator,
      maxBumpTip,
      admin,
      "Staker",
      initialTotalStakeCap
    );
  }

  function setUp() public virtual override(StakerTestBase) {
    StakerTestBase.setUp();

    govStaker = StakerHarnessCapDeposits(address(baseStaker));
  }
}

contract Constructor is StakerCapDepositsTest {
  function test_SetsTheInitialTotalStakeCap() public view {
    assertEq(govStaker.totalStakeCap(), initialTotalStakeCap);
  }

  function testFuzz_SetsTheInitialTotalStakeCapToArbitraryValues(uint256 _initialTotalStakeCap)
    public
  {
    StakerHarnessCapDeposits _govStaker = new StakerHarnessCapDeposits(
      rewardToken,
      govToken,
      earningPowerCalculator,
      maxBumpTip,
      admin,
      "Staker",
      _initialTotalStakeCap
    );
    assertEq(_govStaker.totalStakeCap(), _initialTotalStakeCap);
  }

  function testFuzz_EmitsATotalStakeCapSetEvent(uint256 _initialTotalStakeCap) public {
    vm.expectEmit();
    emit StakerCapDeposits.TotalStakeCapSet(0, _initialTotalStakeCap);
    new StakerHarnessCapDeposits(
      rewardToken,
      govToken,
      earningPowerCalculator,
      maxBumpTip,
      admin,
      "Staker",
      _initialTotalStakeCap
    );
  }
}

contract SetTotalStakeCap is StakerCapDepositsTest {
  function testFuzz_UpdatesTheTotalStakeCap(uint256 _newTotalStakeCap) public {
    vm.prank(admin);
    govStaker.setTotalStakeCap(_newTotalStakeCap);

    assertEq(govStaker.totalStakeCap(), _newTotalStakeCap);
  }

  function testFuzz_EmitsATotalStakeCapSetEvent(uint256 _newTotalStakeCap) public {
    vm.prank(admin);
    vm.expectEmit();
    emit StakerCapDeposits.TotalStakeCapSet(initialTotalStakeCap, _newTotalStakeCap);
    govStaker.setTotalStakeCap(_newTotalStakeCap);
  }

  function testFuzz_RevertIf_TheCallerIsNotTheAdmin(uint256 _newTotalStakeCap, address _notAdmin)
    public
  {
    vm.assume(_notAdmin != govStaker.admin());

    vm.prank(_notAdmin);
    vm.expectRevert(
      abi.encodeWithSelector(Staker.Staker__Unauthorized.selector, bytes32("not admin"), _notAdmin)
    );
    govStaker.setTotalStakeCap(_newTotalStakeCap);
  }
}

contract _Stake is StakerCapDepositsTest {
  function testFuzz_AllowsStakingWhenTheAmountIsBelowTheCap(
    address _depositor,
    uint256 _amount,
    address _delegatee
  ) public {
    _amount = bound(_amount, 0, govStaker.totalStakeCap());
    _mintGovToken(_depositor, _amount);

    // Call to stake does not revert.
    _stake(_depositor, _amount, _delegatee);
    DelegationSurrogate _surrogate = govStaker.surrogates(_delegatee);

    // Some sanity checks to ensure the stake operation has completed.
    assertEq(govStaker.totalStaked(), _amount);
    assertEq(govToken.balanceOf(address(_surrogate)), _amount);
    assertEq(govToken.delegates(address(_surrogate)), _delegatee);
    assertEq(govToken.balanceOf(_depositor), 0);
  }

  function testFuzz_AllowsStakingWhenMultipleDepositsStayBelowTheCap(
    address _depositor1,
    address _depositor2,
    uint256 _amount1,
    uint256 _amount2,
    address _delegatee1,
    address _delegatee2
  ) public {
    // The total staked will be <= the cap.
    _amount1 = bound(_amount1, 0, govStaker.totalStakeCap());
    _amount2 = bound(_amount2, 0, govStaker.totalStakeCap() - _amount1);
    _mintGovToken(_depositor1, _amount1);
    _mintGovToken(_depositor2, _amount2);

    // Calls to stake do not revert
    Staker.DepositIdentifier _depositId1 = _stake(_depositor1, _amount1, _delegatee1);
    Staker.DepositIdentifier _depositId2 = _stake(_depositor2, _amount2, _delegatee2);
    Staker.Deposit memory _deposit1 = _fetchDeposit(_depositId1);
    Staker.Deposit memory _deposit2 = _fetchDeposit(_depositId2);

    // Some sanity checks to ensure the stake operations completed.
    assertEq(govStaker.totalStaked(), _amount1 + _amount2);
    assertEq(_deposit1.balance, _amount1);
    assertEq(_deposit2.balance, _amount2);
  }

  function testFuzz_RevertIf_TheAmountIsAboveTheCap(
    address _depositor,
    uint256 _amount,
    address _delegatee
  ) public {
    _amount = bound(_amount, govStaker.totalStakeCap() + 1, type(uint96).max);
    _mintGovToken(_depositor, _amount);

    vm.startPrank(_depositor);
    govToken.approve(address(govStaker), _amount);

    vm.expectRevert(StakerCapDeposits.StakerCapDeposits__CapExceeded.selector);
    govStaker.stake(_amount, _delegatee);
    vm.stopPrank();
  }

  function testFuzz_RevertIf_TheNextDepositWouldExceedTheCap(
    address _depositor1,
    address _depositor2,
    uint256 _amount1,
    uint256 _amount2,
    address _delegatee1,
    address _delegatee2
  ) public {
    _amount1 = bound(_amount1, 0, govStaker.totalStakeCap());
    uint256 _remainingCap = govStaker.totalStakeCap() - _amount1;
    // The total staked will be greater than the cap after the second deposit.
    _amount2 = bound(_amount2, _remainingCap + 1, type(uint96).max);
    _mintGovToken(_depositor1, _amount1);
    _mintGovToken(_depositor2, _amount2);

    // First call to stake does not revert.
    Staker.DepositIdentifier _depositId1 = _stake(_depositor1, _amount1, _delegatee1);
    Staker.Deposit memory _deposit1 = _fetchDeposit(_depositId1);
    // Some sanity checks to ensure the stake operation completed.
    assertEq(govStaker.totalStaked(), _amount1);
    assertEq(_deposit1.balance, _amount1);

    // The second attempt to stake should revert
    vm.startPrank(_depositor2);
    govToken.approve(address(govStaker), _amount2);
    vm.expectRevert(StakerCapDeposits.StakerCapDeposits__CapExceeded.selector);
    govStaker.stake(_amount2, _delegatee2);
    vm.stopPrank();
  }

  function testFuzz_AllowADepositIfTheCapIsRaised(
    address _depositor1,
    address _depositor2,
    uint256 _amount1,
    uint256 _amount2,
    address _delegatee1,
    address _delegatee2
  ) public {
    _amount1 = bound(_amount1, 0, govStaker.totalStakeCap());
    uint256 _remainingCap = govStaker.totalStakeCap() - _amount1;
    // The total staked will be greater than the cap after the second deposit.
    _amount2 = bound(_amount2, _remainingCap + 1, type(uint96).max);
    _mintGovToken(_depositor1, _amount1);
    _mintGovToken(_depositor2, _amount2);

    // First call to stake does not revert.
    Staker.DepositIdentifier _depositId1 = _stake(_depositor1, _amount1, _delegatee1);
    Staker.Deposit memory _deposit1 = _fetchDeposit(_depositId1);
    // Some sanity checks to ensure the stake operation completed.
    assertEq(govStaker.totalStaked(), _amount1);
    assertEq(_deposit1.balance, _amount1);

    // The second attempt to stake should revert.
    vm.startPrank(_depositor2);
    govToken.approve(address(govStaker), _amount2);
    vm.expectRevert(StakerCapDeposits.StakerCapDeposits__CapExceeded.selector);
    govStaker.stake(_amount2, _delegatee2);
    vm.stopPrank();

    // The cap is raised sufficiently high to allow the deposit.
    uint256 _newTotalStakeCap = _amount1 + _amount2;
    vm.prank(admin);
    govStaker.setTotalStakeCap(_newTotalStakeCap);

    // Now the same deposit succeeds.
    Staker.DepositIdentifier _depositId2 = _stake(_depositor2, _amount2, _delegatee2);

    // Some sanity checks to ensure the stake operation completed.
    Staker.Deposit memory _deposit2 = _fetchDeposit(_depositId2);
    assertEq(govStaker.totalStaked(), _amount1 + _amount2);
    assertEq(_deposit2.balance, _amount2);
  }

  function testFuzz_RevertIf_TheCapIsLoweredAndTheNextDepositWouldExceedTheCap(
    address _depositor1,
    address _depositor2,
    uint256 _amount1,
    uint256 _amount2,
    address _delegatee1,
    address _delegatee2
  ) public {
    // The total staked will be <= the current cap.
    _amount1 = bound(_amount1, 1, govStaker.totalStakeCap());
    _amount2 = bound(_amount2, 0, govStaker.totalStakeCap() - _amount1);
    _mintGovToken(_depositor1, _amount1);
    _mintGovToken(_depositor2, _amount2);

    // First call to stake does not revert.
    Staker.DepositIdentifier _depositId1 = _stake(_depositor1, _amount1, _delegatee1);
    Staker.Deposit memory _deposit1 = _fetchDeposit(_depositId1);
    // Some sanity checks to ensure the stake operation completed.
    assertEq(govStaker.totalStaked(), _amount1);
    assertEq(_deposit1.balance, _amount1);

    // The cap is lowered to make the next deposit impossible.
    uint256 _newTotalStakeCap = _amount1 + _amount2 - 1;
    vm.prank(admin);
    govStaker.setTotalStakeCap(_newTotalStakeCap);

    // The second attempt to stake should revert.
    vm.startPrank(_depositor2);
    govToken.approve(address(govStaker), _amount2);
    vm.expectRevert(StakerCapDeposits.StakerCapDeposits__CapExceeded.selector);
    govStaker.stake(_amount2, _delegatee2);
    vm.stopPrank();
  }
}

contract _StakeMore is StakerCapDepositsTest {
  function testFuzz_AllowsMoreToBeStakedIfTheTotalIsBelowTheCap(
    address _depositor,
    uint256 _depositAmount,
    uint256 _addAmount,
    address _delegatee
  ) public {
    _depositAmount = bound(_depositAmount, 0, govStaker.totalStakeCap());
    uint256 _remainingCap = govStaker.totalStakeCap() - _depositAmount;
    // The amount added to the deposit will still be less than the cap.
    _addAmount = bound(_addAmount, 0, _remainingCap);
    _mintGovToken(_depositor, _depositAmount + _addAmount);

    // Initial stake is completed
    Staker.DepositIdentifier _depositId = _stake(_depositor, _depositAmount, _delegatee);
    // More stake is added without the call reverting.
    vm.startPrank(_depositor);
    govToken.approve(address(govStaker), _addAmount);
    govStaker.stakeMore(_depositId, _addAmount);
    vm.stopPrank();

    Staker.Deposit memory _deposit = _fetchDeposit(_depositId);
    DelegationSurrogate _surrogate = govStaker.surrogates(_deposit.delegatee);

    // Sanity checks to make sure the staking operations completed successfully.
    assertEq(govStaker.totalStaked(), _depositAmount + _addAmount);
    assertEq(govToken.balanceOf(address(_surrogate)), _depositAmount + _addAmount);
    assertEq(_deposit.balance, _depositAmount + _addAmount);
  }

  function testFuzz_RevertIf_StakingMoreWouldExceedTheCap(
    address _depositor,
    uint256 _depositAmount,
    uint256 _addAmount,
    address _delegatee
  ) public {
    _depositAmount = bound(_depositAmount, 0, govStaker.totalStakeCap());
    uint256 _remainingCap = govStaker.totalStakeCap() - _depositAmount;
    // The amount added cause the total staked to exceed the cap.
    _addAmount = bound(_addAmount, _remainingCap + 1, type(uint96).max);
    _mintGovToken(_depositor, _depositAmount + _addAmount);

    // Initial stake is completed
    Staker.DepositIdentifier _depositId = _stake(_depositor, _depositAmount, _delegatee);

    // Reverts when attempting to add more such that the cap is exceeded.
    vm.startPrank(_depositor);
    govToken.approve(address(govStaker), _addAmount);
    vm.expectRevert(StakerCapDeposits.StakerCapDeposits__CapExceeded.selector);
    govStaker.stakeMore(_depositId, _addAmount);
    vm.stopPrank();
  }
}

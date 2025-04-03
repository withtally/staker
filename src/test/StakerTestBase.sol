// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage} from "forge-std/Test.sol";
import {Staker} from "../Staker.sol";
import {DelegationSurrogate} from "../DelegationSurrogate.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Mintable} from "./interfaces/IERC20Mintable.sol";
import {PercentAssertions} from "./helpers/PercentAssertions.sol";

abstract contract StakerTestBase is Test, PercentAssertions {
  Staker staker;
  IERC20 STAKE_TOKEN;
  IERC20 REWARD_TOKEN;

  mapping(DelegationSurrogate surrogate => bool isKnown) isKnownSurrogate;
  mapping(address depositor => bool isKnown) isKnownDepositor;

  function setUp() public virtual {
    // Set the block timestamp to an arbitrary value to avoid introducing assumptions into tests
    // based on a starting timestamp of 0, which is the default.
    _jumpAhead(1234);
  }

  /// @notice A function to move time forward.
  /// @param _seconds The time to jump forward in seconds.
  function _jumpAhead(uint256 _seconds) public virtual {
    vm.warp(block.timestamp + _seconds);
  }

  /// @notice A function that will move time forward by a percentage of the underlying Stake's
  /// reward duration.
  /// @param _percent The percent of the Staker's reward duration to move forward.
  function _jumpAheadByPercentOfRewardDuration(uint256 _percent) public virtual {
    uint256 _seconds = (_percent * staker.REWARD_DURATION()) / 100;
    _jumpAhead(_seconds);
  }

  /// @notice Bound the reward amount to a realistic number.
  /// @param _rewardAmount The unbounded reward amount.
  /// @return _boundedRewardAmount The bounded reward amount.
  function _boundToRealisticReward(uint256 _rewardAmount)
    public
    view
    virtual
    returns (uint256 _boundedRewardAmount)
  {
    _boundedRewardAmount = bound(_rewardAmount, 200e6, 10_000_000e18);
  }

  /// @notice Bound the stake to a realistic amount.
  /// @param _stakeAmount The stake amount to bound.
  /// @return _boundedStakeAmount The bounded stake amount.
  function _boundToRealisticStake(uint256 _stakeAmount)
    public
    view
    virtual
    returns (uint256 _boundedStakeAmount)
  {
    _boundedStakeAmount = bound(_stakeAmount, 0.1e18, 25_000_000e18);
  }

  /// @notice Bound the mint amount to a realistic value.
  /// @param _amount The unbounded mint amount.
  /// @return The bounded mint amount.
  function _boundMintAmount(uint256 _amount) internal pure virtual returns (uint256) {
    return bound(_amount, 0, 100_000_000e18);
  }

  /// @notice A function to mint a specified amount of stake token to an address.
  /// @param _to The address for where to mint tokens.
  /// @param _amount The amount of tokens to be minted.
  function _mintStakeToken(address _to, uint96 _amount) internal virtual {
    vm.assume(_to != address(0));
    IERC20Mintable(address(STAKE_TOKEN)).mint(_to, _amount);
  }

  /// @notice A function to mint and stake tokens with a bounded amount.
  /// @param _depositor The address staking the minted tokens.
  /// @param _amount The amount of tokens to mint and stake.
  /// @param _delegatee The address that receives the stake's voting power.
  function _boundMintAndStake(address _depositor, uint256 _amount, address _delegatee)
    internal
    virtual
    returns (uint256 _boundedAmount, Staker.DepositIdentifier _depositId)
  {
    _boundedAmount = _boundMintAmount(_amount);
    _mintStakeToken(_depositor, uint96(_boundedAmount));
    _depositId = _stake(_depositor, _boundedAmount, _delegatee);
  }

  /// @notice A test helper that wraps calling the `stake` function on the underlying Staker
  /// contract.
  /// @param _depositor The address of the depositor.
  /// @param _amount The amount to stake.
  /// @param _delegatee The address that will receive the voting power of the stake.
  /// @return _depositId The id of the created deposit.
  function _stake(address _depositor, uint256 _amount, address _delegatee)
    internal
    virtual
    returns (Staker.DepositIdentifier _depositId)
  {
    vm.assume(_delegatee != address(0));

    vm.startPrank(_depositor);
    STAKE_TOKEN.approve(address(staker), _amount);
    _depositId = staker.stake(_amount, _delegatee);
    vm.stopPrank();

    // Called after the stake so the surrogate will exist
    _assumeSafeDepositorAndSurrogate(_depositor, _delegatee);
  }

  /// @notice A test helper that wraps calling `withdraw` on the underlying Staker contract.
  /// @param _depositor The depositor that is withdrawing their stake.
  /// @param _depositId The deposit id to withdraw stake from.
  /// @param _amount The amount of stake to withdraw.
  function _withdraw(address _depositor, Staker.DepositIdentifier _depositId, uint256 _amount)
    internal
    virtual
  {
    vm.prank(_depositor);
    staker.withdraw(_depositId, _amount);
  }

  /// @notice A helper function to that returns a deposit struct given a deposit ID.
  /// @param _depositId The id of the deposit to fetch.
  /// @return A struct of deposit information.
  function _fetchDeposit(Staker.DepositIdentifier _depositId)
    internal
    view
    virtual
    returns (Staker.Deposit memory)
  {
    (
      uint96 _balance,
      address _owner,
      uint96 _earningPower,
      address _delegatee,
      address _claimer,
      uint256 _rewardPerTokenCheckpoint,
      uint256 _scaledUnclaimedRewardCheckpoint
    ) = staker.deposits(_depositId);
    return Staker.Deposit({
      balance: _balance,
      owner: _owner,
      delegatee: _delegatee,
      claimer: _claimer,
      earningPower: _earningPower,
      rewardPerTokenCheckpoint: _rewardPerTokenCheckpoint,
      scaledUnclaimedRewardCheckpoint: _scaledUnclaimedRewardCheckpoint
    });
  }

  /// @notice A test helper that calls `notifyRewardAmount`.
  /// @param _amount The amount of tokens to send to the Staker contract.
  function _notifyRewardAmount(uint256 _amount) public virtual;

  //// @notice A function to help calculate the earned rewards over a given period of the reward
  // duration.
  /// @param _earningPower The earning power during the reward duration.
  /// @param _rewardAmount The total amount of reward staker's split.
  /// @param _percentDuration The total duration of the reward period that has passed.
  /// @return The total rewards the given earning power has earned.
  function _calculateEarnedRewards(
    uint256 _earningPower,
    uint256 _rewardAmount,
    uint256 _percentDuration
  ) internal virtual returns (uint256) {
    return
      _percentOf((_earningPower * _rewardAmount) / staker.totalEarningPower(), _percentDuration);
  }

  /// @notice A test helper to prevent address collisions with depositors and delegate surrogate
  /// contracts.
  function _assumeSafeDepositorAndSurrogate(address _depositor, address _delegatee) internal {
    DelegationSurrogate _surrogate = staker.surrogates(_delegatee);
    isKnownDepositor[_depositor] = true;
    isKnownSurrogate[_surrogate] = true;

    vm.assume(
      (!isKnownSurrogate[DelegationSurrogate(_depositor)])
        && (!isKnownDepositor[address(_surrogate)])
    );
  }
}

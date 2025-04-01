// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, stdError} from "forge-std/Test.sol";
import {Staker} from "../Staker.sol";
import {DelegationSurrogate} from "../DelegationSurrogate.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Mintable is IERC20 {
  function mint(address _account, uint256 _value) external;
}

abstract contract StakerTestBase is Test {
  Staker staker;
  IERC20Mintable govToken;

  mapping(DelegationSurrogate surrogate => bool isKnown) isKnownSurrogate;
  mapping(address depositor => bool isKnown) isKnownDepositor;

  // deploy script
  function setUp() public virtual {
    // Set the block timestamp to an arbitrary value to avoid introducing assumptions into tests
    // based on a starting timestamp of 0, which is the default.
    _jumpAhead(1234);

    // rewardToken = new ERC20Fake();
    // vm.label(address(rewardToken), "Reward Token");

    govToken = _govToken();
    vm.label(address(govToken), "Governance Token");

    // rewardNotifier = address(0xaffab1ebeef);
    // vm.label(rewardNotifier, "Reward Notifier");

    // earningPowerCalculator = new MockFullEarningPowerCalculator();
    // vm.label(address(earningPowerCalculator), "Full Earning Power Calculator");

    // admin = makeAddr("admin");

    // baseStaker = _deployStaker();
    // vm.label(address(baseStaker), "GovStaker");

    // vm.prank(admin);
    // baseStaker.setRewardNotifier(rewardNotifier, true);

    // // Convenience for use in tests
    // SCALE_FACTOR = baseStaker.SCALE_FACTOR();
  }

  function _govToken() internal virtual returns (IERC20Mintable);

  function _jumpAhead(uint256 _seconds) public virtual {
    vm.warp(block.timestamp + _seconds);
  }

  function _jumpAheadByPercentOfRewardDuration(uint256 _percent) public {
    uint256 _seconds = (_percent * staker.REWARD_DURATION()) / 100;
    _jumpAhead(_seconds);
  }

  function _boundToRealisticReward(uint256 _rewardAmount)
    public
    view
    virtual
    returns (uint256 _boundedRewardAmount)
  {
    _boundedRewardAmount = bound(_rewardAmount, 200e6, 10_000_000e18);
  }

  function _boundToRealisticStake(uint256 _stakeAmount)
    public
    view
    virtual
    returns (uint256 _boundedStakeAmount)
  {
    _boundedStakeAmount = bound(_stakeAmount, 0.1e18, 25_000_000e18);
  }

  function _boundMintAmount(uint256 _amount) internal pure returns (uint256) {
    return bound(_amount, 0, 100_000_000e18);
  }

  function _mintGovToken(address _to, uint96 _amount) internal {
    vm.assume(_to != address(0));
    govToken.mint(_to, _amount);
  }

  // function _mintGovToken(address _to, uint256 _amount) internal {
  //   // vm.assume(_to != address(0));
  //   // govToken.mint(_to, _amount);
  // }

  // function _setClaimFeeAndCollector(uint96 _amount, address _collector) internal {
  //   // Staker.ClaimFeeParameters memory _params =
  //   //   Staker.ClaimFeeParameters({feeAmount: _amount, feeCollector: _collector});

  //   // vm.prank(admin);
  //   // baseStaker.setClaimFeeParameters(_params);
  // }
  //
  // TODO: different earning power calculators would override this
  function _stake(address _depositor, uint256 _amount, address _delegatee)
    internal
    virtual
    returns (Staker.DepositIdentifier _depositId)
  {
    vm.assume(_delegatee != address(0));

    vm.startPrank(_depositor);
    govToken.approve(address(staker), _amount);
    _depositId = staker.stake(_amount, _delegatee);
    vm.stopPrank();

    // Called after the stake so the surrogate will exist
    _assumeSafeDepositorAndSurrogate(_depositor, _delegatee);
  }

  //
  // function _stake(address _depositor, uint256 _amount, address _delegatee, address _claimer)
  //   internal
  //   returns (Staker.DepositIdentifier _depositId)
  // {
  //   // vm.assume(_delegatee != address(0) && _claimer != address(0));

  //   // vm.startPrank(_depositor);
  //   // govToken.approve(address(baseStaker), _amount);
  //   // _depositId = baseStaker.stake(_amount, _delegatee, _claimer);
  //   // vm.stopPrank();

  //   // // Called after the stake so the surrogate will exist
  //   // _assumeSafeDepositorAndSurrogate(_depositor, _delegatee);
  // }

  function _fetchDeposit(Staker.DepositIdentifier _depositId)
    internal
    view
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

  function _boundMintAndStake(address _depositor, uint256 _amount, address _delegatee)
    internal
    returns (uint256 _boundedAmount, Staker.DepositIdentifier _depositId)
  {
    _boundedAmount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, uint96(_boundedAmount));
    _depositId = _stake(_depositor, _boundedAmount, _delegatee);
  }

  // function _boundMintAndStake(
  //   address _depositor,
  //   uint256 _amount,
  //   address _delegatee,
  //   address _claimer
  // ) internal returns (uint256 _boundedAmount, Staker.DepositIdentifier _depositId) {
  //   // _boundedAmount = _boundMintAmount(_amount);
  //   // _mintGovToken(_depositor, _boundedAmount);
  //   // _depositId = _stake(_depositor, _boundedAmount, _delegatee, _claimer);
  // }

  // function _mintTransferAndNotifyReward(uint256 _amount) public {
  //   rewardToken.mint(rewardNotifier, _amount);

  //   vm.startPrank(rewardNotifier);
  //   rewardToken.transfer(address(govStaker), _amount);
  //   govStaker.notifyRewardAmount(_amount);
  //   vm.stopPrank();
  // }

  // function _mintTransferAndNotifyReward(address _rewardNotifier, uint256 _amount) public {
  //   vm.assume(_rewardNotifier != address(0));
  //   rewardToken.mint(_rewardNotifier, _amount);

  //   vm.startPrank(_rewardNotifier);
  //   rewardToken.transfer(address(govStaker), _amount);
  //   govStaker.notifyRewardAmount(_amount);
  //   vm.stopPrank();
  // }

  function _mintTransferAndNotifyReward(uint256 _amount) public virtual;

  function _assumeSafeDepositorAndSurrogate(address _depositor, address _delegatee) internal {
    DelegationSurrogate _surrogate = staker.surrogates(_delegatee);
    isKnownDepositor[_depositor] = true;
    isKnownSurrogate[_surrogate] = true;

    vm.assume(
      (!isKnownSurrogate[DelegationSurrogate(_depositor)])
        && (!isKnownDepositor[address(_surrogate)])
    );
  }

  // TODO: Move Percent assertions to the src
  // Because there will be (expected) rounding errors in the amount of rewards earned, this helper
  // checks that the truncated number is lesser and within 1% of the expected number.
  function assertLteWithinOnePercent(uint256 a, uint256 b) public {
    if (a > b) {
      emit log("Error: a <= b not satisfied");
      emit log_named_uint("  Expected", b);
      emit log_named_uint("    Actual", a);

      fail();
    }

    uint256 minBound = (b * 9900) / 10_000;

    if (a < minBound) {
      emit log("Error: a >= 0.99 * b not satisfied");
      emit log_named_uint("  Expected", b);
      emit log_named_uint("    Actual", a);
      emit log_named_uint("  minBound", minBound);

      fail();
    }
  }

  function _percentOf(uint256 _amount, uint256 _percent) public pure returns (uint256) {
    // For cases where the percentage is less than 100, we calculate the percentage by
    // taking the inverse percentage and subtracting it. This effectively rounds _up_ the
    // value by putting the truncation on the opposite side. For example, 92% of 555 is 510.6.
    // Calculating it in this way would yield (555 - 44) = 511, instead of 510.
    if (_percent < 100) return _amount - ((100 - _percent) * _amount) / 100;
    else return (_percent * _amount) / 100;
  }

  // This helper is for normal rounding errors, i.e. if the number might be truncated down by 1
  function assertLteWithinOneUnit(uint256 a, uint256 b) public {
    if (a > b) {
      emit log("Error: a <= b not satisfied");
      emit log_named_uint("  Expected", b);
      emit log_named_uint("    Actual", a);

      fail();
    }

    uint256 minBound = b - 1;

    if (!((a == b) || (a == minBound))) {
      emit log("Error: a == b || a  == b-1");
      emit log_named_uint("  Expected", b);
      emit log_named_uint("    Actual", a);

      fail();
    }
  }
}

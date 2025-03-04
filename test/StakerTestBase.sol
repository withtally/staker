// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Vm, Test, stdStorage, StdStorage, console2, stdError} from "forge-std/Test.sol";
import {Staker} from "../src/Staker.sol";
import {DelegationSurrogate} from "../src/DelegationSurrogate.sol";
import {ERC20VotesMock} from "./mocks/MockERC20Votes.sol";
import {ERC20Fake} from "./fakes/ERC20Fake.sol";
import {MockFullEarningPowerCalculator} from "./mocks/MockFullEarningPowerCalculator.sol";
import {PercentAssertions} from "./helpers/PercentAssertions.sol";

// Base utilities that can be used for testing concrete Staker implementations. Steps:
// 1. Create a test file that inherits from StakerTestBase
// 2. Implement the virtual `_deployStaker` method which returns an instance of your concrete
//    staker.
// 3. Override the `setUp` method, call `super.setUp`, then do any other set up for your tests as
//    needed.
// 4. Write your tests, taking advantage of the helpers provided by this base.
abstract contract StakerTestBase is Test, PercentAssertions {
  ERC20Fake rewardToken;
  ERC20VotesMock govToken;
  MockFullEarningPowerCalculator earningPowerCalculator;

  address admin;
  address rewardNotifier;
  Staker baseStaker;
  uint256 SCALE_FACTOR;
  uint256 maxBumpTip = 1e18;

  mapping(DelegationSurrogate surrogate => bool isKnown) isKnownSurrogate;
  mapping(address depositor => bool isKnown) isKnownDepositor;

  function _deployStaker() public virtual returns (Staker _staker);

  function setUp() public virtual {
    // Set the block timestamp to an arbitrary value to avoid introducing assumptions into tests
    // based on a starting timestamp of 0, which is the default.
    _jumpAhead(1234);

    rewardToken = new ERC20Fake();
    vm.label(address(rewardToken), "Reward Token");

    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");

    rewardNotifier = address(0xaffab1ebeef);
    vm.label(rewardNotifier, "Reward Notifier");

    earningPowerCalculator = new MockFullEarningPowerCalculator();
    vm.label(address(earningPowerCalculator), "Full Earning Power Calculator");

    admin = makeAddr("admin");

    baseStaker = _deployStaker();
    vm.label(address(baseStaker), "GovStaker");

    vm.prank(admin);
    baseStaker.setRewardNotifier(rewardNotifier, true);

    // Convenience for use in tests
    SCALE_FACTOR = baseStaker.SCALE_FACTOR();
  }

  function _min(uint256 _leftValue, uint256 _rightValue) internal pure returns (uint256) {
    return _leftValue > _rightValue ? _rightValue : _leftValue;
  }

  function _jumpAhead(uint256 _seconds) public {
    vm.warp(block.timestamp + _seconds);
  }

  function _boundMintAmount(uint256 _amount) internal pure returns (uint256) {
    return bound(_amount, 0, 100_000_000e18);
  }

  function _mintGovToken(address _to, uint256 _amount) internal {
    vm.assume(_to != address(0));
    govToken.mint(_to, _amount);
  }

  function _boundToRealisticStake(uint256 _stakeAmount)
    public
    pure
    returns (uint256 _boundedStakeAmount)
  {
    _boundedStakeAmount = bound(_stakeAmount, 0.1e18, 25_000_000e18);
  }

  // Remember each depositor and surrogate (as they're deployed) and ensure that there is
  // no overlap between them. This is to prevent the fuzzer from selecting a surrogate as a
  // depositor or vice versa.
  function _assumeSafeDepositorAndSurrogate(address _depositor, address _delegatee) internal {
    DelegationSurrogate _surrogate = baseStaker.surrogates(_delegatee);
    isKnownDepositor[_depositor] = true;
    isKnownSurrogate[_surrogate] = true;

    vm.assume(
      (!isKnownSurrogate[DelegationSurrogate(_depositor)])
        && (!isKnownDepositor[address(_surrogate)])
    );
  }

  function _setClaimFeeAndCollector(uint96 _amount, address _collector) internal {
    Staker.ClaimFeeParameters memory _params =
      Staker.ClaimFeeParameters({feeAmount: _amount, feeCollector: _collector});

    vm.prank(admin);
    baseStaker.setClaimFeeParameters(_params);
  }

  function _stake(address _depositor, uint256 _amount, address _delegatee)
    internal
    returns (Staker.DepositIdentifier _depositId)
  {
    vm.assume(_delegatee != address(0));

    vm.startPrank(_depositor);
    govToken.approve(address(baseStaker), _amount);
    _depositId = baseStaker.stake(_amount, _delegatee);
    vm.stopPrank();

    // Called after the stake so the surrogate will exist
    _assumeSafeDepositorAndSurrogate(_depositor, _delegatee);
  }

  function _stake(address _depositor, uint256 _amount, address _delegatee, address _claimer)
    internal
    returns (Staker.DepositIdentifier _depositId)
  {
    vm.assume(_delegatee != address(0) && _claimer != address(0));

    vm.startPrank(_depositor);
    govToken.approve(address(baseStaker), _amount);
    _depositId = baseStaker.stake(_amount, _delegatee, _claimer);
    vm.stopPrank();

    // Called after the stake so the surrogate will exist
    _assumeSafeDepositorAndSurrogate(_depositor, _delegatee);
  }

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
    ) = baseStaker.deposits(_depositId);
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
    _mintGovToken(_depositor, _boundedAmount);
    _depositId = _stake(_depositor, _boundedAmount, _delegatee);
  }

  function _boundMintAndStake(
    address _depositor,
    uint256 _amount,
    address _delegatee,
    address _claimer
  ) internal returns (uint256 _boundedAmount, Staker.DepositIdentifier _depositId) {
    _boundedAmount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _boundedAmount);
    _depositId = _stake(_depositor, _boundedAmount, _delegatee, _claimer);
  }

  // Scales first param and divides it by second
  function _scaledDiv(uint256 _x, uint256 _y) public view returns (uint256) {
    return (_x * SCALE_FACTOR) / _y;
  }
}

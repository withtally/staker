// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver} from "./interfaces/INotifiableRewardReceiver.sol";
import {IEarningPowerCalculator} from "./interfaces/IEarningPowerCalculator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract RewardDistributor is INotifiableRewardReceiver {
  using SafeCast for uint256;
  /// @notice A unique identifier assigned to each deposit.

  type DepositIdentifier is uint256;

  struct DelegateReward {
    uint96 earningPower;
    address claimer;
    address owner;
    uint256 rewardPerTokenCheckpoint;
    uint256 scaledUnclaimedRewardCheckpoint;
  }

  struct ClaimFeeParameters {
    uint96 feeAmount;
    address feeCollector;
  }

  /// @notice Thrown when an account attempts a call for which it lacks appropriate permission.
  /// @param reason Human readable code explaining why the call is unauthorized.
  /// @param caller The address that attempted the unauthorized call.
  error Staker__Unauthorized(bytes32 reason, address caller);

  /// @notice Thrown if the new rate after a reward notification would be zero.
  error Staker__InvalidRewardRate();

  /// @notice Thrown if a caller attempts to specify address zero for certain designated addresses.
  error Staker__InvalidAddress();

  /// @notice Thrown if the claim fee parameters are outside permitted bounds.
  error Staker__InvalidClaimFeeParameters();

  /// @notice Thrown if an earning power update is unqualified to be bumped.
  /// @param score The would-be new earning power which did not qualify.
  error Staker__Unqualified(uint256 score);

  /// @notice Thrown if the unclaimed rewards are insufficient to cover a bumper's requested tip,
  /// or in the case of an earning power decrease the tip of a subsequent earning power increase.
  error Staker__InsufficientUnclaimedRewards();

  /// @notice Thrown if a bumper's requested tip is invalid.
  error Staker__InvalidTip();

  /// @notice Emitted when the admin address is set.
  event AdminSet(address indexed oldAdmin, address indexed newAdmin);

  /// @notice Emitted when the earning power calculator address is set.
  event EarningPowerCalculatorSet(
    address indexed oldEarningPowerCalculator, address indexed newEarningPowerCalculator
  );

  /// @notice Emitted when the max bump tip is modified.
  event MaxBumpTipSet(uint256 oldMaxBumpTip, uint256 newMaxBumpTip);

  /// @notice Emitted when a reward notifier address is enabled or disabled.
  event RewardNotifierSet(address indexed account, bool isEnabled);

  /// @notice Emitted when the claim fee parameters are modified.
  event ClaimFeeParametersSet(
    uint96 oldFeeAmount, uint96 newFeeAmount, address oldFeeCollector, address newFeeCollector
  );

  /// @notice Emitted when a deposit's earning power is changed via bumping.
  event EarningPowerBumped(
    DepositIdentifier indexed depositId,
    uint256 oldEarningPower,
    uint256 newEarningPower,
    address bumper,
    address tipReceiver,
    uint256 tipAmount
  );

  /// @notice Emitted when a deposit's claimer is changed.
  event ClaimerAltered(
    DepositIdentifier indexed depositId,
    address indexed oldClaimer,
    address indexed newClaimer,
    uint256 earningPower
  );

  /// @notice Emitted when a claimer claims their earned reward.
  event RewardClaimed(
    DepositIdentifier indexed depositId,
    address indexed claimer,
    uint256 amount,
    uint256 earningPower
  );

  /// @notice ERC20 token in which rewards are denominated and distributed.
  IERC20 public immutable REWARD_TOKEN;

  /// @notice Delegable governance token which users stake to earn rewards.
  IERC20 public immutable STAKE_TOKEN;

  /// @notice Scale factor used in reward calculation math to reduce rounding errors caused by
  /// truncation during division.
  uint256 public constant SCALE_FACTOR = 1e36;

  /// @notice The maximum value to which the claim fee can be set.
  /// @dev For anything other than a zero value, this immutable parameter should be set in the
  /// constructor of a concrete implementation inheriting from Staker.
  uint256 public immutable MAX_CLAIM_FEE;

  /// @notice Permissioned actor that can enable/disable `rewardNotifier` addresses, set the max
  /// bump tip, set the claim fee parameters, and update the earning power calculator.
  address public admin;

  /// @notice Maximum tip a bumper can request.
  uint256 public maxBumpTip;

  /// @notice Global amount of earning power for all deposits.
  uint256 public totalEarningPower;

  /// @notice Contract that determines a deposit's earning power based on their delegatee.
  /// @dev An earning power calculator should take into account that a deposit's earning power is a
  /// uint96. There may be overflow issues within governance staker if this is not taken into
  /// account. Also, there should be some mechanism to prevent the deposit from frequently being
  /// bumpable: if earning power changes frequently, this will eat into a users unclaimed rewards.
  IEarningPowerCalculator public earningPowerCalculator;

  /// @notice Time at which rewards distribution will complete if there are no new rewards.
  uint256 public rewardEndTime;

  /// @notice Last time at which the global rewards accumulator was updated.
  uint256 public lastCheckpointTime;

  /// @notice Global rate at which rewards are currently being distributed to stakers,
  /// denominated in scaled reward tokens per second, using the SCALE_FACTOR.
  uint256 public scaledRewardRate;

  /// @notice Checkpoint value of the global reward per token accumulator.
  uint256 public rewardPerTokenAccumulatedCheckpoint;

  /// @notice Maps addresses to whether they are authorized to call `notifyRewardAmount`.
  mapping(address rewardNotifier => bool) public isRewardNotifier;

  /// @notice Current configuration parameters for the fee assessed on claiming.
  ClaimFeeParameters public claimFeeParameters;

  /// @notice Stores the metadata associated with a given delegate reward.
  mapping(DepositIdentifier depositId => DelegateReward deposit) public delegateRewards;

  /// @notice Tracks the total earning power by a depositor across all unique deposits.
  mapping(address depositor => uint256 earningPower) public depositorTotalEarningPower;

  /// @notice Set the admin address.
  /// @param _newAdmin Address of the new admin.
  /// @dev Caller must be the current admin.
  function setAdmin(address _newAdmin) external virtual {
    _revertIfNotAdmin();
    _setAdmin(_newAdmin);
  }

  /// @notice Set the earning power calculator address.
  function setEarningPowerCalculator(address _newEarningPowerCalculator) external virtual {
    _revertIfNotAdmin();
    _setEarningPowerCalculator(_newEarningPowerCalculator);
  }

  /// @notice Set the max bump tip.
  /// @param _newMaxBumpTip Value of the new max bump tip.
  /// @dev Caller must be the current admin.
  function setMaxBumpTip(uint256 _newMaxBumpTip) external virtual {
    _revertIfNotAdmin();
    _setMaxBumpTip(_newMaxBumpTip);
  }

  /// @notice Enables or disables a reward notifier address.
  /// @param _rewardNotifier Address of the reward notifier.
  /// @param _isEnabled `true` to enable the `_rewardNotifier`, or `false` to disable.
  /// @dev Caller must be the current admin.
  function setRewardNotifier(address _rewardNotifier, bool _isEnabled) external virtual {
    _revertIfNotAdmin();
    isRewardNotifier[_rewardNotifier] = _isEnabled;
    emit RewardNotifierSet(_rewardNotifier, _isEnabled);
  }

  /// @notice Updates the parameters related to the claim fee.
  /// @param _params The new fee parameters.
  /// @dev Caller must be current admin.
  function setClaimFeeParameters(ClaimFeeParameters memory _params) external virtual {
    _revertIfNotAdmin();
    _setClaimFeeParameters(_params);
  }

  /// @notice Timestamp representing the last time at which rewards have been distributed, which is
  /// either the current timestamp (because rewards are still actively being streamed) or the time
  /// at which the reward duration ended (because all rewards to date have already been streamed).
  /// @return Timestamp representing the last time at which rewards have been distributed.
  function lastTimeRewardDistributed() public view virtual returns (uint256) {
    if (rewardEndTime <= block.timestamp) return rewardEndTime;
    else return block.timestamp;
  }

  /// @notice Live value of the global reward per token accumulator. It is the sum of the last
  /// checkpoint value with the live calculation of the value that has accumulated in the interim.
  /// This number should monotonically increase over time as more rewards are distributed.
  /// @return Live value of the global reward per token accumulator.
  function rewardPerTokenAccumulated() public view virtual returns (uint256) {
    if (totalEarningPower == 0) return rewardPerTokenAccumulatedCheckpoint;

    return rewardPerTokenAccumulatedCheckpoint
      + (scaledRewardRate * (lastTimeRewardDistributed() - lastCheckpointTime)) / totalEarningPower;
  }

  /// @notice Live value of the unclaimed rewards earned by a given deposit. It is the
  /// sum of the last checkpoint value of the unclaimed rewards with the live calculation of the
  /// rewards that have accumulated for this account in the interim. This value can only increase,
  /// until it is reset to zero once the unearned rewards are claimed.
  ///
  /// Note that the contract tracks the unclaimed rewards internally with the scale factor
  /// included, in order to avoid the accrual of precision losses as users takes actions that
  /// cause rewards to be checkpointed. This external helper method is useful for integrations, and
  /// returns the value after it has been scaled down to the reward token's raw decimal amount.
  /// @param _depositId Identifier of the deposit in question.
  /// @return Live value of the unclaimed rewards earned by a given deposit.
  function unclaimedReward(DepositIdentifier _depositId) external view virtual returns (uint256) {
    return _scaledUnclaimedReward(delegateRewards[_depositId]) / SCALE_FACTOR; // TODO: Changed from
      // base
  }

  /// @notice For an existing deposit, change the claimer account which has the right to
  /// withdraw staking rewards.
  /// @param _depositId Unique identifier of the deposit which will have its claimer altered.
  /// @param _newClaimer Address of the new claimer.
  /// @dev The new claimer may not be the zero address. The message sender must be the owner of
  /// the deposit.
  function alterClaimer(DepositIdentifier _depositId, address _newClaimer) external virtual {
    DelegateReward storage deposit = delegateRewards[_depositId]; // Changed from base
    _revertIfNotDepositOwner(deposit, msg.sender);
    _alterClaimer(deposit, _depositId, _newClaimer);
  }

  /// @notice Claim reward tokens earned by a given deposit. Message sender must be the claimer
  /// address of the deposit or the owner of the deposit. Tokens are sent to the caller.
  /// @param _depositId Identifier of the deposit from which accrued rewards will be claimed.
  /// @return Amount of reward tokens claimed, after the fee has been assessed.
  function claimReward(DepositIdentifier _depositId) external virtual returns (uint256) {
    DelegateReward storage deposit = delegateRewards[_depositId];
    if (deposit.claimer != msg.sender && deposit.owner != msg.sender) {
      revert Staker__Unauthorized("not claimer or owner", msg.sender);
    }
    return _claimReward(_depositId, deposit, msg.sender);
  }

  /// @notice A function that a bumper can call to update a deposit's earning power when a
  /// qualifying change in the earning power is returned by the earning power calculator. A
  /// deposit's earning power may change as determined by the algorithm of the current earning power
  /// calculator. In order to incentivize bumpers to trigger these updates a portion of deposit's
  /// unclaimed rewards are sent to the bumper.
  /// @param _depositId The identifier for the deposit that needs an updated earning power.
  /// @param _tipReceiver The receiver of the reward for updating a deposit's earning power.
  /// @param _requestedTip The amount of tip requested by the third-party.
  function bumpEarningPower(
    DepositIdentifier _depositId,
    address _tipReceiver,
    uint256 _requestedTip
  ) external virtual {
    if (_requestedTip > maxBumpTip) revert Staker__InvalidTip();

    DelegateReward storage deposit = delegateRewards[_depositId];

    _checkpointGlobalReward();
    _checkpointReward(deposit);

    uint256 _unclaimedRewards = deposit.scaledUnclaimedRewardCheckpoint / SCALE_FACTOR;

    (uint256 _newEarningPower, bool _isQualifiedForBump) =
      earningPowerCalculator.getNewEarningPower(0, deposit.owner, address(0), deposit.earningPower);
    if (!_isQualifiedForBump || _newEarningPower == deposit.earningPower) {
      revert Staker__Unqualified(_newEarningPower);
    }

    if (_newEarningPower > deposit.earningPower && _unclaimedRewards < _requestedTip) {
      revert Staker__InsufficientUnclaimedRewards();
    }

    // Note: underflow causes a revert if the requested  tip is more than unclaimed rewards
    if (_newEarningPower < deposit.earningPower && (_unclaimedRewards - _requestedTip) < maxBumpTip)
    {
      revert Staker__InsufficientUnclaimedRewards();
    }

    emit EarningPowerBumped(
      _depositId, deposit.earningPower, _newEarningPower, msg.sender, _tipReceiver, _requestedTip
    );

    // Update global earning power & deposit earning power based on this bump
    totalEarningPower =
      _calculateTotalEarningPower(deposit.earningPower, _newEarningPower, totalEarningPower);
    depositorTotalEarningPower[deposit.owner] = _calculateTotalEarningPower(
      deposit.earningPower, _newEarningPower, depositorTotalEarningPower[deposit.owner]
    );
    deposit.earningPower = _newEarningPower.toUint96();

    // Send tip to the receiver
    SafeERC20.safeTransfer(REWARD_TOKEN, _tipReceiver, _requestedTip);
    deposit.scaledUnclaimedRewardCheckpoint =
      deposit.scaledUnclaimedRewardCheckpoint - (_requestedTip * SCALE_FACTOR);
  }

  function _scaledUnclaimedReward(DelegateReward storage deposit)
    internal
    view
    virtual
    returns (uint256)
  {
    return deposit.scaledUnclaimedRewardCheckpoint
      + (deposit.earningPower * (rewardPerTokenAccumulated() - deposit.rewardPerTokenCheckpoint));
  }

  /// @notice Internal helper method which sets the admin address.
  /// @param _newAdmin Address of the new admin.
  function _setAdmin(address _newAdmin) internal virtual {
    _revertIfAddressZero(_newAdmin);
    emit AdminSet(admin, _newAdmin);
    admin = _newAdmin;
  }

  /// @notice Internal helper method which sets the earning power calculator address.
  function _setEarningPowerCalculator(address _newEarningPowerCalculator) internal virtual {
    _revertIfAddressZero(_newEarningPowerCalculator);
    emit EarningPowerCalculatorSet(address(earningPowerCalculator), _newEarningPowerCalculator);
    earningPowerCalculator = IEarningPowerCalculator(_newEarningPowerCalculator);
  }

  /// @notice Internal helper method which sets the max bump tip.
  /// @param _newMaxTip Value of the new max bump tip.
  function _setMaxBumpTip(uint256 _newMaxTip) internal virtual {
    emit MaxBumpTipSet(maxBumpTip, _newMaxTip);
    maxBumpTip = _newMaxTip;
  }

  /// @notice Internal helper method which sets the claim fee parameters.
  /// @param _params The new fee parameters.
  function _setClaimFeeParameters(ClaimFeeParameters memory _params) internal virtual {
    if (
      _params.feeAmount > MAX_CLAIM_FEE
        || (_params.feeCollector == address(0) && _params.feeAmount > 0)
    ) revert Staker__InvalidClaimFeeParameters();

    emit ClaimFeeParametersSet(
      claimFeeParameters.feeAmount,
      _params.feeAmount,
      claimFeeParameters.feeCollector,
      _params.feeCollector
    );

    claimFeeParameters = _params;
  }

  /// @notice Internal convenience method which alters the claimer of an existing deposit.
  /// @dev This method must only be called after proper authorization has been completed.
  /// @dev See public alterClaimer methods for additional documentation.
  function _alterClaimer(
    DelegateReward storage deposit,
    DepositIdentifier _depositId,
    address _newClaimer
  ) internal virtual {
    _revertIfAddressZero(_newClaimer);
    _checkpointGlobalReward();
    _checkpointReward(deposit);

    // Updating the earning power here is not strictly necessary, but if the user is touching their
    // deposit anyway, it seems reasonable to make sure their earning power is up to date.
    uint256 _newEarningPower = earningPowerCalculator.getEarningPower(0, deposit.owner, address(0));
    totalEarningPower =
      _calculateTotalEarningPower(deposit.earningPower, _newEarningPower, totalEarningPower);
    depositorTotalEarningPower[deposit.owner] = _calculateTotalEarningPower(
      deposit.earningPower, _newEarningPower, depositorTotalEarningPower[deposit.owner]
    );

    deposit.earningPower = _newEarningPower.toUint96();

    emit ClaimerAltered(_depositId, deposit.claimer, _newClaimer, _newEarningPower);
    deposit.claimer = _newClaimer;
  }

  /// @notice Checkpoints the global reward per token accumulator.
  function _checkpointGlobalReward() internal virtual {
    rewardPerTokenAccumulatedCheckpoint = rewardPerTokenAccumulated();
    lastCheckpointTime = lastTimeRewardDistributed();
  }

  /// @notice Checkpoints the unclaimed rewards and reward per token accumulator of a given
  /// deposit.
  /// @param deposit The deposit for which the reward parameters will be checkpointed.
  /// @dev This is a sensitive internal helper method that must only be called after global rewards
  /// accumulator has been checkpointed. It assumes the global `rewardPerTokenCheckpoint` is up to
  /// date.
  function _checkpointReward(DelegateReward storage deposit) internal virtual {
    deposit.scaledUnclaimedRewardCheckpoint = _scaledUnclaimedReward(deposit);
    deposit.rewardPerTokenCheckpoint = rewardPerTokenAccumulatedCheckpoint;
  }

  /// @notice Internal helper method which calculates and returns an updated value for total
  /// earning power based on the old and new earning power of a deposit which is being changed.
  /// @param _depositOldEarningPower The earning power of the deposit before a change is applied.
  /// @param _depositNewEarningPower The earning power of the deposit after a change is applied.
  /// @return _newTotalEarningPower The new total earning power.
  function _calculateTotalEarningPower(
    uint256 _depositOldEarningPower,
    uint256 _depositNewEarningPower,
    uint256 _totalEarningPower
  ) internal pure returns (uint256 _newTotalEarningPower) {
    return _totalEarningPower + _depositNewEarningPower - _depositOldEarningPower;
  }

  /// @notice Internal convenience method which claims earned rewards.
  /// @return Amount of reward tokens claimed, after the claim fee has been assessed.
  /// @dev This method must only be called after proper authorization has been completed.
  /// @dev See public claimReward methods for additional documentation.
  function _claimReward(
    DepositIdentifier _depositId,
    DelegateReward storage deposit,
    address _claimer
  ) internal virtual returns (uint256) {
    _checkpointGlobalReward();
    _checkpointReward(deposit);

    uint256 _reward = deposit.scaledUnclaimedRewardCheckpoint / SCALE_FACTOR;
    // Intentionally reverts due to overflow if unclaimed rewards are less than fee.
    uint256 _payout = _reward - claimFeeParameters.feeAmount;
    if (_payout == 0) return 0;

    // retain sub-wei dust that would be left due to the precision loss
    deposit.scaledUnclaimedRewardCheckpoint =
      deposit.scaledUnclaimedRewardCheckpoint - (_reward * SCALE_FACTOR);

    uint256 _newEarningPower = earningPowerCalculator.getEarningPower(0, deposit.owner, address(0));

    emit RewardClaimed(_depositId, _claimer, _payout, _newEarningPower);

    totalEarningPower =
      _calculateTotalEarningPower(deposit.earningPower, _newEarningPower, totalEarningPower);
    depositorTotalEarningPower[deposit.owner] = _calculateTotalEarningPower(
      deposit.earningPower, _newEarningPower, depositorTotalEarningPower[deposit.owner]
    );
    deposit.earningPower = _newEarningPower.toUint96();

    SafeERC20.safeTransfer(REWARD_TOKEN, _claimer, _payout);
    if (claimFeeParameters.feeAmount > 0) {
      SafeERC20.safeTransfer(
        REWARD_TOKEN, claimFeeParameters.feeCollector, claimFeeParameters.feeAmount
      );
    }
    return _payout;
  }

  /// @notice Internal helper method which reverts Staker__Unauthorized if the message
  /// sender is not the admin.
  function _revertIfNotAdmin() internal view virtual {
    if (msg.sender != admin) revert Staker__Unauthorized("not admin", msg.sender);
  }

  /// @notice Internal helper method which reverts with Staker__InvalidAddress if the
  /// account in question is address zero.
  /// @param _account Account to verify.
  function _revertIfAddressZero(address _account) internal pure {
    if (_account == address(0)) revert Staker__InvalidAddress();
  }

  /// @notice Internal helper method which reverts Staker__Unauthorized if the alleged
  /// owner is not the true owner of the deposit.
  /// @param deposit Deposit to validate.
  /// @param _owner Alleged owner of deposit.
  function _revertIfNotDepositOwner(DelegateReward storage deposit, address _owner)
    internal
    view
    virtual
  {
    if (_owner != deposit.owner) revert Staker__Unauthorized("not owner", _owner);
  }

  // function bumpEarningPower(
  //     address _delegate,
  //     address _tipReceiver,
  //     uint256 _requestedTip
  // ) external;
}

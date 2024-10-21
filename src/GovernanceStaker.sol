// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {DelegationSurrogate} from "src/DelegationSurrogate.sol";
import {INotifiableRewardReceiver} from "src/interfaces/INotifiableRewardReceiver.sol";
import {IEarningPowerCalculator} from "src/interfaces/IEarningPowerCalculator.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Multicall} from "openzeppelin/utils/Multicall.sol";
import {Nonces} from "openzeppelin/utils/Nonces.sol";
import {SignatureChecker} from "openzeppelin/utils/cryptography/SignatureChecker.sol";
import {EIP712} from "openzeppelin/utils/cryptography/EIP712.sol";

/// @title GovernanceStaker
/// @author [ScopeLift](https://scopelift.co)
/// @notice This contract manages the distribution of rewards to stakers. Rewards are denominated
/// in an ERC20 token and sent to the contract by authorized reward notifiers. To stake means to
/// deposit a designated, delegable ERC20 governance token and leave it over a period of time.
/// The contract allows stakers to delegate the voting power of the tokens they stake to any
/// governance delegatee on a per deposit basis. The contract also allows stakers to designate the
/// beneficiary address that earns rewards for the associated deposit.
///
/// The staking mechanism of this contract is directly inspired by the Synthetix StakingRewards.sol
/// implementation. The core mechanic involves the streaming of rewards over a designated period
/// of time. Each staker earns rewards proportional to their share of the total stake, and each
/// staker earns only while their tokens are staked. Stakers may add or withdraw their stake at any
/// point. Beneficiaries can claim the rewards they've earned at any point. When a new reward is
/// received, the reward duration restarts, and the rate at which rewards are streamed is updated
/// to include the newly received rewards along with any remaining rewards that have finished
/// streaming since the last time a reward was received.
contract GovernanceStaker is INotifiableRewardReceiver, Multicall, EIP712, Nonces {
  type DepositIdentifier is uint256;

  /// @notice Emitted when stake is deposited by a depositor, either to a new deposit or one that
  /// already exists.
  event StakeDeposited(
    address owner, DepositIdentifier indexed depositId, uint256 amount, uint256 depositBalance
  );

  /// @notice Emitted when a depositor withdraws some portion of stake from a given deposit.
  event StakeWithdrawn(DepositIdentifier indexed depositId, uint256 amount, uint256 depositBalance);

  /// @notice Emitted when a deposit's delegatee is changed.
  event DelegateeAltered(
    DepositIdentifier indexed depositId, address oldDelegatee, address newDelegatee
  );

  /// @notice Emitted when a deposit's beneficiary is changed.
  event BeneficiaryAltered(
    DepositIdentifier indexed depositId,
    address indexed oldBeneficiary,
    address indexed newBeneficiary
  );

  /// @notice Emitted when a beneficiary claims their earned reward.
  event RewardClaimed(
    DepositIdentifier indexed depositId, address indexed beneficiary, uint256 amount
  );

  /// @notice Emitted when this contract is notified of a new reward.
  event RewardNotified(uint256 amount, address notifier);

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

  /// @notice Emitted when a surrogate contract is deployed.
  event SurrogateDeployed(address indexed delegatee, address indexed surrogate);

  /// @notice Thrown when an account attempts a call for which it lacks appropriate permission.
  /// @param reason Human readable code explaining why the call is unauthorized.
  /// @param caller The address that attempted the unauthorized call.
  error GovernanceStaker__Unauthorized(bytes32 reason, address caller);

  /// @notice Thrown if the new rate after a reward notification would be zero.
  error GovernanceStaker__InvalidRewardRate();

  /// @notice Thrown if the following invariant is broken after a new reward: the contract should
  /// always have a reward balance sufficient to distribute at the reward rate across the reward
  /// duration.
  error GovernanceStaker__InsufficientRewardBalance();

  /// @notice Thrown if the unclaimed rewards are insufficient to cover a bumpers requested tip or
  /// in the case of an earning power decrease the tip of a subsequent earning power increase.
  error GovernanceStaker__InsufficientUnclaimedRewards();

  /// @notice Thrown if a caller attempts to specify address zero for certain designated addresses.
  error GovernanceStaker__InvalidAddress();

  /// @notice Thrown if a bumper's requested tip is invalid.
  error GovernanceStaker__InvalidTip();

  /// @notice Thrown when an onBehalf method is called with a deadline that has expired.
  error GovernanceStaker__ExpiredDeadline();

  /// @notice Thrown if a caller supplies an invalid signature to a method that requires one.
  error GovernanceStaker__InvalidSignature();

  /// @notice Thrown if an earning power update is unqualified to be bumped.
  error GovernanceStaker__Unqualified();

  /// @notice Metadata associated with a discrete staking deposit.
  /// @param balance The deposit's staked balance.
  /// @param owner The owner of this deposit.
  /// @param delegatee The governance delegate who receives the voting weight for this deposit.
  /// @param beneficiary The address which has the right to withdraw rewards earned by this
  /// deposit.
  /// @param earningPower The "power" this deposit has as it pertains to earning rewards, which
  /// accrue to this deposit at a rate proportional to its share of the total earning power of the
  /// system.
  /// @param rewardPerTokenCheckpoint Checkpoint of the reward per token accumulator for this
  /// deposit. It represents the value of the global accumulator at the last time a given deposit's
  /// rewards were calculated and stored. The difference between the global value and this value
  /// can be used to calculate the interim rewards earned by given deposit.
  /// @param scaledUnclaimedRewardCheckpoint Checkpoint of the unclaimed rewards earned by a given
  /// deposit with the scale factor included. This value is stored any time an action is taken that
  /// specifically impacts the rate at which rewards are earned by a given deposit. Total unclaimed
  /// rewards for a deposit are thus this value plus all rewards earned after this checkpoint was
  /// taken. This value is reset to zero when the deposit's rewards are claimed.
  struct Deposit {
    uint96 balance;
    address owner;
    uint96 earningPower;
    address delegatee;
    address beneficiary;
    uint256 rewardPerTokenCheckpoint;
    uint256 scaledUnclaimedRewardCheckpoint;
  }

  /// @notice Type hash used when encoding data for `stakeOnBehalf` calls.
  bytes32 public constant STAKE_TYPEHASH = keccak256(
    "Stake(uint256 amount,address delegatee,address beneficiary,address depositor,uint256 nonce,uint256 deadline)"
  );
  /// @notice Type hash used when encoding data for `stakeMoreOnBehalf` calls.
  bytes32 public constant STAKE_MORE_TYPEHASH = keccak256(
    "StakeMore(uint256 depositId,uint256 amount,address depositor,uint256 nonce,uint256 deadline)"
  );
  /// @notice Type hash used when encoding data for `alterDelegateeOnBehalf` calls.
  bytes32 public constant ALTER_DELEGATEE_TYPEHASH = keccak256(
    "AlterDelegatee(uint256 depositId,address newDelegatee,address depositor,uint256 nonce,uint256 deadline)"
  );
  /// @notice Type hash used when encoding data for `alterBeneficiaryOnBehalf` calls.
  bytes32 public constant ALTER_BENEFICIARY_TYPEHASH = keccak256(
    "AlterBeneficiary(uint256 depositId,address newBeneficiary,address depositor,uint256 nonce,uint256 deadline)"
  );
  /// @notice Type hash used when encoding data for `withdrawOnBehalf` calls.
  bytes32 public constant WITHDRAW_TYPEHASH = keccak256(
    "Withdraw(uint256 depositId,uint256 amount,address depositor,uint256 nonce,uint256 deadline)"
  );
  /// @notice Type hash used when encoding data for `claimRewardOnBehalf` calls.
  bytes32 public constant CLAIM_REWARD_TYPEHASH =
    keccak256("ClaimReward(uint256 depositId,uint256 nonce,uint256 deadline)");

  /// @notice ERC20 token in which rewards are denominated and distributed.
  IERC20 public immutable REWARD_TOKEN;

  /// @notice Delegable governance token which users stake to earn rewards.
  IERC20Delegates public immutable STAKE_TOKEN;

  /// @notice Length of time over which rewards sent to this contract are distributed to stakers.
  uint256 public constant REWARD_DURATION = 30 days;

  /// @notice Scale factor used in reward calculation math to reduce rounding errors caused by
  /// truncation during division.
  uint256 public constant SCALE_FACTOR = 1e36;

  /// @dev Unique identifier that will be used for the next deposit.
  DepositIdentifier private nextDepositId;

  /// @notice Permissioned actor that can enable/disable `rewardNotifier` addresses.
  address public admin;

  /// @notice Maximum tip a bumper can request.
  uint256 public maxBumpTip;

  /// @notice Global amount currently staked across all deposits.
  uint256 public totalStaked;

  /// @notice Global amount of earning power for all deposits.
  uint256 public totalEarningPower;

  /// @notice Contract that determines a deposit's earning power based on their delegatee.
  IEarningPowerCalculator public earningPowerCalculator;

  /// @notice Tracks the total staked by a depositor across all unique deposits.
  mapping(address depositor => uint256 amount) public depositorTotalStaked;

  /// @notice Stores the metadata associated with a given deposit.
  mapping(DepositIdentifier depositId => Deposit deposit) public deposits;

  /// @notice Maps the account of each governance delegate with the surrogate contract which holds
  /// the staked tokens from deposits which assign voting weight to said delegate.
  mapping(address delegatee => DelegationSurrogate surrogate) public surrogates;

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

  /// @param _rewardToken ERC20 token in which rewards will be denominated.
  /// @param _stakeToken Delegable governance token which users will stake to earn rewards.
  /// @param _earningPowerCalculator The contract that will serve as the initial calculator of
  /// earning power for the staker system.
  /// @param _admin Address which will have permission to manage rewardNotifiers.
  constructor(
    IERC20 _rewardToken,
    IERC20Delegates _stakeToken,
    IEarningPowerCalculator _earningPowerCalculator,
    uint256 _maxBumpTip,
    address _admin,
    string memory _name
  ) EIP712(_name, "1") {
    REWARD_TOKEN = _rewardToken;
    STAKE_TOKEN = _stakeToken;
    _setAdmin(_admin);
    _setMaxBumpTip(_maxBumpTip);
    _setEarningPowerCalculator(address(_earningPowerCalculator));
  }

  function DOMAIN_SEPERATOR() external view returns (bytes32) {
    return _domainSeparatorV4();
  }

  /// @notice Set the admin address.
  /// @param _newAdmin Address of the new admin.
  /// @dev Caller must be the current admin.
  function setAdmin(address _newAdmin) external {
    _revertIfNotAdmin();
    _setAdmin(_newAdmin);
  }

  /// @notice Set the earning power calculator address.
  function setEarningPowerCalculator(address _newEarningPowerCalculator) external {
    _revertIfNotAdmin();
    _setEarningPowerCalculator(_newEarningPowerCalculator);
  }

  /// @notice Set the max bump tip.
  /// @param _newMaxBumpTip Value of the new max bump tip.
  /// @dev Caller must be the current admin.
  function setMaxBumpTip(uint256 _newMaxBumpTip) external {
    _revertIfNotAdmin();
    _setMaxBumpTip(_newMaxBumpTip);
  }

  /// @notice Enables or disables a reward notifier address.
  /// @param _rewardNotifier Address of the reward notifier.
  /// @param _isEnabled `true` to enable the `_rewardNotifier`, or `false` to disable.
  /// @dev Caller must be the current admin.
  function setRewardNotifier(address _rewardNotifier, bool _isEnabled) external {
    _revertIfNotAdmin();
    isRewardNotifier[_rewardNotifier] = _isEnabled;
    emit RewardNotifierSet(_rewardNotifier, _isEnabled);
  }

  /// @notice Timestamp representing the last time at which rewards have been distributed, which is
  /// either the current timestamp (because rewards are still actively being streamed) or the time
  /// at which the reward duration ended (because all rewards to date have already been streamed).
  /// @return Timestamp representing the last time at which rewards have been distributed.
  function lastTimeRewardDistributed() public view returns (uint256) {
    if (rewardEndTime <= block.timestamp) return rewardEndTime;
    else return block.timestamp;
  }

  /// @notice Live value of the global reward per token accumulator. It is the sum of the last
  /// checkpoint value with the live calculation of the value that has accumulated in the interim.
  /// This number should monotonically increase over time as more rewards are distributed.
  /// @return Live value of the global reward per token accumulator.
  function rewardPerTokenAccumulated() public view returns (uint256) {
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
  function unclaimedReward(DepositIdentifier _depositId) external view returns (uint256) {
    return _scaledUnclaimedReward(deposits[_depositId]) / SCALE_FACTOR;
  }

  /// @notice Stake tokens to a new deposit. The caller must pre-approve the staking contract to
  /// spend at least the would-be staked amount of the token.
  /// @param _amount The amount of the staking token to stake.
  /// @param _delegatee The address to assign the governance voting weight of the staked tokens.
  /// @return _depositId The unique identifier for this deposit.
  /// @dev The delegatee may not be the zero address. The deposit will be owned by the message
  /// sender, and the beneficiary will also be the message sender.
  function stake(uint96 _amount, address _delegatee)
    external
    returns (DepositIdentifier _depositId)
  {
    _depositId = _stake(msg.sender, _amount, _delegatee, msg.sender);
  }

  /// @notice Method to stake tokens to a new deposit. The caller must pre-approve the staking
  /// contract to spend at least the would-be staked amount of the token.
  /// @param _amount Quantity of the staking token to stake.
  /// @param _delegatee Address to assign the governance voting weight of the staked tokens.
  /// @param _beneficiary Address that will accrue rewards for this stake.
  /// @return _depositId Unique identifier for this deposit.
  /// @dev Neither the delegatee nor the beneficiary may be the zero address. The deposit will be
  /// owned by the message sender.
  function stake(uint96 _amount, address _delegatee, address _beneficiary)
    external
    returns (DepositIdentifier _depositId)
  {
    _depositId = _stake(msg.sender, _amount, _delegatee, _beneficiary);
  }

  /// @notice Method to stake tokens to a new deposit. Before the staking operation occurs, a
  /// signature is passed to the token contract's permit method to spend the would-be staked amount
  /// of the token.
  /// @param _amount Quantity of the staking token to stake.
  /// @param _delegatee Address to assign the governance voting weight of the staked tokens.
  /// @param _beneficiary Address that will accrue rewards for this stake.
  /// @param _deadline The timestamp after which the permit signature should expire.
  /// @param _v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param _r ECDSA signature component: x-coordinate of `R`
  /// @param _s ECDSA signature component: `s` value of the signature
  /// @return _depositId Unique identifier for this deposit.
  /// @dev Neither the delegatee nor the beneficiary may be the zero address. The deposit will be
  /// owned by the message sender.
  function permitAndStake(
    uint96 _amount,
    address _delegatee,
    address _beneficiary,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external returns (DepositIdentifier _depositId) {
    try STAKE_TOKEN.permit(msg.sender, address(this), _amount, _deadline, _v, _r, _s) {} catch {}
    _depositId = _stake(msg.sender, _amount, _delegatee, _beneficiary);
  }

  /// @notice Stake tokens to a new deposit on behalf of a user, using a signature to validate the
  /// user's intent. The caller must pre-approve the staking contract to spend at least the
  /// would-be staked amount of the token.
  /// @param _amount Quantity of the staking token to stake.
  /// @param _delegatee Address to assign the governance voting weight of the staked tokens.
  /// @param _beneficiary Address that will accrue rewards for this stake.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _deadline The timestamp after which the signature should expire.
  /// @param _signature Signature of the user authorizing this stake.
  /// @return _depositId Unique identifier for this deposit.
  /// @dev Neither the delegatee nor the beneficiary may be the zero address.
  function stakeOnBehalf(
    uint96 _amount,
    address _delegatee,
    address _beneficiary,
    address _depositor,
    uint256 _deadline,
    bytes memory _signature
  ) external returns (DepositIdentifier _depositId) {
    _revertIfPastDeadline(_deadline);
    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            STAKE_TYPEHASH,
            _amount,
            _delegatee,
            _beneficiary,
            _depositor,
            _useNonce(_depositor),
            _deadline
          )
        )
      ),
      _signature
    );
    _depositId = _stake(_depositor, _amount, _delegatee, _beneficiary);
  }

  /// @notice Add more staking tokens to an existing deposit. A staker should call this method when
  /// they have an existing deposit, and wish to stake more while retaining the same delegatee and
  /// beneficiary.
  /// @param _depositId Unique identifier of the deposit to which stake will be added.
  /// @param _amount Quantity of stake to be added.
  /// @dev The message sender must be the owner of the deposit.
  function stakeMore(DepositIdentifier _depositId, uint96 _amount) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, msg.sender);
    _stakeMore(deposit, _depositId, _amount);
  }

  /// @notice Add more staking tokens to an existing deposit. A staker should call this method when
  /// they have an existing deposit, and wish to stake more while retaining the same delegatee and
  /// beneficiary. Before the staking operation occurs, a signature is passed to the token
  /// contract's permit method to spend the would-be staked amount of the token.
  /// @param _depositId Unique identifier of the deposit to which stake will be added.
  /// @param _amount Quantity of stake to be added.
  /// @param _deadline The timestamp after which the permit signature should expire.
  /// @param _v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param _r ECDSA signature component: x-coordinate of `R`
  /// @param _s ECDSA signature component: `s` value of the signature
  /// @dev The message sender must be the owner of the deposit.
  function permitAndStakeMore(
    DepositIdentifier _depositId,
    uint96 _amount,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, msg.sender);

    try STAKE_TOKEN.permit(msg.sender, address(this), _amount, _deadline, _v, _r, _s) {} catch {}
    _stakeMore(deposit, _depositId, _amount);
  }

  /// @notice Add more staking tokens to an existing deposit on behalf of a user, using a signature
  /// to validate the user's intent. A staker should call this method when they have an existing
  /// deposit, and wish to stake more while retaining the same delegatee and beneficiary.
  /// @param _depositId Unique identifier of the deposit to which stake will be added.
  /// @param _amount Quantity of stake to be added.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _deadline The timestamp after which the signature should expire.
  /// @param _signature Signature of the user authorizing this stake.
  function stakeMoreOnBehalf(
    DepositIdentifier _depositId,
    uint96 _amount,
    address _depositor,
    uint256 _deadline,
    bytes memory _signature
  ) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, _depositor);
    _revertIfPastDeadline(_deadline);
    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            STAKE_MORE_TYPEHASH, _depositId, _amount, _depositor, _useNonce(_depositor), _deadline
          )
        )
      ),
      _signature
    );

    _stakeMore(deposit, _depositId, _amount);
  }

  /// @notice For an existing deposit, change the address to which governance voting power is
  /// assigned.
  /// @param _depositId Unique identifier of the deposit which will have its delegatee altered.
  /// @param _newDelegatee Address of the new governance delegate.
  /// @dev The new delegatee may not be the zero address. The message sender must be the owner of
  /// the deposit.
  function alterDelegatee(DepositIdentifier _depositId, address _newDelegatee) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, msg.sender);
    _alterDelegatee(deposit, _depositId, _newDelegatee);
  }

  /// @notice For an existing deposit, change the address to which governance voting power is
  /// assigned on behalf of a user, using a signature to validate the user's intent.
  /// @param _depositId Unique identifier of the deposit which will have its delegatee altered.
  /// @param _newDelegatee Address of the new governance delegate.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _deadline The timestamp after which the signature should expire.
  /// @param _signature Signature of the user authorizing this stake.
  /// @dev The new delegatee may not be the zero address.
  function alterDelegateeOnBehalf(
    DepositIdentifier _depositId,
    address _newDelegatee,
    address _depositor,
    uint256 _deadline,
    bytes memory _signature
  ) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, _depositor);
    _revertIfPastDeadline(_deadline);
    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            ALTER_DELEGATEE_TYPEHASH,
            _depositId,
            _newDelegatee,
            _depositor,
            _useNonce(_depositor),
            _deadline
          )
        )
      ),
      _signature
    );

    _alterDelegatee(deposit, _depositId, _newDelegatee);
  }

  /// @notice For an existing deposit, change the beneficiary account which has the right to
  /// withdraw staking rewards.
  /// @param _depositId Unique identifier of the deposit which will have its beneficiary altered.
  /// @param _newBeneficiary Address of the new beneficiary.
  /// @dev The new beneficiary may not be the zero address. The message sender must be the owner of
  /// the deposit.
  function alterBeneficiary(DepositIdentifier _depositId, address _newBeneficiary) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, msg.sender);
    _alterBeneficiary(deposit, _depositId, _newBeneficiary);
  }

  /// @notice For an existing deposit, change the beneficiary account which has the right to
  /// withdraw staking rewards accruing on behalf of a user, using a signature to validate the
  /// user's intent.
  /// @param _depositId Unique identifier of the deposit which will have its beneficiary altered.
  /// @param _newBeneficiary Address of the new beneficiary.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _deadline The timestamp after which the signature should expire.
  /// @param _signature Signature of the user authorizing this stake.
  /// @dev The new beneficiary may not be the zero address.
  function alterBeneficiaryOnBehalf(
    DepositIdentifier _depositId,
    address _newBeneficiary,
    address _depositor,
    uint256 _deadline,
    bytes memory _signature
  ) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, _depositor);
    _revertIfPastDeadline(_deadline);
    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            ALTER_BENEFICIARY_TYPEHASH,
            _depositId,
            _newBeneficiary,
            _depositor,
            _useNonce(_depositor),
            _deadline
          )
        )
      ),
      _signature
    );

    _alterBeneficiary(deposit, _depositId, _newBeneficiary);
  }

  /// @notice Withdraw staked tokens from an existing deposit.
  /// @param _depositId Unique identifier of the deposit from which stake will be withdrawn.
  /// @param _amount Quantity of staked token to withdraw.
  /// @dev The message sender must be the owner of the deposit. Stake is withdrawn to the message
  /// sender's account.
  function withdraw(DepositIdentifier _depositId, uint96 _amount) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, msg.sender);
    _withdraw(deposit, _depositId, _amount);
  }

  /// @notice Withdraw staked tokens from an existing deposit on behalf of a user, using a
  /// signature to validate the user's intent.
  /// @param _depositId Unique identifier of the deposit from which stake will be withdrawn.
  /// @param _amount Quantity of staked token to withdraw.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _deadline The timestamp after which the signature should expire.
  /// @param _signature Signature of the user authorizing this stake.
  /// @dev Stake is withdrawn to the deposit owner's account.
  function withdrawOnBehalf(
    DepositIdentifier _depositId,
    uint96 _amount,
    address _depositor,
    uint256 _deadline,
    bytes memory _signature
  ) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, _depositor);
    _revertIfPastDeadline(_deadline);
    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            WITHDRAW_TYPEHASH, _depositId, _amount, _depositor, _useNonce(_depositor), _deadline
          )
        )
      ),
      _signature
    );

    _withdraw(deposit, _depositId, _amount);
  }

  /// @notice Claim reward tokens earned by a given deposit. Message sender must be the beneficiary
  /// address of the deposit. Tokens are sent to the beneficiary address.
  /// @param _depositId Identifier of the deposit from which accrued rewards will be claimed.
  /// @return Amount of reward tokens claimed.
  function claimReward(DepositIdentifier _depositId) external returns (uint256) {
    Deposit storage deposit = deposits[_depositId];
    if (deposit.beneficiary != msg.sender && deposit.owner != msg.sender) {
      revert GovernanceStaker__Unauthorized("not beneficiary or owner", msg.sender);
    }
    return _claimReward(_depositId, deposit, msg.sender);
  }

  /// @notice Claim reward tokens earned by a given deposit, using a signature to validate the
  /// caller's intent. The signer must be the beneficiary address of the deposit Tokens are sent to
  /// the beneficiary.
  /// @param _depositId The identifier for the deposit for which to claim rewards.
  /// @param _deadline The timestamp after which the signature should expire.
  /// @param _signature Signature of the beneficiary authorizing this reward claim.
  /// @return Amount of reward tokens claimed.
  function claimRewardOnBehalf(
    DepositIdentifier _depositId,
    uint256 _deadline,
    bytes memory _signature
  ) external returns (uint256) {
    _revertIfPastDeadline(_deadline);
    Deposit storage deposit = deposits[_depositId];
    bytes32 _beneficiaryHash = _hashTypedDataV4(
      keccak256(
        abi.encode(CLAIM_REWARD_TYPEHASH, _depositId, _useNonce(deposit.beneficiary), _deadline)
      )
    );
    bool _isValidBeneficiaryClaim =
      SignatureChecker.isValidSignatureNow(deposit.beneficiary, _beneficiaryHash, _signature);
    if (_isValidBeneficiaryClaim) return _claimReward(_depositId, deposit, deposit.beneficiary);

    bytes32 _ownerHash = _hashTypedDataV4(
      keccak256(abi.encode(CLAIM_REWARD_TYPEHASH, _depositId, _useNonce(deposit.owner), _deadline))
    );
    bool _isValidOwnerClaim =
      SignatureChecker.isValidSignatureNow(deposit.owner, _ownerHash, _signature);
    if (!_isValidOwnerClaim) revert GovernanceStaker__InvalidSignature();
    return _claimReward(_depositId, deposit, deposit.owner);
  }

  /// @notice Called by an authorized rewards notifier to alert the staking contract that a new
  /// reward has been transferred to it. It is assumed that the reward has already been
  /// transferred to this staking contract before the rewards notifier calls this method.
  /// @param _amount Quantity of reward tokens the staking contract is being notified of.
  /// @dev It is critical that only well behaved contracts are approved by the admin to call this
  /// method, for two reasons.
  ///
  /// 1. A misbehaving contract could grief stakers by frequently notifying this contract of tiny
  ///    rewards, thereby continuously stretching out the time duration over which real rewards are
  ///    distributed. It is required that reward notifiers supply reasonable rewards at reasonable
  ///    intervals.
  //  2. A misbehaving contract could falsely notify this contract of rewards that were not actually
  ///    distributed, creating a shortfall for those claiming their rewards after others. It is
  ///    required that a notifier contract always transfers the `_amount` to this contract before
  ///    calling this method.
  function notifyRewardAmount(uint256 _amount) external {
    if (!isRewardNotifier[msg.sender]) {
      revert GovernanceStaker__Unauthorized("not notifier", msg.sender);
    }

    // We checkpoint the accumulator without updating the timestamp at which it was updated,
    // because that second operation will be done after updating the reward rate.
    rewardPerTokenAccumulatedCheckpoint = rewardPerTokenAccumulated();

    if (block.timestamp >= rewardEndTime) {
      scaledRewardRate = (_amount * SCALE_FACTOR) / REWARD_DURATION;
    } else {
      uint256 _remainingReward = scaledRewardRate * (rewardEndTime - block.timestamp);
      scaledRewardRate = (_remainingReward + _amount * SCALE_FACTOR) / REWARD_DURATION;
    }

    rewardEndTime = block.timestamp + REWARD_DURATION;
    lastCheckpointTime = block.timestamp;

    if ((scaledRewardRate / SCALE_FACTOR) == 0) revert GovernanceStaker__InvalidRewardRate();

    // This check cannot _guarantee_ sufficient rewards have been transferred to the contract,
    // because it cannot isolate the unclaimed rewards owed to stakers left in the balance. While
    // this check is useful for preventing degenerate cases, it is not sufficient. Therefore, it is
    // critical that only safe reward notifier contracts are approved to call this method by the
    // admin.
    if (
      (scaledRewardRate * REWARD_DURATION) > (REWARD_TOKEN.balanceOf(address(this)) * SCALE_FACTOR)
    ) revert GovernanceStaker__InsufficientRewardBalance();

    emit RewardNotified(_amount, msg.sender);
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
  ) external {
    if (_requestedTip > maxBumpTip) revert GovernanceStaker__InvalidTip();

    Deposit storage deposit = deposits[_depositId];

    _checkpointGlobalReward();
    _checkpointReward(deposit);

    uint256 _unclaimedRewards = deposit.scaledUnclaimedRewardCheckpoint / SCALE_FACTOR;

    (uint256 _newEarningPower, bool _isQualifiedForBump) = earningPowerCalculator.getNewEarningPower(
      deposit.balance, deposit.owner, deposit.delegatee, deposit.earningPower
    );
    if (!_isQualifiedForBump || _newEarningPower == deposit.earningPower) {
      revert GovernanceStaker__Unqualified();
    }

    if (_newEarningPower > deposit.earningPower && _unclaimedRewards < _requestedTip) {
      revert GovernanceStaker__InsufficientUnclaimedRewards();
    }

    // Note: underflow causes a revert if the requested  tip is more than unclaimed rewards
    if (_newEarningPower < deposit.earningPower && (_unclaimedRewards - _requestedTip) < maxBumpTip)
    {
      revert GovernanceStaker__InsufficientUnclaimedRewards();
    }

    // Update global earning power & deposit earning power based on this bump
    totalEarningPower = _calculateTotalEarningPower(deposit.earningPower, _newEarningPower);
    deposit.earningPower = uint96(_newEarningPower);

    // Send tip to the receiver
    SafeERC20.safeTransfer(REWARD_TOKEN, _tipReceiver, _requestedTip);
  }

  /// @notice Live value of the unclaimed rewards earned by a given deposit with the
  /// scale factor included. Used internally for calculating reward checkpoints while minimizing
  /// precision loss.
  /// @return Live value of the unclaimed rewards earned by a given deposit with the
  /// scale factor included.
  /// @dev See documentation for the public, non-scaled `unclaimedReward` method for more details.
  function _scaledUnclaimedReward(Deposit storage deposit) internal view returns (uint256) {
    return deposit.scaledUnclaimedRewardCheckpoint
      + (deposit.earningPower * (rewardPerTokenAccumulated() - deposit.rewardPerTokenCheckpoint));
  }

  /// @notice Allows an address to increment their nonce and therefore invalidate any pending signed
  /// actions.
  function invalidateNonce() external {
    _useNonce(msg.sender);
  }

  /// @notice Internal method which finds the existing surrogate contract—or deploys a new one if
  /// none exists—for a given delegatee.
  /// @param _delegatee Account for which a surrogate is sought.
  /// @return _surrogate The address of the surrogate contract for the delegatee.
  function _fetchOrDeploySurrogate(address _delegatee)
    internal
    returns (DelegationSurrogate _surrogate)
  {
    _surrogate = surrogates[_delegatee];

    if (address(_surrogate) == address(0)) {
      _surrogate = new DelegationSurrogate(STAKE_TOKEN, _delegatee);
      surrogates[_delegatee] = _surrogate;
      emit SurrogateDeployed(_delegatee, address(_surrogate));
    }
  }

  /// @notice Internal convenience method which calls the `transferFrom` method on the stake token
  /// contract and reverts on failure.
  /// @param _from Source account from which stake token is to be transferred.
  /// @param _to Destination account of the stake token which is to be transferred.
  /// @param _value Quantity of stake token which is to be transferred.
  function _stakeTokenSafeTransferFrom(address _from, address _to, uint256 _value) internal {
    SafeERC20.safeTransferFrom(IERC20(address(STAKE_TOKEN)), _from, _to, _value);
  }

  /// @notice Internal method which generates and returns a unique, previously unused deposit
  /// identifier.
  /// @return _depositId Previously unused deposit identifier.
  function _useDepositId() internal returns (DepositIdentifier _depositId) {
    _depositId = nextDepositId;
    nextDepositId = DepositIdentifier.wrap(DepositIdentifier.unwrap(_depositId) + 1);
  }

  /// @notice Internal convenience methods which performs the staking operations.
  /// @dev This method must only be called after proper authorization has been completed.
  /// @dev See public stake methods for additional documentation.
  function _stake(address _depositor, uint96 _amount, address _delegatee, address _beneficiary)
    internal
    returns (DepositIdentifier _depositId)
  {
    _revertIfAddressZero(_delegatee);
    _revertIfAddressZero(_beneficiary);

    _checkpointGlobalReward();

    DelegationSurrogate _surrogate = _fetchOrDeploySurrogate(_delegatee);
    _depositId = _useDepositId();

    uint96 _earningPower = uint96(earningPowerCalculator.getEarningPower(_amount, _depositor, _delegatee));
    totalStaked += _amount;
    totalEarningPower += _earningPower;
    depositorTotalStaked[_depositor] += _amount;
    deposits[_depositId] = Deposit({
      balance: _amount,
      owner: _depositor,
      delegatee: _delegatee,
      beneficiary: _beneficiary,
      earningPower: _earningPower,
      rewardPerTokenCheckpoint: rewardPerTokenAccumulatedCheckpoint,
      scaledUnclaimedRewardCheckpoint: 0
    });
    _stakeTokenSafeTransferFrom(_depositor, address(_surrogate), _amount);
    emit StakeDeposited(_depositor, _depositId, _amount, _amount);
    emit BeneficiaryAltered(_depositId, address(0), _beneficiary);
    emit DelegateeAltered(_depositId, address(0), _delegatee);
  }

  /// @notice Internal convenience method which adds more stake to an existing deposit.
  /// @dev This method must only be called after proper authorization has been completed.
  /// @dev See public stakeMore methods for additional documentation.
  function _stakeMore(Deposit storage deposit, DepositIdentifier _depositId, uint96 _amount)
    internal
  {
    _checkpointGlobalReward();
    _checkpointReward(deposit);

    DelegationSurrogate _surrogate = surrogates[deposit.delegatee];

    uint96 _newBalance = deposit.balance + _amount;
    uint96 _newEarningPower =
      uint96(earningPowerCalculator.getEarningPower(_newBalance, deposit.owner, deposit.delegatee));
    totalEarningPower = _calculateTotalEarningPower(deposit.earningPower, _newEarningPower);
    totalStaked += _amount;
    depositorTotalStaked[deposit.owner] += _amount;
    deposit.earningPower = _newEarningPower;
    deposit.balance = _newBalance;
    _stakeTokenSafeTransferFrom(deposit.owner, address(_surrogate), _amount);
    emit StakeDeposited(deposit.owner, _depositId, _amount, deposit.balance);
  }

  /// @notice Internal convenience method which alters the delegatee of an existing deposit.
  /// @dev This method must only be called after proper authorization has been completed.
  /// @dev See public alterDelegatee methods for additional documentation.
  function _alterDelegatee(
    Deposit storage deposit,
    DepositIdentifier _depositId,
    address _newDelegatee
  ) internal {
    _revertIfAddressZero(_newDelegatee);
    DelegationSurrogate _oldSurrogate = surrogates[deposit.delegatee];
    uint96 _newEarningPower =
      uint96(earningPowerCalculator.getEarningPower(deposit.balance, deposit.owner, _newDelegatee));
    totalEarningPower = _calculateTotalEarningPower(deposit.earningPower, _newEarningPower);
    emit DelegateeAltered(_depositId, deposit.delegatee, _newDelegatee);
    deposit.delegatee = _newDelegatee;
    deposit.earningPower = _newEarningPower;
    DelegationSurrogate _newSurrogate = _fetchOrDeploySurrogate(_newDelegatee);
    _stakeTokenSafeTransferFrom(address(_oldSurrogate), address(_newSurrogate), deposit.balance);
  }

  /// @notice Internal convenience method which alters the beneficiary of an existing deposit.
  /// @dev This method must only be called after proper authorization has been completed.
  /// @dev See public alterBeneficiary methods for additional documentation.
  function _alterBeneficiary(
    Deposit storage deposit,
    DepositIdentifier _depositId,
    address _newBeneficiary
  ) internal {
    _revertIfAddressZero(_newBeneficiary);

    // Updating the earning power here is not strictly necessary, but if the user is touching their
    // deposit anyway, it seems reasonable to make sure their earning power is up to date.
    uint96 _newEarningPower =
      uint96(earningPowerCalculator.getEarningPower(deposit.balance, deposit.owner, deposit.delegatee));
    totalEarningPower = _calculateTotalEarningPower(deposit.earningPower, _newEarningPower);
    deposit.earningPower = _newEarningPower;

    emit BeneficiaryAltered(_depositId, deposit.beneficiary, _newBeneficiary);
    deposit.beneficiary = _newBeneficiary;
  }

  /// @notice Internal convenience method which withdraws the stake from an existing deposit.
  /// @dev This method must only be called after proper authorization has been completed.
  /// @dev See public withdraw methods for additional documentation.
  function _withdraw(Deposit storage deposit, DepositIdentifier _depositId, uint96 _amount)
    internal
  {
    _checkpointGlobalReward();
    _checkpointReward(deposit);

    // overflow prevents withdrawing more than balance
    uint96 _newBalance = deposit.balance - _amount;
    uint96 _newEarningPower =
      uint96(earningPowerCalculator.getEarningPower(_newBalance, deposit.owner, deposit.delegatee));

    totalStaked -= _amount;
    totalEarningPower = _calculateTotalEarningPower(deposit.earningPower, _newEarningPower);
    depositorTotalStaked[deposit.owner] -= _amount;
    deposit.balance = _newBalance;
    deposit.earningPower = _newEarningPower;
    _stakeTokenSafeTransferFrom(address(surrogates[deposit.delegatee]), deposit.owner, _amount);
    emit StakeWithdrawn(_depositId, _amount, deposit.balance);
  }

  /// @notice Internal convenience method which claims earned rewards.
  /// @return Amount of reward tokens claimed.
  /// @dev This method must only be called after proper authorization has been completed.
  /// @dev See public claimReward methods for additional documentation.
  function _claimReward(DepositIdentifier _depositId, Deposit storage deposit, address _claimer)
    internal
    returns (uint256)
  {
    _checkpointGlobalReward();
    _checkpointReward(deposit);

    uint256 _reward = deposit.scaledUnclaimedRewardCheckpoint / SCALE_FACTOR;
    if (_reward == 0) return 0;

    // retain sub-wei dust that would be left due to the precision loss
    deposit.scaledUnclaimedRewardCheckpoint =
      deposit.scaledUnclaimedRewardCheckpoint - (_reward * SCALE_FACTOR);
    emit RewardClaimed(_depositId, _claimer, _reward);

    uint96 _newEarningPower =
      uint96(earningPowerCalculator.getEarningPower(deposit.balance, deposit.owner, deposit.delegatee));
    totalEarningPower = _calculateTotalEarningPower(deposit.earningPower, _newEarningPower);
    deposit.earningPower = _newEarningPower;

    SafeERC20.safeTransfer(REWARD_TOKEN, _claimer, _reward);
    return _reward;
  }

  /// @notice Checkpoints the global reward per token accumulator.
  function _checkpointGlobalReward() internal {
    rewardPerTokenAccumulatedCheckpoint = rewardPerTokenAccumulated();
    lastCheckpointTime = lastTimeRewardDistributed();
  }

  /// @notice Checkpoints the unclaimed rewards and reward per token accumulator of a given
  /// deposit.
  /// @param deposit The deposit for which the reward parameters will be checkpointed.
  /// @dev This is a sensitive internal helper method that must only be called after global rewards
  /// accumulator has been checkpointed. It assumes the global `rewardPerTokenCheckpoint` is up to
  /// date.
  function _checkpointReward(Deposit storage deposit) internal {
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
    uint256 _depositNewEarningPower
  ) internal view returns (uint256 _newTotalEarningPower) {
    if (_depositNewEarningPower >= _depositOldEarningPower) {
      _newTotalEarningPower =
        totalEarningPower + (_depositNewEarningPower - _depositOldEarningPower);
    } else {
      _newTotalEarningPower =
        totalEarningPower - (_depositOldEarningPower - _depositNewEarningPower);
    }
  }

  /// @notice Internal helper method which sets the admin address.
  /// @param _newAdmin Address of the new admin.
  function _setAdmin(address _newAdmin) internal {
    _revertIfAddressZero(_newAdmin);
    emit AdminSet(admin, _newAdmin);
    admin = _newAdmin;
  }

  /// @notice Internal helper method which sets the earning power calculator address.
  function _setEarningPowerCalculator(address _newEarningPowerCalculator) internal {
    _revertIfAddressZero(_newEarningPowerCalculator);
    emit EarningPowerCalculatorSet(address(earningPowerCalculator), _newEarningPowerCalculator);
    earningPowerCalculator = IEarningPowerCalculator(_newEarningPowerCalculator);
  }

  /// @notice Internal helper method which sets the max bump tip.
  /// @param _newMaxTip Value of the new max bump tip.
  function _setMaxBumpTip(uint256 _newMaxTip) internal {
    emit MaxBumpTipSet(maxBumpTip, _newMaxTip);
    maxBumpTip = _newMaxTip;
  }

  /// @notice Internal helper method which reverts GovernanceStaker__Unauthorized if the message
  /// sender is not the admin.
  function _revertIfNotAdmin() internal view {
    if (msg.sender != admin) revert GovernanceStaker__Unauthorized("not admin", msg.sender);
  }

  /// @notice Internal helper method which reverts GovernanceStaker__Unauthorized if the alleged
  /// owner is
  /// not the true owner of the deposit.
  /// @param deposit Deposit to validate.
  /// @param owner Alleged owner of deposit.
  function _revertIfNotDepositOwner(Deposit storage deposit, address owner) internal view {
    if (owner != deposit.owner) revert GovernanceStaker__Unauthorized("not owner", owner);
  }

  /// @notice Internal helper method which reverts with GovernanceStaker__InvalidAddress if the
  /// account in question is address zero.
  /// @param _account Account to verify.
  function _revertIfAddressZero(address _account) internal pure {
    if (_account == address(0)) revert GovernanceStaker__InvalidAddress();
  }

  function _revertIfPastDeadline(uint256 _deadline) internal view {
    if (block.timestamp > _deadline) revert GovernanceStaker__ExpiredDeadline();
  }

  /// @notice Internal helper method which reverts with GovernanceStaker__InvalidSignature if the
  /// signature is invalid.
  /// @param _signer Address of the signer.
  /// @param _hash Hash of the message.
  /// @param _signature Signature to validate.
  function _revertIfSignatureIsNotValidNow(address _signer, bytes32 _hash, bytes memory _signature)
    internal
    view
  {
    bool _isValid = SignatureChecker.isValidSignatureNow(_signer, _hash, _signature);
    if (!_isValid) revert GovernanceStaker__InvalidSignature();
  }
}

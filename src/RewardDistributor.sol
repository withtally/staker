
import {INotifiableRewardReceiver} from "./interfaces/INotifiableRewardReceiver.sol";

abstract contract Staker is INotifiableRewardReceiver {
    struct DelegateReward {
        uint96 earningPower;
        address claimer;
        uint256 rewardPerTokenCheckpoint;
        uint256 scaledUnclaimedRewardCheckpoint;
    }

	struct ClaimFeeParameters {
        uint96 feeAmount;
        address feeCollector;
    }

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










}

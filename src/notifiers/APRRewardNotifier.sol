// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Staker} from "../Staker.sol";

contract APRRewardNotifier is AccessControl {
  using SafeERC20 for IERC20;

  event Notified(uint256 amount, uint256 currentAPR);

  event MaxEarningPowerTokenMultiplierSet(uint16 oldMultiplier, uint16 newMultiplier);

  event TargetAPRSet(uint16 oldTargetAPR, uint16 newTargetAPR);

  error APRRewardNotifier__InvalidParameter();

  error APRRewardNotifier__APROffTarget();

  Staker public immutable RECEIVER;

  IERC20 public immutable REWARD_TOKEN;

  uint16 public constant BIPS_DENOMINATOR = 10_000;

  bytes32 public constant NOTIFIER_ROLE = keccak256("NOTIFIER");

  uint256 public constant SECONDS_PER_YEAR = 31_556_952;

  uint16 public maxEarningPowerTokenMultiplier;

  uint16 public targetAPR;

  constructor(Staker _receiver, IERC20 _rewardToken, uint16 _multiple, address _owner) {
    RECEIVER = _receiver;
    REWARD_TOKEN = _rewardToken;

    _setMaxEarningPowerTokenMultiplier(_multiple);
    _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    _grantRole(NOTIFIER_ROLE, _owner);
  }

  /// @notice Currently this only handles lowering to APR ceiling
  function notifyDecrease() external virtual {
    _checkRole(NOTIFIER_ROLE, msg.sender);
    uint256 _currentAPR = _currentScaledAPR();
    // Calculate how to raise the apr
    if (_currentAPR <= targetAPR) revert APRRewardNotifier__APROffTarget();
    uint256 _targetScaledRate = _targetScaledRewardRate();
    uint256 _maxRewardAmount =
      (_targetScaledRate * RECEIVER.REWARD_DURATION()) / RECEIVER.SCALE_FACTOR();
    uint256 _remainingRewards = _remainingScaledReward() / RECEIVER.SCALE_FACTOR();

    uint256 _amountToNotify =
      (_maxRewardAmount > _remainingRewards) ? _maxRewardAmount - _remainingRewards : 0;

    REWARD_TOKEN.safeTransfer(address(RECEIVER), _amountToNotify);

    RECEIVER.notifyRewardAmount(_amountToNotify);
    emit Notified(_amountToNotify, _currentAPR);
  }

  function notifyIncrease() external virtual {
    _checkRole(NOTIFIER_ROLE, msg.sender);
    uint256 _currentAPR = _currentScaledAPR();
    // Calculate how to raise the apr
    if (_currentAPR >= targetAPR) revert APRRewardNotifier__APROffTarget();
    uint256 _targetScaledRate = _targetScaledRewardRate();
    uint256 _maxRewardAmount =
      (_targetScaledRate * RECEIVER.REWARD_DURATION()) / RECEIVER.SCALE_FACTOR();
    uint256 _remainingRewards = _remainingScaledReward() / RECEIVER.SCALE_FACTOR();

    uint256 _amountToNotify = _maxRewardAmount - _remainingRewards;

    REWARD_TOKEN.safeTransfer(address(RECEIVER), _amountToNotify);

    RECEIVER.notifyRewardAmount(_amountToNotify);
    emit Notified(_amountToNotify, _currentAPR);
  }

  function setMaxEarningPowerTokenMultiplier(uint16 _multiple) external {
    _checkRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setMaxEarningPowerTokenMultiplier(_multiple);
  }

  function setTargetAPR(uint16 _targetAPR) external virtual {
    _checkRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setTargetAPR(_targetAPR);
  }

  function _currentScaledAPR() internal view returns (uint256) {
    uint256 _totalEarningPower = RECEIVER.totalEarningPower();
    if (_totalEarningPower == 0) return 0;

    return (
      (RECEIVER.scaledRewardRate() * uint256(maxEarningPowerTokenMultiplier) * SECONDS_PER_YEAR)
        / (_totalEarningPower * BIPS_DENOMINATOR * RECEIVER.SCALE_FACTOR())
    );
  }

  function _remainingScaledReward() internal view returns (uint256) {
    uint256 _rewardEndTime = RECEIVER.rewardEndTime();
    if (block.timestamp >= _rewardEndTime) return 0;
    return RECEIVER.scaledRewardRate() * (_rewardEndTime - block.timestamp);
  }

  function _setMaxEarningPowerTokenMultiplier(uint16 _multiple) internal {
    if (_multiple == 0) revert APRRewardNotifier__InvalidParameter();
    emit MaxEarningPowerTokenMultiplierSet(maxEarningPowerTokenMultiplier, _multiple);
    maxEarningPowerTokenMultiplier = _multiple;
  }

  function _setTargetAPR(uint16 _targetAPR) internal {
    if (_targetAPR == 0) revert APRRewardNotifier__InvalidParameter();
    emit TargetAPRSet(targetAPR, _targetAPR);
    targetAPR = _targetAPR;
  }

  function _targetScaledRewardRate() internal view returns (uint256) {
    uint256 _totalEarningPower = RECEIVER.totalEarningPower();
    if (_totalEarningPower == 0) return 0;
    return (
      uint256(targetAPR) * _totalEarningPower * uint256(maxEarningPowerTokenMultiplier)
        * RECEIVER.SCALE_FACTOR()
    ) / (BIPS_DENOMINATOR * SECONDS_PER_YEAR);
  }
}

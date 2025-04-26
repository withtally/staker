// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {FullStaker} from "./FullStaker.sol";
import {IEarningPowerCalculator} from "../interfaces/IEarningPowerCalculator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Staking} from "../interfaces/IERC20Staking.sol";

/// @title StakerFactory
/// @notice Deploys fully-featured staking systems (`FullStaker`) for users in a single call.
contract StakerFactory {
  /// @notice Emitted each time a new staking system is deployed.
  /// @param staker   Address of the newly‐deployed FullStaker contract.
  /// @param stakeToken The staking token accepted by the system.
  /// @param rewardsToken The reward token distributed by the system.
  /// @param admin    Admin address configured for the system.
  event StakingSystemCreated(
    address indexed staker,
    address indexed stakeToken,
    address indexed rewardsToken,
    address admin
  );

  /// @dev Keep track of all deployed staking systems.
  address[] public allStakers;

  /// @notice Deploy a new `FullStaker` instance configured with the provided parameters.
  /// @param _rewardsToken ERC20 token distributed as rewards.
  /// @param _stakeToken   ERC20 token to stake (must support permit + votes).
  /// @param _earningPowerCalculator Calculator contract for earning power.
  /// @param _maxBumpTip  Initial max bump tip.
  /// @param _admin  Admin address for the staking system.
  /// @param _maxClaimFee Maximum fee that can be charged for claiming rewards (denominated in reward tokens).
  /// @return staker Address of the newly deployed FullStaker.
  function createStakingSystem(
    IERC20 _rewardsToken,
    IERC20Staking _stakeToken,
    IEarningPowerCalculator _earningPowerCalculator,
    uint256 _maxBumpTip,
    address _admin,
    uint256 _maxClaimFee
  ) external returns (address staker) {
    // Deploy
    FullStaker newStaker = new FullStaker(
      _rewardsToken,
      _stakeToken,
      _earningPowerCalculator,
      _maxBumpTip,
      _admin,
      _maxClaimFee
    );

    staker = address(newStaker);
    allStakers.push(staker);

    emit StakingSystemCreated(staker, address(_stakeToken), address(_rewardsToken), _admin);
  }

  /// @notice Returns the count of staking systems deployed by this factory.
  function allStakersLength() external view returns (uint256) {
    return allStakers.length;
  }
} 
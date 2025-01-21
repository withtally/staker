// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {INotifiableRewardReceiver, IERC20} from "src/interfaces/INotifiableRewardReceiver.sol";
import {IMintable} from "src/interfaces/IMintable.sol";
import {RewardTokenNotifierBase} from "src/notifiers/RewardTokenNotifierBase.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract MintRewardNotifier is RewardTokenNotifierBase {
  using SafeERC20 for IERC20;

  event MinterSet(IMintable oldMinter, IMintable newMinter);

  IMintable public minter;

  constructor(
    INotifiableRewardReceiver _receiver,
    uint256 _initialRewardAmount,
    uint256 _initialRewardInterval,
    address _initialOwner,
    IMintable _minter
  )
    RewardTokenNotifierBase(_receiver, _initialRewardAmount, _initialRewardInterval)
    Ownable(_initialOwner)
  {
    _setMinter(_minter);
  }

  function setMinter(IMintable _minter) external {
    _checkOwner();
    _setMinter(_minter);
  }

  function _setMinter(IMintable _newMinter) internal {
    emit MinterSet(minter, _newMinter);
    minter = _newMinter;
  }

  function _sendTokensToReceiver() internal virtual override {
    minter.mint(address(RECEIVER), rewardAmount);
  }
}

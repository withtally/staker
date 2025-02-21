// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {stdStorage, StdStorage} from "forge-std/Test.sol";
import {StakerOnBehalf} from "../src/extensions/StakerOnBehalf.sol";
import {StakerTest, StakerRewardsTest} from "test/Staker.t.sol";
import {StakerHarness} from "test/harnesses/StakerHarness.sol";
import {Staker, IERC20, IEarningPowerCalculator} from "../src/Staker.sol";
import {IERC20Staking} from "../src/interfaces/IERC20Staking.sol";

contract Domain_Separator is StakerTest {
  function _buildDomainSeparator(string memory _name, string memory _version, address _contract)
    internal
    view
    returns (bytes32)
  {
    bytes32 _typeHash = keccak256(
      "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    return keccak256(
      abi.encode(
        _typeHash, keccak256(bytes(_name)), keccak256(bytes(_version)), block.chainid, _contract
      )
    );
  }

  function testFuzz_CorrectlyReturnsTheDomainSeparator(
    address _rewardToken,
    address _stakeToken,
    address _earningPowerCalculator,
    uint256 _maxBumpTip,
    address _admin,
    string memory _name
  ) public {
    vm.assume(_admin != address(0) && _earningPowerCalculator != address(0));
    StakerHarness _govStaker = new StakerHarness(
      IERC20(_rewardToken),
      IERC20Staking(_stakeToken),
      IEarningPowerCalculator(_earningPowerCalculator),
      _maxBumpTip,
      _admin,
      _name
    );

    bytes32 _separator = _govStaker.DOMAIN_SEPARATOR();
    bytes32 _expectedSeparator = _buildDomainSeparator(_name, "1", address(_govStaker));
    assertEq(_separator, _expectedSeparator);
  }
}

contract InvalidateNonce is StakerTest {
  using stdStorage for StdStorage;

  function testFuzz_SuccessfullyIncrementsTheNonceOfTheSender(
    address _caller,
    uint256 _initialNonce
  ) public {
    vm.assume(_caller != address(0));
    vm.assume(_initialNonce != type(uint256).max);

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_caller).checked_write(
      _initialNonce
    );

    vm.prank(_caller);
    govStaker.invalidateNonce();

    uint256 currentNonce = govStaker.nonces(_caller);

    assertEq(currentNonce, _initialNonce + 1, "Current nonce is incorrect");
  }

  function testFuzz_IncreasesTheNonceByTwoWhenCalledTwice(address _caller, uint256 _initialNonce)
    public
  {
    vm.assume(_caller != address(0));
    _initialNonce = bound(_initialNonce, 0, type(uint256).max - 2);

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_caller).checked_write(
      _initialNonce
    );

    vm.prank(_caller);
    govStaker.invalidateNonce();

    vm.prank(_caller);
    govStaker.invalidateNonce();

    uint256 currentNonce = govStaker.nonces(_caller);

    assertEq(currentNonce, _initialNonce + 2, "Current nonce is incorrect");
  }
}

contract StakeOnBehalf is StakerTest {
  using stdStorage for StdStorage;

  function testFuzz_StakesOnBehalfOfAnotherAccount(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _depositAmount,
    address _delegatee,
    address _claimer,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _claimer != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    vm.prank(_depositor);
    govToken.approve(address(govStaker), _depositAmount);

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.STAKE_TYPEHASH(),
        _depositAmount,
        _delegatee,
        _claimer,
        _depositor,
        govStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.prank(_sender);
    Staker.DepositIdentifier _depositId = govStaker.stakeOnBehalf(
      _depositAmount, _delegatee, _claimer, _depositor, _deadline, _signature
    );

    Staker.Deposit memory _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.balance, _depositAmount);
    assertEq(_deposit.owner, _depositor);
    assertEq(_deposit.delegatee, _delegatee);
    assertEq(_deposit.claimer, _claimer);
  }

  function testFuzz_RevertIf_WrongNonceIsUsed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _depositAmount,
    address _delegatee,
    address _claimer,
    uint256 _currentNonce,
    uint256 _suppliedNonce,
    uint256 _deadline
  ) public {
    vm.assume(_currentNonce != _suppliedNonce);
    vm.assume(_delegatee != address(0) && _claimer != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    vm.prank(_depositor);
    govToken.approve(address(govStaker), _depositAmount);

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.STAKE_TYPEHASH(),
        _depositAmount,
        _delegatee,
        _claimer,
        _depositor,
        _suppliedNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__InvalidSignature.selector);
    vm.prank(_sender);
    govStaker.stakeOnBehalf(_depositAmount, _delegatee, _claimer, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DeadlineExpired(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _depositAmount,
    address _delegatee,
    address _claimer,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _claimer != address(0) && _sender != address(0));
    _deadline = bound(_deadline, 0, block.timestamp - 1);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    vm.prank(_depositor);
    govToken.approve(address(govStaker), _depositAmount);

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.STAKE_TYPEHASH(),
        _depositAmount,
        _delegatee,
        _claimer,
        _depositor,
        _currentNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__ExpiredDeadline.selector);
    vm.prank(_sender);
    govStaker.stakeOnBehalf(_depositAmount, _delegatee, _claimer, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_InvalidSignatureIsPassed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _depositAmount,
    address _delegatee,
    address _claimer,
    uint256 _currentNonce,
    uint256 _randomSeed,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _claimer != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);

    vm.prank(_depositor);
    govToken.approve(address(govStaker), _depositAmount);

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.STAKE_TYPEHASH(),
        _depositAmount,
        _delegatee,
        _claimer,
        _depositor,
        govStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));

    // Here we use `_randomSeed` as an arbitrary source of randomness to replace a legit parameter
    // with an attack-like one.
    if (_randomSeed % 6 == 0) {
      _depositAmount = uint256(keccak256(abi.encode(_depositAmount)));
    } else if (_randomSeed % 6 == 1) {
      _delegatee = address(uint160(uint256(keccak256(abi.encode(_delegatee)))));
    } else if (_randomSeed % 6 == 2) {
      _depositor = address(uint160(uint256(keccak256(abi.encode(_depositor)))));
    } else if (_randomSeed % 6 == 3) {
      _messageHash = _modifyMessage(_messageHash, uint256(keccak256(abi.encode(_randomSeed))));
    } else if (_randomSeed % 6 == 4) {
      _deadline = uint256(keccak256(abi.encode(_deadline)));
    }
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);
    if (_randomSeed % 6 == 5) _signature = _modifySignature(_signature, _randomSeed);

    vm.prank(_sender);
    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__InvalidSignature.selector);
    govStaker.stakeOnBehalf(_depositAmount, _delegatee, _claimer, _depositor, _deadline, _signature);
  }
}

contract StakeMoreOnBehalf is StakerTest {
  using stdStorage for StdStorage;

  function testFuzz_StakeMoreOnBehalfOfDepositor(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _initialDepositAmount,
    uint256 _stakeMoreAmount,
    address _delegatee,
    address _claimer,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _claimer != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);

    Staker.DepositIdentifier _depositId;
    (_initialDepositAmount, _depositId) =
      _boundMintAndStake(_depositor, _initialDepositAmount, _delegatee, _claimer);
    Staker.Deposit memory _deposit = _fetchDeposit(_depositId);

    _stakeMoreAmount = _boundToRealisticStake(_stakeMoreAmount);
    _mintGovToken(_depositor, _stakeMoreAmount);

    vm.startPrank(_depositor);
    govToken.approve(address(govStaker), _stakeMoreAmount);
    vm.stopPrank();

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.STAKE_MORE_TYPEHASH(),
        _depositId,
        _stakeMoreAmount,
        _depositor,
        govStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.prank(_sender);
    govStaker.stakeMoreOnBehalf(_depositId, _stakeMoreAmount, _depositor, _deadline, _signature);

    _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.balance, _initialDepositAmount + _stakeMoreAmount);
    assertEq(_deposit.owner, _depositor);
    assertEq(_deposit.delegatee, _delegatee);
    assertEq(_deposit.claimer, _claimer);
  }

  function testFuzz_RevertIf_WrongNonceIsUsed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _initialDepositAmount,
    uint256 _stakeMoreAmount,
    address _delegatee,
    address _claimer,
    uint256 _currentNonce,
    uint256 _suppliedNonce,
    uint256 _deadline
  ) public {
    vm.assume(_currentNonce != _suppliedNonce);
    vm.assume(_delegatee != address(0) && _claimer != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _initialDepositAmount = _boundMintAmount(_initialDepositAmount);
    _mintGovToken(_depositor, _initialDepositAmount);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    Staker.DepositIdentifier _depositId;
    (_initialDepositAmount, _depositId) =
      _boundMintAndStake(_depositor, _initialDepositAmount, _delegatee, _claimer);

    _stakeMoreAmount = _boundToRealisticStake(_stakeMoreAmount);
    _mintGovToken(_depositor, _stakeMoreAmount);

    vm.startPrank(_depositor);
    govToken.approve(address(govStaker), _stakeMoreAmount);
    vm.stopPrank();

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.STAKE_MORE_TYPEHASH(),
        _depositId,
        _stakeMoreAmount,
        _depositor,
        _suppliedNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__InvalidSignature.selector);
    vm.prank(_sender);
    govStaker.stakeMoreOnBehalf(_depositId, _stakeMoreAmount, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DeadlineExpired(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _initialDepositAmount,
    uint256 _stakeMoreAmount,
    address _delegatee,
    address _claimer,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _claimer != address(0) && _sender != address(0));
    _deadline = bound(_deadline, 0, block.timestamp - 1);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _initialDepositAmount = _boundMintAmount(_initialDepositAmount);
    _mintGovToken(_depositor, _initialDepositAmount);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    Staker.DepositIdentifier _depositId;
    (_initialDepositAmount, _depositId) =
      _boundMintAndStake(_depositor, _initialDepositAmount, _delegatee, _claimer);

    _stakeMoreAmount = _boundToRealisticStake(_stakeMoreAmount);
    _mintGovToken(_depositor, _stakeMoreAmount);

    vm.startPrank(_depositor);
    govToken.approve(address(govStaker), _stakeMoreAmount);
    vm.stopPrank();

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.STAKE_MORE_TYPEHASH(),
        _depositId,
        _stakeMoreAmount,
        _depositor,
        _currentNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__ExpiredDeadline.selector);
    vm.prank(_sender);
    govStaker.stakeMoreOnBehalf(_depositId, _stakeMoreAmount, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DepositorIsNotDepositOwner(
    address _sender,
    address _depositor,
    address _notDepositor,
    uint256 _initialDepositAmount,
    uint256 _stakeMoreAmount,
    address _delegatee,
    address _claimer,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(
      _delegatee != address(0) && _claimer != address(0) && _sender != address(0)
        && _depositor != _notDepositor
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _initialDepositAmount = _boundMintAmount(_initialDepositAmount);
    _mintGovToken(_depositor, _initialDepositAmount);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    Staker.DepositIdentifier _depositId;
    (_initialDepositAmount, _depositId) =
      _boundMintAndStake(_depositor, _initialDepositAmount, _delegatee, _claimer);

    vm.expectRevert(
      abi.encodeWithSelector(
        Staker.Staker__Unauthorized.selector, bytes32("not owner"), _notDepositor
      )
    );
    vm.prank(_sender);
    govStaker.stakeMoreOnBehalf(_depositId, _stakeMoreAmount, _notDepositor, _deadline, "");
  }

  function testFuzz_RevertIf_InvalidSignatureIsPassed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _initialDepositAmount,
    uint256 _stakeMoreAmount,
    address _delegatee,
    address _claimer,
    uint256 _currentNonce,
    uint256 _randomSeed,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _claimer != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _initialDepositAmount = _boundMintAmount(_initialDepositAmount);
    _mintGovToken(_depositor, _initialDepositAmount);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    Staker.DepositIdentifier _depositId;
    (_initialDepositAmount, _depositId) =
      _boundMintAndStake(_depositor, _initialDepositAmount, _delegatee, _claimer);

    _stakeMoreAmount = _boundToRealisticStake(_stakeMoreAmount);
    _mintGovToken(_depositor, _stakeMoreAmount);

    vm.startPrank(_depositor);
    govToken.approve(address(govStaker), _stakeMoreAmount);
    vm.stopPrank();

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.STAKE_MORE_TYPEHASH(),
        _depositId,
        _stakeMoreAmount,
        _depositor,
        govStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));

    // Here we use `_randomSeed` as an arbitrary source of randomness to replace a legit parameter
    // with an attack-like one.
    if (_randomSeed % 4 == 0) {
      _stakeMoreAmount = uint256(keccak256(abi.encode(_stakeMoreAmount)));
    } else if (_randomSeed % 4 == 1) {
      _messageHash = _modifyMessage(_messageHash, uint256(keccak256(abi.encode(_randomSeed))));
    } else if (_randomSeed % 4 == 2) {
      _deadline = uint256(keccak256(abi.encode(_deadline)));
    }
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);
    if (_randomSeed % 4 == 3) _signature = _modifySignature(_signature, _randomSeed);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__InvalidSignature.selector);
    vm.prank(_sender);
    govStaker.stakeMoreOnBehalf(_depositId, _stakeMoreAmount, _depositor, _deadline, _signature);
  }
}

contract AlterDelegateeOnBehalf is StakerTest {
  using stdStorage for StdStorage;

  function testFuzz_AlterDelegateeOnBehalfOfDepositor(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _amount,
    address _delegatee,
    address _claimer,
    address _newDelegatee,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(
      _delegatee != address(0) && _claimer != address(0) && _sender != address(0)
        && _newDelegatee != address(0)
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);

    Staker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _claimer);
    Staker.Deposit memory _deposit = _fetchDeposit(_depositId);

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.ALTER_DELEGATEE_TYPEHASH(),
        _depositId,
        _newDelegatee,
        _depositor,
        govStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.prank(_sender);
    govStaker.alterDelegateeOnBehalf(_depositId, _newDelegatee, _depositor, _deadline, _signature);

    _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.delegatee, _newDelegatee);
  }

  function testFuzz_RevertIf_WrongNonceIsUsed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _amount,
    address _delegatee,
    address _claimer,
    address _newDelegatee,
    uint256 _currentNonce,
    uint256 _suppliedNonce,
    uint256 _deadline
  ) public {
    vm.assume(_currentNonce != _suppliedNonce);
    vm.assume(
      _delegatee != address(0) && _claimer != address(0) && _sender != address(0)
        && _newDelegatee != address(0)
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    Staker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _claimer);

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.ALTER_DELEGATEE_TYPEHASH(), _depositId, _newDelegatee, _depositor, _suppliedNonce
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__InvalidSignature.selector);
    vm.prank(_sender);
    govStaker.alterDelegateeOnBehalf(_depositId, _newDelegatee, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DeadlineExpired(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _amount,
    address _delegatee,
    address _claimer,
    address _newDelegatee,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(
      _delegatee != address(0) && _claimer != address(0) && _sender != address(0)
        && _newDelegatee != address(0)
    );
    _deadline = bound(_deadline, 0, block.timestamp - 1);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    Staker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _claimer);

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.ALTER_DELEGATEE_TYPEHASH(),
        _depositId,
        _newDelegatee,
        _depositor,
        _currentNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__ExpiredDeadline.selector);
    vm.prank(_sender);
    govStaker.alterDelegateeOnBehalf(_depositId, _newDelegatee, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DepositorIsNotDepositOwner(
    address _sender,
    address _depositor,
    address _notDepositor,
    uint256 _amount,
    address _delegatee,
    address _newDelegatee,
    address _claimer,
    uint256 _deadline,
    bytes memory _signature
  ) public {
    vm.assume(
      _delegatee != address(0) && _claimer != address(0) && _sender != address(0)
        && _depositor != _notDepositor
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);

    Staker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _claimer);

    vm.expectRevert(
      abi.encodeWithSelector(
        Staker.Staker__Unauthorized.selector, bytes32("not owner"), _notDepositor
      )
    );
    vm.prank(_sender);
    govStaker.alterDelegateeOnBehalf(
      _depositId, _newDelegatee, _notDepositor, _deadline, _signature
    );
  }

  function testFuzz_RevertIf_InvalidSignatureIsPassed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _amount,
    address _delegatee,
    address _claimer,
    address _newDelegatee,
    uint256 _currentNonce,
    uint256 _randomSeed,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _claimer != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    Staker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _claimer);

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.ALTER_DELEGATEE_TYPEHASH(),
        _depositId,
        _newDelegatee,
        _depositor,
        govStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));

    // Here we use `_randomSeed` as an arbitrary source of randomness to replace a legit parameter
    // with an attack-like one.
    if (_randomSeed % 4 == 0) {
      _newDelegatee = address(uint160(uint256(keccak256(abi.encode(_newDelegatee)))));
    } else if (_randomSeed % 4 == 1) {
      _messageHash = _modifyMessage(_messageHash, uint256(keccak256(abi.encode(_randomSeed))));
    } else if (_randomSeed % 4 == 2) {
      _deadline = uint256(keccak256(abi.encode(_deadline)));
    }
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);
    if (_randomSeed % 4 == 3) _signature = _modifySignature(_signature, _randomSeed);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__InvalidSignature.selector);
    vm.prank(_sender);
    govStaker.alterDelegateeOnBehalf(_depositId, _newDelegatee, _depositor, _deadline, _signature);
  }
}

contract AlterClaimerOnBehalf is StakerTest {
  using stdStorage for StdStorage;

  function testFuzz_AlterClaimerOnBehalfOfDepositor(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _amount,
    address _delegatee,
    address _claimer,
    address _newClaimer,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(
      _delegatee != address(0) && _claimer != address(0) && _sender != address(0)
        && _newClaimer != address(0)
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);

    Staker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _claimer);
    Staker.Deposit memory _deposit = _fetchDeposit(_depositId);

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.ALTER_CLAIMER_TYPEHASH(),
        _depositId,
        _newClaimer,
        _depositor,
        govStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.prank(_sender);
    govStaker.alterClaimerOnBehalf(_depositId, _newClaimer, _depositor, _deadline, _signature);

    _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.claimer, _newClaimer);
  }

  function testFuzz_RevertIf_WrongNonceIsUsed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _amount,
    address _delegatee,
    address _claimer,
    address _newClaimer,
    uint256 _currentNonce,
    uint256 _suppliedNonce,
    uint256 _deadline
  ) public {
    vm.assume(_currentNonce != _suppliedNonce);
    vm.assume(
      _delegatee != address(0) && _claimer != address(0) && _sender != address(0)
        && _newClaimer != address(0)
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    Staker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _claimer);

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.ALTER_CLAIMER_TYPEHASH(),
        _depositId,
        _newClaimer,
        _depositor,
        _suppliedNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__InvalidSignature.selector);
    vm.prank(_sender);
    govStaker.alterClaimerOnBehalf(_depositId, _newClaimer, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DeadlineExpired(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _amount,
    address _delegatee,
    address _claimer,
    address _newClaimer,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(
      _delegatee != address(0) && _claimer != address(0) && _sender != address(0)
        && _newClaimer != address(0)
    );
    _deadline = bound(_deadline, 0, block.timestamp - 1);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    Staker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _claimer);

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.ALTER_CLAIMER_TYPEHASH(),
        _depositId,
        _newClaimer,
        _depositor,
        _currentNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__ExpiredDeadline.selector);
    vm.prank(_sender);
    govStaker.alterClaimerOnBehalf(_depositId, _newClaimer, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DepositorIsNotDepositOwner(
    address _sender,
    address _depositor,
    address _notDepositor,
    uint256 _amount,
    address _delegatee,
    address _claimer,
    address _newClaimer,
    uint256 _deadline,
    bytes memory _signature
  ) public {
    vm.assume(
      _delegatee != address(0) && _claimer != address(0) && _sender != address(0)
        && _depositor != _notDepositor
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);

    Staker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _claimer);

    vm.expectRevert(
      abi.encodeWithSelector(
        Staker.Staker__Unauthorized.selector, bytes32("not owner"), _notDepositor
      )
    );
    vm.prank(_sender);
    govStaker.alterClaimerOnBehalf(_depositId, _newClaimer, _notDepositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_InvalidSignatureIsPassed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _amount,
    address _delegatee,
    address _claimer,
    address _newClaimer,
    uint256 _currentNonce,
    uint256 _randomSeed,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _claimer != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    Staker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _claimer);

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.ALTER_CLAIMER_TYPEHASH(),
        _depositId,
        _newClaimer,
        _depositor,
        govStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));

    // Here we use `_randomSeed` as an arbitrary source of randomness to replace a legit parameter
    // with an attack-like one.
    if (_randomSeed % 4 == 0) {
      _newClaimer = address(uint160(uint256(keccak256(abi.encode(_newClaimer)))));
    } else if (_randomSeed % 4 == 1) {
      _messageHash = _modifyMessage(_messageHash, uint256(keccak256(abi.encode(_randomSeed))));
    } else if (_randomSeed % 4 == 2) {
      _deadline = uint256(keccak256(abi.encode(_deadline)));
    }
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);
    if (_randomSeed % 4 == 3) _signature = _modifySignature(_signature, _randomSeed);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__InvalidSignature.selector);
    vm.prank(_sender);
    govStaker.alterClaimerOnBehalf(_depositId, _newClaimer, _depositor, _deadline, _signature);
  }
}

contract WithdrawOnBehalf is StakerTest {
  using stdStorage for StdStorage;

  function testFuzz_WithdrawOnBehalfOfDepositor(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _depositAmount,
    address _delegatee,
    address _claimer,
    uint256 _withdrawAmount,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _claimer != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);

    Staker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _claimer);
    Staker.Deposit memory _deposit = _fetchDeposit(_depositId);
    _withdrawAmount = bound(_withdrawAmount, 0, _depositAmount);

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.WITHDRAW_TYPEHASH(),
        _depositId,
        _withdrawAmount,
        _depositor,
        govStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.prank(_sender);
    govStaker.withdrawOnBehalf(_depositId, _withdrawAmount, _depositor, _deadline, _signature);

    _deposit = _fetchDeposit(_depositId);

    assertEq(_deposit.balance, _depositAmount - _withdrawAmount);
  }

  function testFuzz_RevertIf_WrongNonceIsUsed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _depositAmount,
    address _delegatee,
    address _claimer,
    uint256 _withdrawAmount,
    uint256 _currentNonce,
    uint256 _suppliedNonce,
    uint256 _deadline
  ) public {
    vm.assume(_currentNonce != _suppliedNonce);
    vm.assume(_delegatee != address(0) && _claimer != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    Staker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _claimer);

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.WITHDRAW_TYPEHASH(),
        _depositId,
        _withdrawAmount,
        _depositor,
        _suppliedNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__InvalidSignature.selector);
    vm.prank(_sender);
    govStaker.withdrawOnBehalf(_depositId, _withdrawAmount, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DeadlineExpired(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _depositAmount,
    address _delegatee,
    address _claimer,
    uint256 _withdrawAmount,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _claimer != address(0) && _sender != address(0));
    _deadline = bound(_deadline, 0, block.timestamp - 1);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    Staker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _claimer);

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.WITHDRAW_TYPEHASH(),
        _depositId,
        _withdrawAmount,
        _depositor,
        _currentNonce,
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__ExpiredDeadline.selector);
    vm.prank(_sender);
    govStaker.withdrawOnBehalf(_depositId, _withdrawAmount, _depositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_DepositorIsNotDepositOwner(
    address _sender,
    address _depositor,
    address _notDepositor,
    uint256 _amount,
    address _delegatee,
    address _claimer,
    uint256 _withdrawAmount,
    uint256 _deadline,
    bytes memory _signature
  ) public {
    vm.assume(
      _delegatee != address(0) && _claimer != address(0) && _sender != address(0)
        && _depositor != _notDepositor
    );
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _amount = _boundMintAmount(_amount);
    _mintGovToken(_depositor, _amount);

    Staker.DepositIdentifier _depositId;
    (_amount, _depositId) = _boundMintAndStake(_depositor, _amount, _delegatee, _claimer);

    vm.expectRevert(
      abi.encodeWithSelector(
        Staker.Staker__Unauthorized.selector, bytes32("not owner"), _notDepositor
      )
    );
    vm.prank(_sender);
    govStaker.withdrawOnBehalf(_depositId, _withdrawAmount, _notDepositor, _deadline, _signature);
  }

  function testFuzz_RevertIf_InvalidSignatureIsPassed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _depositAmount,
    address _delegatee,
    address _claimer,
    uint256 _withdrawAmount,
    uint256 _currentNonce,
    uint256 _randomSeed,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _claimer != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    Staker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _claimer);

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.WITHDRAW_TYPEHASH(),
        _depositId,
        _withdrawAmount,
        _depositor,
        govStaker.nonces(_depositor),
        _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));

    // Here we use `_randomSeed` as an arbitrary source of randomness to replace a legit parameter
    // with an attack-like one.
    if (_randomSeed % 4 == 0) {
      _withdrawAmount = uint256(keccak256(abi.encode(_withdrawAmount)));
    } else if (_randomSeed % 4 == 1) {
      _messageHash = _modifyMessage(_messageHash, uint256(keccak256(abi.encode(_randomSeed))));
    } else if (_randomSeed % 4 == 2) {
      _deadline = uint256(keccak256(abi.encode(_deadline)));
    }
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);
    if (_randomSeed % 4 == 3) _signature = _modifySignature(_signature, _randomSeed);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__InvalidSignature.selector);
    vm.prank(_sender);
    govStaker.withdrawOnBehalf(_depositId, _withdrawAmount, _depositor, _deadline, _signature);
  }
}

contract ClaimRewardOnBehalf is StakerRewardsTest {
  using stdStorage for StdStorage;

  function testFuzz_ClaimRewardOnBehalfOfClaimer(
    uint256 _claimerPrivateKey,
    address _sender,
    uint256 _depositAmount,
    uint256 _durationPercent,
    uint256 _rewardAmount,
    address _depositor,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_depositor != address(0) && _sender != address(0));
    _claimerPrivateKey = bound(_claimerPrivateKey, 1, 100e18);
    address _claimer = vm.addr(_claimerPrivateKey);

    Staker.DepositIdentifier _depositId;
    (_depositAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_depositAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, address(0x01), _claimer);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);

    uint256 _earned = govStaker.unclaimedReward(_depositId);

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_claimer).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.CLAIM_REWARD_TYPEHASH(), _depositId, govStaker.nonces(_claimer), _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_claimerPrivateKey, _messageHash);

    uint256 _oldDepositorNonce = govStaker.nonces(_depositor);
    vm.prank(_sender);
    govStaker.claimRewardOnBehalf(_depositId, _deadline, _signature);

    assertEq(rewardToken.balanceOf(_claimer), _earned);
    assertEq(govStaker.nonces(_depositor), _oldDepositorNonce);
  }

  function testFuzz_ClaimRewardOnBehalfOfDepositor(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _depositAmount,
    uint256 _durationPercent,
    uint256 _rewardAmount,
    address _claimer,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_claimer != address(0) && _sender != address(0));
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);

    Staker.DepositIdentifier _depositId;
    (_depositAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_depositAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, address(0x01), _claimer);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);

    uint256 _earned = govStaker.unclaimedReward(_depositId);

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.CLAIM_REWARD_TYPEHASH(), _depositId, govStaker.nonces(_depositor), _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    uint256 _oldClaimerNonce = govStaker.nonces(_claimer);
    vm.prank(_sender);
    govStaker.claimRewardOnBehalf(_depositId, _deadline, _signature);

    assertEq(rewardToken.balanceOf(_depositor), _earned);
    assertEq(govStaker.nonces(_claimer), _oldClaimerNonce);
  }

  function testFuzz_ReturnsClaimedRewardAmount(
    uint256 _claimerPrivateKey,
    address _sender,
    uint256 _depositAmount,
    uint256 _durationPercent,
    uint256 _rewardAmount,
    address _delegatee,
    address _depositor,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _depositor != address(0) && _sender != address(0));
    _claimerPrivateKey = bound(_claimerPrivateKey, 1, 100e18);
    address _claimer = vm.addr(_claimerPrivateKey);

    Staker.DepositIdentifier _depositId;
    (_depositAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_depositAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _claimer);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);

    uint256 _earned = govStaker.unclaimedReward(_depositId);

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_claimer).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(
        govStaker.CLAIM_REWARD_TYPEHASH(), _depositId, govStaker.nonces(_claimer), _deadline
      )
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_claimerPrivateKey, _messageHash);

    vm.prank(_sender);
    uint256 _claimedAmount = govStaker.claimRewardOnBehalf(_depositId, _deadline, _signature);

    assertEq(_earned, _claimedAmount);
  }

  function testFuzz_RevertIf_WrongClaimerNonceIsUsed(
    uint256 _claimerPrivateKey,
    address _sender,
    uint256 _depositAmount,
    uint256 _durationPercent,
    uint256 _rewardAmount,
    address _delegatee,
    address _depositor,
    uint256 _currentNonce,
    uint256 _suppliedNonce,
    uint256 _deadline
  ) public {
    vm.assume(_currentNonce != _suppliedNonce);
    vm.assume(_delegatee != address(0) && _depositor != address(0) && _sender != address(0));
    _claimerPrivateKey = bound(_claimerPrivateKey, 1, 100e18);
    address _claimer = vm.addr(_claimerPrivateKey);

    Staker.DepositIdentifier _depositId;
    (_depositAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_depositAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _claimer);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_claimer).checked_write(
      _currentNonce
    );

    bytes32 _message =
      keccak256(abi.encode(govStaker.CLAIM_REWARD_TYPEHASH(), _claimer, _suppliedNonce, _deadline));

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_claimerPrivateKey, _messageHash);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__InvalidSignature.selector);
    vm.prank(_sender);
    govStaker.claimRewardOnBehalf(_depositId, _deadline, _signature);
  }

  function testFuzz_RevertIf_WrongDepositorNonceIsUsed(
    uint256 _depositorPrivateKey,
    address _sender,
    uint256 _depositAmount,
    uint256 _durationPercent,
    uint256 _rewardAmount,
    address _delegatee,
    address _claimer,
    uint256 _currentNonce,
    uint256 _suppliedNonce,
    uint256 _deadline
  ) public {
    vm.assume(_currentNonce != _suppliedNonce);
    vm.assume(_delegatee != address(0) && _claimer != address(0) && _sender != address(0));
    _depositorPrivateKey = bound(_depositorPrivateKey, 1, 100e18);
    address _depositor = vm.addr(_depositorPrivateKey);

    Staker.DepositIdentifier _depositId;
    (_depositAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_depositAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _claimer);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_depositor).checked_write(
      _currentNonce
    );

    bytes32 _message = keccak256(
      abi.encode(govStaker.CLAIM_REWARD_TYPEHASH(), _depositor, _suppliedNonce, _deadline)
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_depositorPrivateKey, _messageHash);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__InvalidSignature.selector);
    vm.prank(_sender);
    govStaker.claimRewardOnBehalf(_depositId, _deadline, _signature);
  }

  function testFuzz_RevertIf_DeadlineExpired(
    uint256 _claimerPrivateKey,
    address _sender,
    uint256 _depositAmount,
    uint256 _durationPercent,
    uint256 _rewardAmount,
    address _delegatee,
    address _depositor,
    uint256 _currentNonce,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _depositor != address(0) && _sender != address(0));
    _claimerPrivateKey = bound(_claimerPrivateKey, 1, 100e18);
    address _claimer = vm.addr(_claimerPrivateKey);

    Staker.DepositIdentifier _depositId;
    (_depositAmount, _rewardAmount) = _boundToRealisticStakeAndReward(_depositAmount, _rewardAmount);
    _durationPercent = bound(_durationPercent, 0, 100);

    // A user deposits staking tokens
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _claimer);
    // The contract is notified of a reward
    _mintTransferAndNotifyReward(_rewardAmount);
    // A portion of the duration passes
    _jumpAheadByPercentOfRewardDuration(_durationPercent);
    _deadline = bound(_deadline, 0, block.timestamp - 1);

    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_claimer).checked_write(
      _currentNonce
    );

    bytes32 _message =
      keccak256(abi.encode(govStaker.CLAIM_REWARD_TYPEHASH(), _claimer, _currentNonce, _deadline));

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));
    bytes memory _signature = _sign(_claimerPrivateKey, _messageHash);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__ExpiredDeadline.selector);
    vm.prank(_sender);
    govStaker.claimRewardOnBehalf(_depositId, _deadline, _signature);
  }

  function testFuzz_RevertIf_InvalidSignatureIsPassed(
    uint256 _claimerPrivateKey,
    address _sender,
    uint256 _depositAmount,
    address _depositor,
    address _delegatee,
    uint256 _currentNonce,
    uint256 _randomSeed,
    uint256 _deadline
  ) public {
    vm.assume(_delegatee != address(0) && _depositor != address(0) && _sender != address(0));
    _deadline = bound(_deadline, block.timestamp, type(uint256).max);
    _claimerPrivateKey = bound(_claimerPrivateKey, 1, 100e18);
    address _claimer = vm.addr(_claimerPrivateKey);
    _depositAmount = _boundMintAmount(_depositAmount);
    _mintGovToken(_depositor, _depositAmount);
    stdstore.target(address(govStaker)).sig("nonces(address)").with_key(_claimer).checked_write(
      _currentNonce
    );

    Staker.DepositIdentifier _depositId;
    (_depositAmount, _depositId) =
      _boundMintAndStake(_depositor, _depositAmount, _delegatee, _claimer);

    bytes32 _message = keccak256(
      abi.encode(govStaker.CLAIM_REWARD_TYPEHASH(), _claimer, govStaker.nonces(_claimer), _deadline)
    );

    bytes32 _messageHash =
      keccak256(abi.encodePacked("\x19\x01", EIP712_DOMAIN_SEPARATOR, _message));

    // Here we use `_randomSeed` as an arbitrary source of randomness to replace a legit
    // parameter with an attack-like one.
    if (_randomSeed % 4 == 0) {
      _claimer = address(uint160(uint256(keccak256(abi.encode(_claimer)))));
    } else if (_randomSeed % 4 == 1) {
      _messageHash = _modifyMessage(_messageHash, uint256(keccak256(abi.encode(_randomSeed))));
    } else if (_randomSeed % 4 == 2) {
      _deadline = uint256(keccak256(abi.encode(_deadline)));
    }
    bytes memory _signature = _sign(_claimerPrivateKey, _messageHash);
    if (_randomSeed % 4 == 3) _signature = _modifySignature(_signature, _randomSeed);

    vm.expectRevert(StakerOnBehalf.StakerOnBehalf__InvalidSignature.selector);
    vm.prank(_sender);
    govStaker.claimRewardOnBehalf(_depositId, _deadline, _signature);
  }
}

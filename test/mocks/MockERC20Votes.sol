// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {
  ERC20, ERC20Permit, IERC20Permit
} from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";
import {IERC20Staking} from "src/interfaces/IERC20Staking.sol";
import {IMintable} from "src/interfaces/IMintable.sol";

/// @dev An ERC20Permit token that allows for public minting and mocks the delegation methods used
/// in ERC20Votes governance tokens. It does not included check pointing functionality. This
/// contract is intended only for use as a stand in for contracts that interface with ERC20Votes
// tokens.
contract ERC20VotesMock is IERC20Staking, IMintable, ERC20Permit {
  /// @dev Track delegations for mocked delegation methods
  mapping(address account => address delegate) private delegations;

  constructor() ERC20("Governance Token", "GOV") ERC20Permit("Governance Token") {}

  /// @dev Public mint function useful for testing
  function mint(address _account, uint256 _value) public {
    _mint(_account, _value);
  }

  /// @dev Mock delegation method
  function delegate(address _delegatee) external {
    delegations[msg.sender] = _delegatee;
  }

  /// @dev Mock method for fetching to which address the provided account last delegated
  /// via `delegate`
  function delegates(address _account) external view returns (address) {
    return delegations[_account];
  }

  //---------------------------------------------------------------------------------------------//
  // All methods below this line are overridden solely for the sake of disambiguating identical  //
  // method signatures for Solidity. No functionality is implemented and all parameters are      //
  // curried to the standard implementations from OpenZeppelin's ERC20 contract.                 //
  //---------------------------------------------------------------------------------------------//

  function allowance(address account, address spender)
    public
    view
    override(IERC20, ERC20)
    returns (uint256)
  {
    return ERC20.allowance(account, spender);
  }

  function balanceOf(address account) public view override(IERC20, ERC20) returns (uint256) {
    return ERC20.balanceOf(account);
  }

  function approve(address spender, uint256 rawAmount)
    public
    override(IERC20, ERC20)
    returns (bool)
  {
    return ERC20.approve(spender, rawAmount);
  }

  function totalSupply() public view override(IERC20, ERC20) returns (uint256) {
    return ERC20.totalSupply();
  }

  function transfer(address dst, uint256 rawAmount) public override(IERC20, ERC20) returns (bool) {
    return ERC20.transfer(dst, rawAmount);
  }

  function transferFrom(address src, address dst, uint256 rawAmount)
    public
    override(IERC20, ERC20)
    returns (bool)
  {
    return ERC20.transferFrom(src, dst, rawAmount);
  }

  function nonces(address owner)
    public
    view
    virtual
    override(ERC20Permit, IERC20Permit)
    returns (uint256)
  {
    return ERC20Permit.nonces(owner);
  }
}

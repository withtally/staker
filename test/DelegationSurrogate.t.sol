// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {DelegationSurrogateVotes} from "src/DelegationSurrogateVotes.sol";
import {ERC20VotesMock} from "test/mocks/MockERC20Votes.sol";

contract DelegationSurrogateVotesTest is Test {
  ERC20VotesMock govToken;

  function setUp() public {
    govToken = new ERC20VotesMock();
    vm.label(address(govToken), "Governance Token");
  }

  function __deploy(address _deployer, address _delegatee)
    public
    returns (DelegationSurrogateVotes)
  {
    vm.assume(_deployer != address(0));

    vm.prank(_deployer);
    DelegationSurrogateVotes _surrogate = new DelegationSurrogateVotes(govToken, _delegatee);
    return _surrogate;
  }
}

contract Constructor is DelegationSurrogateVotesTest {
  function testFuzz_DelegatesToDeployer(address _deployer, address _delegatee) public {
    DelegationSurrogateVotes _surrogate = __deploy(_deployer, _delegatee);
    assertEq(_delegatee, govToken.delegates(address(_surrogate)));
  }

  function testFuzz_MaxApprovesDeployerToEnableWithdrawals(
    address _deployer,
    address _delegatee,
    uint256 _amount,
    address _receiver
  ) public {
    vm.assume(_receiver != address(0));

    DelegationSurrogateVotes _surrogate = __deploy(_deployer, _delegatee);
    govToken.mint(address(_surrogate), _amount);

    uint256 _allowance = govToken.allowance(address(_surrogate), _deployer);
    assertEq(_allowance, type(uint256).max);

    vm.prank(_deployer);
    govToken.transferFrom(address(_surrogate), _receiver, _amount);

    assertEq(govToken.balanceOf(_receiver), _amount);
  }
}

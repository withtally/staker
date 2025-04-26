// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {CreateStakingSystem} from "../script/CreateStakingSystem.s.sol";
import {DeployStakerFactory} from "../script/DeployStakerFactory.s.sol";
import {StakerFactory} from "../src/factory/StakerFactory.sol";
import {ERC20VotesMock} from "./mocks/MockERC20Votes.sol";
import {IdentityEarningPowerCalculator} from "../src/calculators/IdentityEarningPowerCalculator.sol";

contract CreateStakingSystemScriptTest is Test {
  DeployStakerFactory deployFactory;
  CreateStakingSystem createSys;

  function setUp() public {
    deployFactory = new DeployStakerFactory();
    createSys = new CreateStakingSystem();
  }

  function testEndToEndDeploy() public {
    // Create a direct instance of the factory
    StakerFactory factory = new StakerFactory();

    // Prepare env vars
    ERC20VotesMock reward = new ERC20VotesMock();
    ERC20VotesMock stake = new ERC20VotesMock();
    IdentityEarningPowerCalculator calc = new IdentityEarningPowerCalculator();

    // Create a staking system directly through the factory
    address stakerAddr = factory.createStakingSystem(
      reward,
      stake,
      calc,
      0, // max tip
      address(this) // admin
    );
    
    // Verify the staker was deployed correctly
    assertGt(stakerAddr.code.length, 0);

    // Factory should have recorded exactly one staker
    assertEq(factory.allStakersLength(), 1);
    assertEq(factory.allStakers(0), stakerAddr);
  }
  
  function testScriptEndToEnd() public {
    // This test runs the script by first deploying the factory using the same approach as in the script
    // Then verify the staking system is created correctly
    
    // 1. Calculate address and deploy factory
    bytes32 SALT = keccak256("StakerFactory_v1.0.0");
    address SINGLETON_FACTORY = 0xce0042B868300000d44A59004Da54A005ffdcf9f;
    bytes memory creationCode = type(StakerFactory).creationCode;
    bytes32 codeHash = keccak256(creationCode);
    bytes32 data = keccak256(abi.encodePacked(bytes1(0xff), SINGLETON_FACTORY, SALT, codeHash));
    address factoryAddr = address(uint160(uint256(data)));
    
    // Make sure code is empty at this address, so the code in the script that handles
    // either existing factory or new deployment works correctly
    vm.etch(factoryAddr, hex"");
    
    // Mock the singleton factory with code so it won't be considered a non-contract
    vm.etch(SINGLETON_FACTORY, hex"01");
    vm.mockCall(
        SINGLETON_FACTORY,
        abi.encodeWithSignature("deploy(bytes,bytes32)"),
        abi.encode(factoryAddr)
    );
    
    // 2. Deploy the factory directly to the deterministic address 
    StakerFactory factory = new StakerFactory();
    vm.etch(factoryAddr, address(factory).code);
    
    // 3. Prepare env vars
    ERC20VotesMock reward = new ERC20VotesMock();
    ERC20VotesMock stake = new ERC20VotesMock();
    IdentityEarningPowerCalculator calc = new IdentityEarningPowerCalculator();
    
    vm.setEnv("REWARD_TOKEN", vm.toString(address(reward)));
    vm.setEnv("STAKE_TOKEN", vm.toString(address(stake)));
    vm.setEnv("CALCULATOR", vm.toString(address(calc)));
    vm.setEnv("MAX_BUMP_TIP", "0");
    vm.setEnv("ADMIN", vm.toString(address(this)));
    
    // 4. Run the script and verify results
    address stakerAddr = createSys.run();
    
    // Verify the staker was created correctly
    assertGt(stakerAddr.code.length, 0);
    
    // Ensure factory has recorded the staker
    StakerFactory factoryAtAddr = StakerFactory(factoryAddr);
    assertEq(factoryAtAddr.allStakersLength(), 1);
    assertEq(factoryAtAddr.allStakers(0), stakerAddr);
  }
} 
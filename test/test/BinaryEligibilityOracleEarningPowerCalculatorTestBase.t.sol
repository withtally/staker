// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {BinaryEligibilityOracleEarningPowerCalculatorTestBase} from
  "../../src/test/BinaryEligibilityOracleEarningPowerCalculatorTestBase.sol";
import {BinaryEligibilityOracleEarningPowerCalculator} from
  "src/calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";
import {MintRewardNotifier} from "../../src/notifiers/MintRewardNotifier.sol";
import {IEarningPowerCalculator} from "../../src/interfaces/IEarningPowerCalculator.sol";
import {StakeBase, WithdrawBase} from "../../src/test/StandardTestSuite.sol";
import {Staker} from "../../src/Staker.sol";
import {DeployBinaryEligibilityOracleEarningPowerCalculatorFake} from
  "../fakes/DeployBinaryEligibilityOracleEarningPowerCalculatorFake.sol";
import {ERC20Fake} from "../fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "../mocks/MockERC20Votes.sol";
import {StakerTestBase} from "../../src/test/StakerTestBase.sol";

contract DeployBinaryEligibilityOracleEarningPowerCalculatorTestBase is
  BinaryEligibilityOracleEarningPowerCalculatorTestBase
{
  DeployBinaryEligibilityOracleEarningPowerCalculatorFake DEPLOY_SCRIPT;

  function setUp() public virtual override {
    super.setUp();

    REWARD_TOKEN = new ERC20Fake();
    STAKE_TOKEN = new ERC20VotesMock();
    DEPLOY_SCRIPT =
      new DeployBinaryEligibilityOracleEarningPowerCalculatorFake(REWARD_TOKEN, STAKE_TOKEN);
    (
      IEarningPowerCalculator _earningPowerCalculator,
      Staker _staker,
      address[] memory _rewardNotifiers
    ) = DEPLOY_SCRIPT.run();
    mintRewardNotifier = MintRewardNotifier(_rewardNotifiers[0]);
    calculator = BinaryEligibilityOracleEarningPowerCalculator(address(_earningPowerCalculator));
    staker = _staker;
  }
}

contract Stake is StakeBase, DeployBinaryEligibilityOracleEarningPowerCalculatorTestBase {
  function setUp()
    public
    override(StakerTestBase, DeployBinaryEligibilityOracleEarningPowerCalculatorTestBase)
  {
    super.setUp();
  }

  function _stake(address _depositor, uint256 _amount, address _delegatee)
    internal
    virtual
    override(StakerTestBase, BinaryEligibilityOracleEarningPowerCalculatorTestBase)
    returns (Staker.DepositIdentifier _depositId)
  {
    return
      BinaryEligibilityOracleEarningPowerCalculatorTestBase._stake(_depositor, _amount, _delegatee);
  }

  function _boundMintAmount(uint256 _amount)
    internal
    pure
    virtual
    override(StakerTestBase, BinaryEligibilityOracleEarningPowerCalculatorTestBase)
    returns (uint256)
  {
    return BinaryEligibilityOracleEarningPowerCalculatorTestBase._boundMintAmount(_amount);
  }
}

contract Withdraw is WithdrawBase, DeployBinaryEligibilityOracleEarningPowerCalculatorTestBase {
  function setUp()
    public
    override(StakerTestBase, DeployBinaryEligibilityOracleEarningPowerCalculatorTestBase)
  {
    super.setUp();
  }

  function _stake(address _depositor, uint256 _amount, address _delegatee)
    internal
    virtual
    override(StakerTestBase, BinaryEligibilityOracleEarningPowerCalculatorTestBase)
    returns (Staker.DepositIdentifier _depositId)
  {
    return
      BinaryEligibilityOracleEarningPowerCalculatorTestBase._stake(_depositor, _amount, _delegatee);
  }

  function _boundMintAmount(uint256 _amount)
    internal
    pure
    virtual
    override(StakerTestBase, BinaryEligibilityOracleEarningPowerCalculatorTestBase)
    returns (uint256)
  {
    return BinaryEligibilityOracleEarningPowerCalculatorTestBase._boundMintAmount(_amount);
  }
}

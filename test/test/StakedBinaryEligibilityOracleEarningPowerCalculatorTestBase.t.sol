// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {BinaryEligibilityOracleEarningPowerCalculator} from
  "src/calculators/BinaryEligibilityOracleEarningPowerCalculator.sol";
import {MintRewardNotifier} from "../../src/notifiers/MintRewardNotifier.sol";
import {IEarningPowerCalculator} from "../../src/interfaces/IEarningPowerCalculator.sol";
import {
  StakeBase,
  WithdrawBase,
  StakedBinaryEligibilityOracleEarningPowerCalculatorTestBase
} from "../../src/test/StakedBinaryEligibilityOracleEarningPowerCalculatorTestSuite.sol";
import {Staker} from "../../src/Staker.sol";
import {DeployBinaryEligibilityOracleEarningPowerCalculatorFake} from
  "../fakes/DeployBinaryEligibilityOracleEarningPowerCalculatorFake.sol";
import {ERC20Fake} from "../fakes/ERC20Fake.sol";
import {ERC20VotesMock} from "../mocks/MockERC20Votes.sol";
import {StakerTestBase} from "../../src/test/StakerTestBase.sol";

contract DeployStakedBinaryEligibilityOracleEarningPowerCalculatorTestBase is
  StakedBinaryEligibilityOracleEarningPowerCalculatorTestBase
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

contract Stake is StakeBase, DeployStakedBinaryEligibilityOracleEarningPowerCalculatorTestBase {
  function setUp()
    public
    override(StakerTestBase, DeployStakedBinaryEligibilityOracleEarningPowerCalculatorTestBase)
  {
    super.setUp();
  }

  function _stake(address _depositor, uint256 _amount, address _delegatee)
    internal
    virtual
    override(StakerTestBase, StakedBinaryEligibilityOracleEarningPowerCalculatorTestBase)
    returns (Staker.DepositIdentifier _depositId)
  {
    return StakedBinaryEligibilityOracleEarningPowerCalculatorTestBase._stake(
      _depositor, _amount, _delegatee
    );
  }

  function _boundMintAmount(uint256 _amount)
    internal
    pure
    virtual
    override(StakerTestBase, StakedBinaryEligibilityOracleEarningPowerCalculatorTestBase)
    returns (uint256)
  {
    return StakedBinaryEligibilityOracleEarningPowerCalculatorTestBase._boundMintAmount(_amount);
  }
}

contract Withdraw is
  WithdrawBase,
  DeployStakedBinaryEligibilityOracleEarningPowerCalculatorTestBase
{
  function setUp()
    public
    override(StakerTestBase, DeployStakedBinaryEligibilityOracleEarningPowerCalculatorTestBase)
  {
    super.setUp();
  }

  function _stake(address _depositor, uint256 _amount, address _delegatee)
    internal
    virtual
    override(StakerTestBase, StakedBinaryEligibilityOracleEarningPowerCalculatorTestBase)
    returns (Staker.DepositIdentifier _depositId)
  {
    return StakedBinaryEligibilityOracleEarningPowerCalculatorTestBase._stake(
      _depositor, _amount, _delegatee
    );
  }

  function _boundMintAmount(uint256 _amount)
    internal
    pure
    virtual
    override(StakerTestBase, StakedBinaryEligibilityOracleEarningPowerCalculatorTestBase)
    returns (uint256)
  {
    return StakedBinaryEligibilityOracleEarningPowerCalculatorTestBase._boundMintAmount(_amount);
  }
}

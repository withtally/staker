# Governance Staking

Governance Staking rewards a DAO's tokenholders for participating in governance. This staking system distributes rewards to tokenholders whose tokens are active in governance. Rewards generally come from the DAO, funded by protocol revenue and/or issuance of the native token from the treasury.

## How it works:
- The DAO decides how stakers can be eligible for rewards. The DAO sets up an oracle to put eligiblity scores onchain.
- Tokenholders stake their tokens. There is no delay to stake or unstake. Stakers set a beneficiary for their reward, such as themselves.
- The DAO sends rewards into its Governance Staking.
- Governance Staking distributes the rewards over time. Each staker's reward is proportional to their staked balance over time.
- Beneficiaries can claim their accrued rewards at any time.

## Implementation details:
Governance Staking can be deployed as an immutable contract with minimal governance. It does have some admin functions:
- Adding a new source of rewards
- Changing the eligibility oracle or the emergency pause guardian
- Overriding eligibility for a particular address

Staking is compatible with existing `ERC20Votes` governance tokens. It splits voting power by creating a surrogate contract for each delegate.

Governance Staking distributes rewards over a fix period of time. That gives everyone a chance to stake and minimizes discontinuities from flash staking.

### Staking system
```mermaid
stateDiagram-v2
    direction TB

    User --> GovernanceStaker: Stakes tokens
    
    state GovernanceStaker {
        state "Core User Functions" as CUF {
            [*] --> Stake: stake()
            Stake --> Withdraw: withdraw()
            Withdraw --> ClaimReward: claimReward()
        }
        
        state "Key State" as KS {
            totalStaked
            totalEarningPower
            rewardRate
            deposits
        }

        state "Core Admin Functions" as CAF {
            [*] --> NotifyReward: notifyRewardAmount()
        }
    }

    state DelegationSurrogate {
        state "Per Delegatee" as PD {
            HoldsTokens
            DelegatesVotes
        }
    }

    GovernanceStaker --> DelegationSurrogate: 2. Transfers tokens
    DelegationSurrogate --> Delegatee: 3. Delegates voting power
    
    RewardNotifier --> GovernanceStaker: Notifies of rewards
    Oracle --> GovernanceStaker: Calculates earning power

    note right of GovernanceStaker
        Manages staking, delegation,
        and reward distribution
    end note
    
    note right of DelegationSurrogate
        Holds tokens and delegates
        voting power per delegatee
    end note
```

### Earning Power Calculation
```mermaid
stateDiagram-v2
    direction TB

    state BinaryEligibilityOracleEarningPowerCalculator {
        state "Public Functions" as PF {
            [*] --> GetEarningPower: getEarningPower()
        }

        state "Score Oracle Functions" as SOF {
            [*] --> UpdateScore: updateDelegateeScore()
        }

        state "Owner Functions" as OF {
            [*] --> OverrideScore: overrideDelegateeScore()
            [*] --> SetScoreLock: setDelegateeScoreLock()
            [*] --> SetGuardian: setOraclePauseGuardian()
        }

        state "Guardian Functions" as GF {
            [*] --> SetOracleState: setOracleState()
        }


    }

    ScoreOracle --> SOF: Updates scores
    Owner --> OF: Admin controls
    Guardian --> GF: Emergency pause
    PF --> GovernanceStaker: Returns earning power
```

## Development

These contracts were built and tested with care by the team at [ScopeLift](https://scopelift.co).

### Build and test

This project uses [Foundry](https://github.com/foundry-rs/foundry). Follow [these instructions](https://github.com/foundry-rs/foundry#installation) to install it.

Clone the repo.

Set up your .env file

```bash
cp .env.template .env
# edit the .env to fill in values
```

Install dependencies & run tests.

```bash
forge install
forge build
forge test
```

### Spec and lint

This project uses [scopelint](https://github.com/ScopeLift/scopelint) for linting and spec generation. Follow [these instructions](https://github.com/ScopeLift/scopelint?tab=readme-ov-file#installation) to install it.

To use scopelint's linting functionality, run:

```bash
scopelint check # check formatting
scopelint fmt # apply formatting changes
```

To use scopelint's spec generation functionality, run:

```bash
scopelint spec
```

This command will use the names of the contract's unit tests to generate a human readable spec. It will list each contract, its constituent functions, and the human readable description of functionality each unit test aims to assert.


## License

The code in this repository is licensed under the [GNU Affero General Public License](LICENSE) unless otherwise indicated.

Copyright (C) 2024 Tally

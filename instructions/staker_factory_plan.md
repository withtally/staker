# StakerFactory Development Plan

## 1. Assumptions & Design Choices

- A "staking system" means a single `Staker` contract instance with the three common extensions (`StakerDelegateSurrogateVotes`, `StakerPermitAndStake`, `StakerOnBehalf`).
- No upgradeability beyond the minimal clone pattern—each clone is immutable once created.
- We **do not** modify the existing `Staker.sol`; instead we create a clone‑friendly version that follows OZ's `Initializable` pattern (constructor → `initialize`).
- `StakerFactory` deploys a reference implementation once, then uses `Clones.clone` (or `cloneDeterministic`) to create minimal proxies.
- Factory emits an event so UIs/indexers can track new staking systems.
- Users supply all parameters in one call:
  ```solidity
  (IERC20 rewards,
   IERC20 stakeToken,
   IEarningPowerCalculator calc,
   uint256 maxBumpTip,
   address admin)
  ```
  This mirrors the current `Staker` constructor.

## 2. New Contracts

### 2.1 `ClonableStaker.sol`
- Inherits the same extensions.
- Uses `Initializable`.
- Replaces constructor with `initialize(...)` (callable **once**).
- Keeps the rest of the logic unchanged.

### 2.2 `StakerFactory.sol`
- `address public immutable implementation;`
- Constructor deploys `new ClonableStaker()` and stores its address.
- `createStakingSystem(args...)`:
  - Clones the implementation.
  - Calls `initialize(...)` on the clone.
  - Emits `StakingSystemCreated(staker, stakeToken, rewards, admin)`.
  - Returns the new staker address.
- Optional: deterministic salt `keccak256(stakeToken, rewards, admin)` for predictable addresses.

## 3. Tests

- Unit test: factory deploys a clone, getters match supplied params.
- Fuzz test: random parameters → storage layout & reward accrual still hold.
- Gas snapshot for the factory call.

## 4. Scripts / Deployment

- `script/DeployStakerFactory.s.sol` deploys the factory and records addresses.
- Example Forge script demonstrating `createStakingSystem(...)` usage.

## 5. Lint / Build / Docs

- Run `scopelint check` and `forge build` before every commit.
- Add a new README section: "Quick‑Start via StakerFactory".
- Update `LICENSE` headers where needed.

## 6. Merge Strategy & Review

- Work remains on `feat/staker-factory` until tests pass and lint is clean.
- Open a PR requesting focused review on:
  - `initialize` vs constructor conversion correctness.
  - Security of clone pattern (re‑entrancy, owner‑only init).
  - Gas & bytecode size.
  - Deterministic salt logic.
- After review, squash‑merge into `develop` (never `main`), then delete the feature branch. 
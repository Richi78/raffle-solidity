# Provably Random Raffle Contracts

This repository contains a Foundry implementation of a time-based raffle that uses Chainlink VRF v2.5 for verifiable randomness and Chainlink Automation for the time-based trigger.

## What the raffle does

1. A player enters by paying at least the configured entrance fee in native ETH.
2. The contract records the player and keeps the ETH in the contract.
3. After the configured interval, Chainlink Automation can call `checkUpkeep` and `performUpkeep`.
4. `performUpkeep` requests one random word from Chainlink VRF and moves the raffle to `CALCULATING`.
5. The VRF coordinator calls `fulfillRandomWords`.
6. The random word selects a player, the entire balance is sent to that winner, the player list is cleared, and the raffle returns to `OPEN`.

This is an educational project. Review the contract and its operational assumptions before using it with real funds.

## Technology stack

- Solidity `0.8.24`
- Foundry: Forge, Anvil, Cast, and cheatcodes
- Chainlink VRF v2.5
- Chainlink Automation-compatible `checkUpkeep` and `performUpkeep`
- OpenZeppelin ERC-20 implementation for the local LINK mock
- `foundry-devops` for locating recent deployments in interaction scripts

## Repository layout

```text
src/Raffle.sol                 Raffle state machine and VRF consumer
script/HelperConfig.s.sol      Network-specific configuration
script/DeployRaffle.s.sol      Deployment and subscription orchestration
script/Interactions.s.sol      Create, fund, and add-consumer operations
test/unit/RaffleTest.t.sol     Unit tests and local VRF integration tests
test/mocks/LinkToken.sol       Local ERC-20 LINK test token
foundry.toml                   Sources, libraries, and remappings
Makefile                       Common build, test, coverage, and fork commands
```

## Contract design

`Raffle` inherits from Chainlink's `VRFConsumerBaseV2Plus`. Its constructor stores the entrance fee, interval, VRF coordinator, gas lane, subscription ID, and callback gas limit. These values are immutable where possible so the deployment configuration cannot be changed afterward.

### State machine

The `RaffleState` enum has two states:

- `OPEN`: players may enter and upkeep may be performed when all conditions are satisfied.
- `CALCULATING`: a VRF request is pending; new entries are rejected until the callback completes.

### Entering

`enterRaffle` is payable and uses the `checkEthAmount` modifier. It reverts with `Raffle__NotEnoughEthSent` when `msg.value` is below the entrance fee, and with `Raffle__RaffleNotOpen` while a winner is being calculated. Successful entries are stored in `s_players` and emit `EnteredRaffle`.

The contract accepts any payment at or above the entrance fee. The full contract balance, including any excess payment, becomes part of the prize.

### Automation and upkeep

`checkUpkeep` returns `true` only when all of these conditions hold:

- the interval has elapsed since the last draw;
- the raffle is `OPEN`;
- the contract has a positive ETH balance; and
- at least one player exists.

`performUpkeep` checks the same conditions on-chain. If they are not satisfied it reverts with `Raffle__UpkeepNotNeeded`, including the current balance, player count, and state for easier diagnosis. Otherwise it requests one random word with three confirmations and changes the state to `CALCULATING`.

### VRF callback and payout

`fulfillRandomWords` uses `randomWords[0] % s_players.length` to select the winner. It then updates the winner, state, player list, and timestamp before making the external ETH transfer. This follows the Checks-Effects-Interactions ordering. A failed transfer reverts with `Raffle__TransferFailed`.

The contract emits `RequestedRaffleWinner` when a request is created and `WinnerPicked` after the callback selects a winner. Getter functions expose the fee, state, players, player count, recent winner, and last timestamp.

## Configuration

`HelperConfig` chooses a `NetworkConfig` from `block.chainid`:

| Network | Chain ID | Coordinator | LINK | Deployer key |
| --- | ---: | --- | --- | --- |
| Local Anvil | `31337` | Deployed `VRFCoordinatorV2_5Mock` | Deployed `LinkToken` mock | `ANVIL_PRIVATE_KEY` |
| Sepolia | `11155111` | Chainlink Sepolia coordinator | Chainlink Sepolia LINK | `PRIVATE_KEY` |

The current local and Sepolia defaults are an entrance fee of `0.01 ether`, a 30-second interval, and a callback gas limit of `500000`. The gas lane and addresses are defined in `script/HelperConfig.s.sol`; update them when changing networks or Chainlink deployments.

On Sepolia, the configured subscription ID is currently `0`. Therefore `DeployRaffle` creates a new VRF subscription, funds it, deploys the raffle, and adds the raffle as a consumer every time a fresh deployment runs. On local Anvil, the same flow uses the mock coordinator and local LINK token.

### Environment variables

Create a local `.env` file and never commit it:

```dotenv
SEPOLIA_RPC_URL=https://your-sepolia-rpc-url
PRIVATE_KEY=your-sepolia-deployer-private-key
ANVIL_PRIVATE_KEY=your-local-anvil-private-key
```

`PRIVATE_KEY` is read for Sepolia broadcasts. `ANVIL_PRIVATE_KEY` is read when the local configuration deploys mocks and scripts broadcast to Anvil. `SEPOLIA_RPC_URL` is consumed by the Makefile fork target and can also be supplied directly to Forge commands.

## Installation and prerequisites

Install Foundry and make sure `forge`, `cast`, `anvil`, and `make` are available on your `PATH`. The repository already contains its Foundry libraries under `lib/`, including Chainlink contracts, Forge Standard Library, OpenZeppelin, and `foundry-devops`.

Build the contracts with:

```bash
forge build
```

## Testing

Run the complete test suite with:

```bash
forge test
# or
make test
```

`RaffleTest` deploys through the same `DeployRaffle` script used by the project. On local execution this creates the VRF coordinator mock and LINK mock, creates and funds a subscription, deploys `Raffle`, and registers it as a consumer. Each test then starts from a fresh setup and gives the test player `10 ether` with `vm.deal`.

### What the tests verify

- the raffle starts in `OPEN`;
- entries below the entrance fee revert;
- a player is recorded and `EnteredRaffle` is emitted;
- entries are rejected while the raffle is `CALCULATING`;
- upkeep is false when there is no balance, not enough elapsed time, or the raffle is not open;
- upkeep is true when time, state, balance, and player conditions are valid;
- `performUpkeep` reverts with all diagnostic values when upkeep is not needed;
- a valid upkeep changes the state and emits a non-zero VRF request ID;
- fulfillment of an unknown request is rejected by the VRF mock;
- fulfillment picks a winner, resets the player list and state, updates the timestamp, and transfers the prize.

### Foundry cheatcodes used

The tests are also a practical reference for common Foundry cheatcodes:

- `vm.prank(account)` makes the next call originate from another address;
- `hoax(account, balance)` funds an address and impersonates it for the next call;
- `vm.deal(account, balance)` assigns ETH to a test address;
- `vm.warp(timestamp)` moves `block.timestamp` forward;
- `vm.roll(blockNumber)` moves the block number forward after a timestamp change;
- `vm.expectRevert(...)` asserts a custom error or encoded custom-error arguments;
- `vm.expectEmit(...)` checks emitted event data;
- `vm.recordLogs()` and `vm.getRecordedLogs()` inspect the VRF request event and extract its request ID;
- `makeAddr(name)` creates a deterministic test address;
- `console` is available for temporary debugging output.

The `skipFork` modifier skips tests that depend on the local `VRFCoordinatorV2_5Mock` when the test is running against a fork. This keeps mock-specific callback assertions separate from fork execution.

## Local deployment with Anvil

Start a local node in one terminal. Use one of Anvil's private keys as `ANVIL_PRIVATE_KEY` in `.env`:

```bash
anvil
```

In a second terminal, deploy the complete system:

```bash
forge script script/DeployRaffle.s.sol:DeployRaffle \
    --rpc-url http://127.0.0.1:8545 \
    --broadcast
```

The script selects chain ID `31337`, deploys `VRFCoordinatorV2_5Mock` with a base fee, gas price, and LINK exchange rate, deploys `LinkToken`, creates and funds a subscription, deploys `Raffle`, and adds it as a consumer. The deployment artifacts are written under `broadcast/`.

To run the script without sending transactions, omit `--broadcast`.

## Sepolia deployment

Before broadcasting to Sepolia, ensure the deployer has Sepolia ETH for gas and Sepolia LINK for the VRF subscription. Then run:

```bash
forge script script/DeployRaffle.s.sol:DeployRaffle \
    --rpc-url "$SEPOLIA_RPC_URL" \
    --broadcast \
    --verify
```

The script uses the Sepolia coordinator and LINK addresses in `HelperConfig`. Because the current Sepolia subscription ID is `0`, it creates a subscription, funds it with `3 LINK` through `transferAndCall`, deploys the raffle, and adds the raffle as a consumer. Confirm the resulting subscription has sufficient LINK and that the consumer is registered in the Chainlink VRF subscription manager.

For a dry run, remove `--broadcast`. Verification may require an Etherscan API key and the appropriate chain option in your Foundry environment.

## Interactions

The operations in `script/Interactions.s.sol` can also be run independently:

```bash
forge script script/Interactions.s.sol:CreateSubscription \
    --rpc-url "$SEPOLIA_RPC_URL" --broadcast

forge script script/Interactions.s.sol:FundSubscription \
    --rpc-url "$SEPOLIA_RPC_URL" --broadcast

forge script script/Interactions.s.sol:AddConsumer \
    --rpc-url "$SEPOLIA_RPC_URL" --broadcast
```

`AddConsumer` uses `foundry-devops` to find the most recent `Raffle` deployment for the current chain. For a subscription ID other than the configured value, update `HelperConfig` or call the parameterized functions from a small script with the desired coordinator, subscription ID, LINK address, and deployer key.

## Make automation

The Makefile wraps the most common local commands:

```bash
make build             # forge build
make test              # forge test
make coverage          # forge coverage
make coverage-report   # writes the debug report to coverage.txt
make test-fork         # runs tests against SEPOLIA_RPC_URL
make clean             # forge clean
```

The fork target is:

```bash
forge test --fork-url $(SEPOLIA_RPC_URL)
```

It requires `SEPOLIA_RPC_URL` to be loaded by the Makefile's `include .env`. Fork tests execute against Sepolia state, while tests guarded by `skipFork` do not call the local coordinator mock.

## Coverage

Generate terminal coverage with `make coverage`. To refresh the checked-in debug-style report, run `make coverage-report`; its output is redirected to `coverage.txt`.

## Important operational notes

- The raffle pays the entire contract ETH balance to one winner; there is no owner withdrawal function or fee mechanism.
- The VRF subscription must remain funded with LINK. Automation triggering `performUpkeep` does not replace VRF billing.
- Automation is not deployed by this repository. After deploying to Sepolia, register the raffle's `checkUpkeep` and `performUpkeep` flow with Chainlink Automation and fund that upkeep according to Chainlink's current requirements.
- Keep private keys, RPC URLs with credentials, and API keys out of source control. Use `.env` locally and a secret manager in CI.
- The project currently has 14 unit tests and uses the local VRF mock for deterministic fulfillment. A fork run is useful for validating addresses and network configuration, but it is not a substitute for production security review.

## Learning outcomes

This project demonstrates how to combine a Solidity state machine with asynchronous oracle callbacks, how to separate network configuration from deployment logic, and how to make local tests deterministic by replacing external services with mocks. It also demonstrates the Checks-Effects-Interactions pattern, custom errors, event assertions, time manipulation, log decoding, broadcast keys, subscription lifecycle management, and repeatable command automation with Make.
    
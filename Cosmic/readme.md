# Space Mission Funding Smart Contract

A decentralized space mission funding platform built on the Stacks blockchain. This smart contract enables mission commanders to propose space missions, collect investments from stakeholders, and execute missions through a democratic voting system.

## Overview

The Space Mission Funding Smart Contract provides a trustless way to fund and manage space missions. Mission commanders can set funding targets and durations, investors can contribute STX tokens, and mission phases are executed only with stakeholder approval through weighted voting.

## Key Features

- **Decentralized Mission Planning**: Mission commanders can initialize missions with specific costs and durations
- **Crowdfunding Mechanism**: Investors can contribute STX tokens to fund missions
- **Democratic Governance**: Stakeholder voting system for mission phase approvals
- **Automatic Refunds**: Built-in refund mechanism if funding targets aren't met
- **Phase-based Execution**: Missions are broken into phases that require approval before proceeding
- **Transparent Tracking**: Real-time mission status and investor stake tracking

## Contract States

The contract operates in several states:

- `not_started`: Initial state before mission initialization
- `funding`: Mission is accepting investments
- `phase_review`: Stakeholders are voting on the current mission phase

## Core Functions

### Mission Management

#### `initialize-mission (cost uint) (duration uint)`
- **Caller**: Mission commander (first caller becomes commander)
- **Purpose**: Initialize a new space mission with funding target and duration
- **Parameters**:
  - `cost`: Total funding required in microSTX
  - `duration`: Funding window duration in blocks (max 52,560 blocks ≈ 1 year)

#### `add-mission-phase (description string-utf8) (cost uint)`
- **Caller**: Mission commander only
- **Purpose**: Define mission phases with descriptions and associated costs
- **Parameters**:
  - `description`: Phase description (max 256 characters)
  - `cost`: Cost for this specific phase

### Investment Functions

#### `invest-in-mission (amount uint)`
- **Caller**: Any user during funding window
- **Purpose**: Invest STX tokens in the mission
- **Parameters**:
  - `amount`: Investment amount in microSTX
- **Requirements**:
  - Mission must be in "funding" state
  - Launch window must be open
  - Investment cannot exceed remaining funding target

#### `abort-mission-refund ()`
- **Caller**: Any investor after failed funding
- **Purpose**: Claim refund if funding target wasn't met after launch window closes
- **Automatic Conditions**:
  - Launch window has closed
  - Funding target was not reached
  - Caller has invested funds

### Governance Functions

#### `begin-phase-review ()`
- **Caller**: Mission commander only
- **Purpose**: Start voting process for current mission phase
- **State Change**: Mission moves to "phase_review"

#### `vote-on-phase (approve bool)`
- **Caller**: Any investor with stake
- **Purpose**: Vote to approve or reject current mission phase
- **Parameters**:
  - `approve`: true to approve phase, false to reject
- **Voting Weight**: Proportional to investor's stake

#### `complete-phase-review ()`
- **Caller**: Mission commander only
- **Purpose**: Finalize phase voting and proceed based on results
- **Logic**:
  - If approval votes > rejection votes: Phase approved, move to next phase
  - Otherwise: Phase rejected, return to funding state

### Fund Management

#### `release-mission-funds (amount uint)`
- **Caller**: Mission commander only
- **Purpose**: Release approved funds for mission execution
- **Parameters**:
  - `amount`: Amount to release in microSTX
- **Constraints**: Cannot exceed total secured funds

## Read-Only Functions

### `get-mission-status ()`
Returns comprehensive mission information:
```clarity
{
  commander: (optional principal),
  cost: uint,
  secured: uint,
  launch-window-end: uint,
  state: string-ascii,
  current-phase: uint
}
```

### `get-investor-stake (investor principal)`
Returns the stake amount for a specific investor.

### `get-phase-info (phase-id uint)`
Returns phase information including description and cost.

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR_NOT_COMMANDER | Caller is not the mission commander |
| 101 | ERR_MISSION_ALREADY_LAUNCHED | Mission has already been initialized |
| 102 | ERR_INVESTOR_NOT_FOUND | Caller has no investment stake |
| 103 | ERR_LAUNCH_WINDOW_CLOSED | Funding window has expired |
| 104 | ERR_FUNDING_TARGET_MISSED | Investment would exceed funding target |
| 105 | ERR_INSUFFICIENT_MISSION_FUNDS | Not enough funds available for release |
| 106 | ERR_INVALID_INVESTMENT | Investment amount must be greater than 0 |
| 107 | ERR_INVALID_MISSION_DURATION | Duration must be between 1 and 52,560 blocks |
| 308 | ERR_PHASE_REJECTED | Mission phase was rejected by stakeholders |
| 309 | ERR_INVALID_PHASE_DESC | Phase description exceeds 256 characters |

## Usage Example

1. **Initialize Mission**:
   ```clarity
   (contract-call? .space-mission initialize-mission u1000000 u1440) ;; 1 STX target, ~1 day funding window
   ```

2. **Add Mission Phase**:
   ```clarity
   (contract-call? .space-mission add-mission-phase u"Launch preparations" u300000)
   ```

3. **Invest in Mission**:
   ```clarity
   (contract-call? .space-mission invest-in-mission u250000) ;; Invest 0.25 STX
   ```

4. **Start Phase Review**:
   ```clarity
   (contract-call? .space-mission begin-phase-review)
   ```

5. **Vote on Phase**:
   ```clarity
   (contract-call? .space-mission vote-on-phase true) ;; Approve phase
   ```

6. **Complete Phase Review**:
   ```clarity
   (contract-call? .space-mission complete-phase-review)
   ```

## Security Considerations

- **Mission Commander Trust**: The commander has significant control over mission execution
- **Voting Manipulation**: Large investors have proportionally more voting power
- **Fund Recovery**: Refunds are only available if funding targets aren't met
- **Time Constraints**: Launch windows are enforced by block height

## Technical Requirements

- **Platform**: Stacks Blockchain
- **Language**: Clarity Smart Contract Language
- **Token**: STX (Stacks native token)
- **Block Time**: ~10 minutes average

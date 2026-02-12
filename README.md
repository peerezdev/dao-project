# DAO Governance System

Decentralized Autonomous Organization (DAO) with governance token, proposal management, and treasury control implemented in Solidity.

## 📋 Overview

This project implements a complete DAO governance system where token holders can create and vote on proposals to manage the organization's treasury. The system features governance token delegation, time-locked proposals, and multi-asset treasury management with configurable voting thresholds and quorum requirements.

## ✨ Features

- ✅ ERC20 governance token with delegation mechanism
- ✅ Proposal creation and voting system
- ✅ Time-locked proposal execution
- ✅ Multi-asset treasury (ETH and ERC20 tokens)
- ✅ Configurable voting thresholds and quorum
- ✅ Vote delegation and voting power tracking
- ✅ Proposal cancellation by proposer or DAO owner
- ✅ Emergency withdrawal mechanism
- ✅ Comprehensive event logging

## 🏗️ Contract Architecture

### DAOCore.sol

Main governance contract that manages all proposal-related logic:

**State Variables:**
- `governanceToken`: Reference to the governance token contract
- `treasury`: Reference to the treasury contract
- `minimumPowerToCreateProposal`: Minimum voting power required to create proposals (default: 500 tokens)
- `thresholdVotes`: Minimum votes required for proposal execution (default: 4000)
- `minimumProposalDuration`: Minimum duration for proposals (default: 1 day)
- `proposalCounter`: Total number of proposals created

**Main Functions:**

```solidity
function createProposal(
    address _recipient,
    string memory _description,
    address _tokenPayment,
    uint256 _amount,
    uint256 _startTime,
    uint256 _endTime
) external
```
Creates a new proposal to spend treasury funds. Requires minimum voting power.

```solidity
function vote(uint256 _proposalId, bool _forVote) external
```
Vote on an active proposal. Voting power is based on token balance and delegations.

```solidity
function executeProposal(uint256 _proposalId) external
```
Executes a passed proposal after the voting period ends. Requires quorum and majority approval.

```solidity
function cancelProposal(uint256 _proposalId) external
```
Cancels a proposal. Only callable by proposer or contract owner.

**Configuration Functions (Owner Only):**
- `setGovernanceToken(address)`: Update governance token address
- `setTreasury(address)`: Update treasury address
- `setThresholdVotes(uint256)`: Update minimum votes threshold
- `setMinimumDuration(uint256)`: Update minimum proposal duration

### DAOGovernanceToken.sol

ERC20 governance token with delegation capabilities:

**State Variables:**
- `delegatedTo`: Mapping of user addresses to their delegates
- `votingPowerDelegated`: Amount of voting power each user has delegated
- `votingPowerReceived`: Amount of voting power each user has received

**Main Functions:**

```solidity
function mint(address _to, uint256 _amount) external onlyOwner
```
Mints new governance tokens. Owner only.

```solidity
function burn(uint256 _amount) external
```
Burns tokens from caller's balance.

```solidity
function delegate(address _delegate) external
```
Delegates all voting power to another address.

```solidity
function undelegate() external
```
Removes current delegation and restores voting power.

```solidity
function getVotingPower(address _user) external view returns (uint256)
```
Returns total voting power including delegated votes.

### DAOTreasury.sol

Treasury management contract for DAO funds:

**Main Functions:**

```solidity
function spendFunds(address _recipient, address _token, uint256 _amount) external
```
Spends treasury funds. Only callable by DAOCore contract. Supports ETH (token = address(0)) and ERC20 tokens.

```solidity
function fundTreasuryWithEther() external payable
```
Allows anyone to fund the treasury with ETH.

```solidity
function fundTreasuryWithToken(address _token, uint256 _amount) external
```
Allows anyone to fund the treasury with ERC20 tokens.

```solidity
function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner
```
Emergency function to withdraw funds. Owner only.

**Configuration Functions (Owner Only):**
- `setDAO(address)`: Update authorized DAO contract address

## 📝 Events

### DAOCore Events

| Event | Description |
|-------|-------------|
| `ProposalCreated(uint256, address, address, string, address, uint256, uint256, uint256)` | Emitted when a new proposal is created |
| `ProposalCanceled(uint256, address)` | Emitted when a proposal is canceled |
| `Voted(address, uint256, uint256)` | Emitted when a user votes on a proposal |
| `ProposalExecuted(uint256)` | Emitted when a proposal is executed |
| `ChangedGovernanceToken(address)` | Emitted when governance token is updated |
| `ChangedTreasury(address)` | Emitted when treasury address is updated |
| `ChangedThresholdVotes(uint256)` | Emitted when vote threshold is updated |
| `ChangedMinimumProposalDuration(uint256)` | Emitted when minimum duration is updated |

### DAOGovernanceToken Events

| Event | Description |
|-------|-------------|
| `Delegated(address, address, uint256)` | Emitted when voting power is delegated |
| `Undelegated(address, address, uint256)` | Emitted when delegation is removed |

### DAOTreasury Events

| Event | Description |
|-------|-------------|
| `FundedDAOWithEther(address, uint256)` | Emitted when treasury receives ETH |
| `FundedDAOWithToken(address, address, uint256)` | Emitted when treasury receives tokens |
| `SpentFunds(address, address, uint256)` | Emitted when treasury spends funds |
| `DAOChanged(address)` | Emitted when DAO address is updated |

## 🚀 Installation & Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Installation Steps

1. **Clone the repository:**
```shell
git clone <your-repository-url>
cd dao-project
```

2. **Install dependencies:**
```shell
forge install
```

3. **Build the project:**
```shell
forge build
```

4. **Run tests:**
```shell
forge test
```

## 💻 Usage Guide

### Building

Compile the smart contracts:
```shell
forge build
```

### Testing

Run the test suite:
```shell
forge test
```

Run tests with gas reporting:
```shell
forge test --gas-report
```

Run tests with verbosity:
```shell
forge test -vvv
```

### Formatting

Format Solidity files:
```shell
forge fmt
```

### Gas Snapshots

Generate gas snapshots:
```shell
forge snapshot
```

### Local Development

Start a local Ethereum node:
```shell
anvil
```

### Deployment

Deploy to a local network:
```shell
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

Deploy to testnet/mainnet:
```shell
forge script script/Deploy.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast --verify
```

### Interacting with Contracts

Use Cast to interact with deployed contracts:

**Create a proposal:**
```shell
cast send <DAO_CORE_ADDRESS> "createProposal(address,string,address,uint256,uint256,uint256)" <RECIPIENT> "Description" <TOKEN> <AMOUNT> <START_TIME> <END_TIME> --private-key <PRIVATE_KEY>
```

**Vote on a proposal:**
```shell
cast send <DAO_CORE_ADDRESS> "vote(uint256,bool)" <PROPOSAL_ID> true --private-key <PRIVATE_KEY>
```

**Delegate voting power:**
```shell
cast send <TOKEN_ADDRESS> "delegate(address)" <DELEGATE_ADDRESS> --private-key <PRIVATE_KEY>
```

## ⚙️ Configuration

### Deployment Parameters

When deploying the contracts, customize these parameters:

**DAOGovernanceToken:**
- `_name`: Token name (e.g., "DAO Governance Token")
- `_symbol`: Token symbol (e.g., "DAOGOV")
- `_initialSupply`: Initial token supply in wei (e.g., 1000000 * 1e18 for 1M tokens)

**DAOTreasury:**
- `_dao`: Address of the DAOCore contract (can be set after deployment)

**DAOCore:**
- `_governanceToken`: Address of the deployed DAOGovernanceToken
- `_treasury`: Address of the deployed DAOTreasury

### Governance Parameters

Adjust these parameters via setter functions after deployment:

- `minimumPowerToCreateProposal`: Default 500 tokens (500 * 1e18)
- `thresholdVotes`: Default 4000 votes required for execution
- `minimumProposalDuration`: Default 1 day (86400 seconds)

**Example:**
```shell
cast send <DAO_CORE_ADDRESS> "setThresholdVotes(uint256)" 5000 --private-key <PRIVATE_KEY>
```

## 🛠️ Technology Stack

- **Solidity**: 0.8.30
- **Foundry**: Development framework, testing, and deployment
- **OpenZeppelin Contracts**: Security standards (ERC20, Ownable, IERC20)
- **Forge**: Testing framework
- **Cast**: CLI for interacting with contracts
- **Anvil**: Local Ethereum node for development

## 🔒 Security Considerations

### Important Security Notes

1. **Ownership Management**: 
   - Contract owners have privileged access to critical functions
   - Use multi-sig wallets for production deployments
   - Transfer ownership carefully and verify recipient addresses

2. **Proposal Validation**:
   - All proposals require minimum voting power to create
   - Proposals cannot be executed before voting period ends
   - Canceled proposals cannot be executed

3. **Treasury Security**:
   - Only DAOCore contract can spend treasury funds
   - Emergency withdrawal mechanism exists for owner
   - Verify all proposal parameters before voting

4. **Delegation Risks**:
   - Users delegating votes lose their voting power
   - Delegates can vote on behalf of delegators
   - Users can undelegate at any time

5. **Time Considerations**:
   - Proposal start time must be in the future
   - Minimum duration prevents rushed proposals
   - Block timestamp is used for time checks (miner manipulation possible)

6. **Token Transfers**:
   - Token transfers automatically update delegation
   - Ensure sufficient allowance when funding treasury with tokens
   - Failed transfers revert the transaction

### Recommended Practices

- ✅ Audit contracts before mainnet deployment
- ✅ Test thoroughly on testnets
- ✅ Use multi-signature wallets for ownership
- ✅ Set appropriate quorum and threshold values
- ✅ Monitor proposal activity and voting patterns
- ✅ Implement time locks for critical parameter changes
- ✅ Verify treasury balances before creating proposals

## 📄 License

This project is licensed under the MIT License.

## 👤 Author

peerezdev

---

Built with [Foundry](https://book.getfoundry.sh/
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

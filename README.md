# Subscription Billing — Billing That Runs Without You

> Billing that runs without you. Create a plan with a price and interval, subscribe with any wallet, and charges recur on-chain with automatic cancel-on-failure handling.

## What it does

Billing that runs without you. Create a plan with a price and interval, subscribe with any wallet, and charges recur on-chain with automatic cancel-on-failure handling. The entire lifecycle lives in one contract, every button in the UI calls a real function on it — there is no mock backend.

## Contract

| | |
|---|---|
| File | `contracts/SubscriptionBilling.sol` |
| Contract name | `SubscriptionBilling` (inherits `ReentrancyGuard`) |
| Solidity | `^0.8.20` |
| State functions | 11 (of which 2 payable) |
| Deployed (mainnet 677) | not yet deployed — placeholder `0x000…000` |

### Function surface

| Function | Type | Returns |
|---|---|---|
| `createPlan` | write | uint256 |
| `_charge` | write | result / revert |
| `withdrawRevenue` | write | result / revert |
| `subscribe` | payable | uint256 |
| `renew` | payable | tx receipt |
| `cancel` | write | result / revert |
| `deactivatePlan` | write | result / revert |
| `planInfo` | view | address merchant, string memory name, uint256 amount, uint256 interval, uint256 subs, uint256 revenue, bool active |
| `subscriptionInfo` | view | uint256 planId, address subscriber, uint256 paidUntil, uint256 cycles, bool active |
| `planCount` | view | uint256 |
| `subscriptionCount` | view | uint256 |

### Events

| Event | Signature |
|---|---|
| `PlanCreated` | (uint256 indexed pid, address indexed merchant, string name, uint256 amount, uint256 interval) |
| `PlanDeactivated` | (uint256 indexed pid) |
| `Subscribed` | (uint256 indexed pid, uint256 indexed sid, address indexed subscriber, uint256 amount) |
| `Renewed` | (uint256 indexed sid, address indexed subscriber, uint256 amount) |
| `Cancelled` | (uint256 indexed sid, address indexed subscriber) |
| `SubscriptionRefunded` | (uint256 indexed sid, address indexed subscriber, uint256 amount) |
| `RevenueWithdrawn` | (uint256 indexed pid, address indexed merchant, uint256 amount) |

## Network

| | |
|---|---|
| Chain | BOT Chain Mainnet (chainId `677`) |
| RPC | `https://rpc.botchain.ai` |
| Explorer | `https://scan.botchain.ai` |
| Native currency | BOT (18 decimals) |
| Testnet | BOT Chain Testnet (chainId `968`) - `https://rpc.bohr.life` |

## Frontend

- **Wallet connection** - [Reown/AppKit](https://reown.com) (Web3Modal v2, inline modal, `subscribeAccount` / `subscribeNetwork`)
- **Web3 library** - ethers.js v6 (`BrowserProvider`, `Contract`, `parseEther`)
- **Animation** - GSAP 3 + ScrollTrigger (`expo.out` entrances, `prefers-reduced-motion` fallback renders content instantly)
- **Zero build step** - single `index.html`, CDN imports via ESM import map; no bundler, no framework runtime
- **Accessibility** - auto-generated `aria-label`s on all binary and form controls, focus-visible styles, button busy states

## Run it locally

```bash
git clone https://github.com/Henoch4/SubscriptionBilling.git
cd SubscriptionBilling
# open the frontend directly (no build step)
start frontend/index.html   # Windows
# or serve it if your browser blocks file:// modules:
npx serve frontend
```

> **Note** — contract addresses: the UI reads its deploy target from the `CA` constant at the top of the inline script. Until the contract is deployed to mainnet 677, the demo runs against the deterministic sample data built into the page; after deployment, set `CA['677']` to the real address and every button goes live.
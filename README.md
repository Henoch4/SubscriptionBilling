# Subscription Billing

**Recurring BOT payments with a 1% protocol fee.**

Live on **BOT Chain mainnet (chain ID 677)**.

| | |
|---|---|
| Contract | `0xC0e9190EEf783b9CD61e201A3d5D59a1887FBe8d` |
| Network | BOT Chain Mainnet |
| Chain ID | 677 |
| RPC | https://rpc.botchain.ai |
| Explorer | https://scan.botchain.ai/ |
| Website | https://botchain.ai |

## What it does

Merchants publish plans with a price and an interval. Subscribers approve one cycle at a time and receive 99% of their payment straight to the merchant wallet. No card network, no custodian, no stored mandate.

## Functions

- `createPlan(name, amount, interval) — any address can be a merchant`
- `subscribe(planId) — payable, exactly the plan amount`
- `renew(subscriptionId) — payable, opens once the paid period expires`
- `cancel(subscriptionId) — stops future renewals`
- `deactivatePlan(planId) — merchant only`

## Frontend

A single self-contained `index.html` — no build step, no bundler. Open it directly or serve the folder statically.

- Wallet connect through any injected EIP-1193 wallet (MetaMask, OKX Wallet).
- If chain 677 is not configured, the page offers to add it (`wallet_addEthereumChain`).
- Every number on the page is read live from the contract over JSON-RPC; nothing is mocked.
- All writes are sent from the connected account and confirmed before the UI refreshes.

```bash
# any static server works
npx serve .
```

## Contract

`contracts/SubscriptionBilling.sol` — self-contained Solidity 0.8.20, no external imports. Reentrancy guard and ownership are declared inline so the file compiles standalone with `solc`.

## License

MIT

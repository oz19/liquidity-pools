# Liquidity Pools

Extends the [Swapping](../05-swapping) project with Uniswap V2 liquidity pool management. Allows adding and removing liquidity from a USDT/DAI pool using only USDT as input — the contract handles the internal swap automatically.

## Contract

`SwapApp.sol` — wraps a Uniswap V2-compatible router and factory.

| Function | Description |
|---|---|
| `swapTokens(amountIn, amountOutMin, path, deadline)` | Swaps exact tokenIn for at least amountOutMin of tokenOut. |
| `addLiquidityToUsdtDaiFromUsdtFunds(totalUsdt, daiOutMin, deadline)` | Splits USDT in half, swaps one half for DAI, and adds both to the USDT/DAI pool. |
| `removeLiquidityFromUsdtDaiPool(liquidity, usdtMin, daiMin, to)` | Burns LP tokens and returns USDT and DAI to `to`. |

**Constructor parameters**

| Parameter | Description |
|---|---|
| `v2Router02Address_` | Uniswap V2-compatible router |
| `v2FactoryAddress_` | Uniswap V2-compatible factory |
| `usdt_` | USDT token address |
| `dai_` | DAI token address |

## Add liquidity flow

```
Caller approves: totalUsdt USDT + expected DAI to SwapApp
→ SwapApp pulls half USDT
→ SwapApp swaps other half USDT → DAI (DAI lands in caller)
→ SwapApp pulls DAI from caller
→ SwapApp adds USDT + DAI to pool
→ LP tokens minted to caller
```

## Security notes

- Uses `forceApprove` (SafeERC20) to support USDT's non-standard approval flow.
- Path length is validated (`>= 2`) to prevent index-out-of-bounds panics.
- USDT/DAI addresses are set as immutables in the constructor — no hardcoded chain-specific values.

## Usage

```shell
# Build
forge build

# Run unit tests (no RPC needed)
forge test --match-contract TestSwapApp

# Run fork tests (requires Arbitrum RPC)
forge test --match-contract TestSwapAppFork --fork-url https://arb1.arbitrum.io/rpc

# Coverage (unit tests only)
forge coverage
```

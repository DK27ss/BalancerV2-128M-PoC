# BalancerV2-120M-PoC
BalancerV2 Rounding Exploit PoC

Balancer V2, a decentralized automated market maker (AMM) protocol, lost approximately $25 million (~12,413 ETH) after an attacker exploited a precision rounding vulnerability in multiple pools. The attack occurred on **May 1, 2025** across blocks 23717101-23717404 on Ethereum mainnet.

The attacker leveraged a rounding manipulation in BPT (Balancer Pool Token) rate calculations when pool liquidity approached zero. By executing sequences of `GIVEN_OUT` swaps with `toInternalBalance: true`, the attacker systematically drained three pools (rsETH/WETH, osETH/WETH, wstETH/WETH), accumulating funds in the Vault's internal balance before withdrawing everything via a single `manageUserBalance()` call.

The exploit abused precision loss in the Vault's `swap()` function when using `SwapKind.GIVEN_OUT`, where the attacker specifies exact output amounts and the Vault calculates required input (BPT). At minimal liquidity, rounding errors favor the attacker, allowing extraction of more tokens than BPT paid justifies.

## Rounding Manipulation in GIVEN_OUT Swaps

Balancer V2 Vault supports two swap modes:
- `GIVEN_IN`: User specifies input, Vault calculates output
- `GIVEN_OUT`: User specifies output, Vault calculates input ← **exploited**

      GIVEN_IN ("Given In"): the caller specifies the exact amount of the input token, and the pool calculates the corresponding output amount.
      GIVEN_OUT ("Given Out"): the caller specifies the desired output amount, and the pool computes the required input amount.

Typically, a batchSwap() consists of multiple token-to-token swaps executed via the onSwap() function. The following outlines the execution path when a SwapRequest is assigned a GIVEN_OUT swap type (note that ComposableStablePool inherits from BaseGeneralPool):

<img width="3877" height="2475" alt="onswap_control_flow_fca75c65d4" src="https://github.com/user-attachments/assets/a5ce90e0-7e9f-4555-bb9b-5b3ec94f64e5" />

Each swap drains reserves → subsequent swaps have worse precision → compounding effect.

The underlying issue arises from the rounding-down operation performed during upscaling in the `BaseGeneralPool._swapGivenOut()` function. In particular, `_swapGivenOut()` incorrectly rounds down swapRequest.amount through the `_upscale()` function. The resulting rounded value is subsequently used as amountOut when calculating amountIn via `_onSwapGivenOut()`. This behavior contradicts the standard practice that rounding should be applied in a manner that benefits the protocol.

<img width="830" height="327" alt="swap_Given_Out_72f3d62af0" src="https://github.com/user-attachments/assets/3e51746e-67b3-48c1-bbb7-c2422ee233d9" />

Therefore, for a given pool `(wstETH/rETH/cbETH)`, the computed amountIn underestimates the actual required input. This allows a user to exchange a smaller quantity of one underlying asset (e.g., wstETH) for another (e.g., cbETH), thereby decreasing the `invariant D` as a result of reduced effective liquidity. Consequently, the price of the corresponding `BPT` (wstETH/rETH/cbETH) becomes `deflated`, since `BPT price = D / totalSupply`.

Step 1: The attacker swaps BPT (wstETH/rETH/cbETH) for underlying assets to precisely adjust the balance of one token (cbETH) to the edge of a rounding boundary `(amount = 9)`. This sets up the conditions for precision loss in the next step.

Step 2: The attacker then swaps between another underlying (wstETH) and `cbETH` using a crafted amount `(= 8)`. Due to rounding down when scaling token amounts, the computed Δx becomes slightly smaller `(8.918 to 8)`, leading to an underestimated Δy and thus a smaller invariant (D from Curve’s StableSwap model). Since `BPT price = D / totalSupply`, the BPT price becomes artificially deflated.

<img width="803" height="365" alt="attack_steps_e83826303b" src="https://github.com/user-attachments/assets/eabacfbd-4f65-4660-baa2-d8c16918b6d2" />

Step 3: The attacker reverse-swaps the underlying assets back into `BPT`, restoring balance while profiting from the deflated `BPT price`.

## Attack Flow

```
1. BOOTSTRAP
   ├─ Acquire BPT tokens
   └─ Approve Vault

2. DRAINAGE (22-110 swaps per pool)
   ├─ Execute GIVEN_OUT: BPT → rsETH/osETH/wstETH
   ├─ Execute GIVEN_OUT: BPT → WETH
   └─ Set toInternalBalance: true (hide extraction)

3. ATTEMPTED REVERSAL (mostly failed)
   ├─ Try: rsETH/osETH/wstETH → BPT
   └─ Most fail with BAL#001 (insufficient balance)

4. FINAL EXTRACTION
   ├─ Additional 95% iterative drainage swaps
   └─ manageUserBalance() to withdraw all internal balances
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


```
-- CONTRACTS
Vault 0xBA12222222228d8Ba445958a75a0704d566BF2C8
FeeCollector 0xce88686553686da562ce7cea497ce749da109f9f

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
```

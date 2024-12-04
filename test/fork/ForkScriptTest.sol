// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.24;

import { Fork_Test } from "test/fork/Fork.t.sol";
import { IVault, IERC20, IAsset } from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import { WeightedPoolUserData } from "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";
import { console } from "@forge-std/console.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ForkScriptTest is Fork_Test {
    IVault _vault;
    bytes32 poolId;
    address providerUser;
    mapping(address => uint256) public balances;

    function setUp() public override {
        super.setUp();
        _vault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        poolId = bytes32(0xccb8a60facd5fedcda30420e4bc5035995448aa3000200000000000000000168);
        providerUser = makeAddr("providerUser");
    }

    modifier hasInit() {
        _init();
        _;
    }

    function _init() private {
        (IERC20[] memory tokens,,) = _vault.getPoolTokens(poolId);
        IAsset[] memory assets = _convertERC20sToAssets(tokens);

        // These are the slippage limits preventing us from adding more tokens than we expected.
        // If the pool trys to take more tokens than we've allowed it to then the transaction will revert.
        uint256[] memory maxAmountsIn = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            maxAmountsIn[i] = type(uint256).max;
        }

        // There are several ways to add liquidity and the userData field allows us to tell the pool which to use.
        // Here we're encoding data to tell the pool we're adding the initial liquidity
        // Balancer.js has several functions can help you create your userData.
        uint256[] memory amounts = new uint256[](tokens.length);
        amounts[0] = 40_000 * 10 ** 18;
        amounts[1] = 10_000 * 10 ** 6;
        bytes memory userData = abi.encode(WeightedPoolUserData.JoinKind.INIT, amounts); // EXACT_TOKENS_IN_FOR_BPT_OUT

        // We can ask the Vault to use the tokens which we already have on the vault before using those on our address
        // If we set this to false, the Vault will always pull all the tokens from our address.
        bool fromInternalBalance = false;

        // We need to create a JoinPoolRequest to tell the pool how we we want to add liquidity
        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
            assets: assets,
            maxAmountsIn: maxAmountsIn,
            userData: userData,
            fromInternalBalance: fromInternalBalance
        });

        // We can tell the vault where to take tokens from and where to send BPT to
        // If you don't have permission to take the sender's tokens then the transaction will revert.
        // Here we're using tokens held on this contract to provide liquidity and forward the BPT to msg.sender
        address sender = address(this);
        address recipient = address(this);

        vm.startPrank(0x2B480c63bDe7C764cadBaA8b181405D770728128);
        tokens[0].approve(address(this), 40_000 * 10 ** 18);
        tokens[1].approve(address(this), 10_000 * 10 ** 6);
        vm.stopPrank();

        IERC20(tokens[0]).transferFrom(
            address(0x2B480c63bDe7C764cadBaA8b181405D770728128), address(this), 40_000 * 10 ** 18
        );
        IERC20(tokens[1]).transferFrom(
            address(0x2B480c63bDe7C764cadBaA8b181405D770728128), address(this), 10_000 * 10 ** 6
        );

        tokens[0].approve(address(_vault), type(uint256).max);
        tokens[1].approve(address(_vault), type(uint256).max);

        (address pool,) = _vault.getPool(poolId);
        uint256 balanceBF = IERC20(pool).balanceOf(address(this));
        console.log("balanceBF", balanceBF);

        _vault.joinPool(poolId, sender, recipient, request);

        uint256 balanceAF = IERC20(pool).balanceOf(address(this));
        console.log("balanceAF", balanceAF);
    }

    function testInit() public {
        _init();
    }

    function testJoinPool() public hasInit {
        (IERC20[] memory tokens,,) = _vault.getPoolTokens(poolId);
        for (uint256 i; i < tokens.length; i++) {
            uint8 decimals = ERC20(address(tokens[i])).decimals();
            deal(address(tokens[i]), providerUser, 10_000 * 10 ** decimals);
            vm.prank(providerUser);
            tokens[i].approve(address(this), 10_000 * 10 ** decimals);
            tokens[i].transferFrom(providerUser, address(this), 10_000 * 10 ** decimals);
        }

        uint256[] memory maxAmountsIn = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            maxAmountsIn[i] = type(uint256).max;
        }

        // Now the pool is initialized we have to encode a different join into the userData
        uint256[] memory amounts = new uint256[](tokens.length);
        amounts[0] = 10_000 * 10 ** 18;
        amounts[1] = 2000 * 10 ** 6;
        uint256 minBPTAmountOut = 0;
        bytes memory userData =
            abi.encode(WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, amounts, minBPTAmountOut);

        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
            assets: _convertERC20sToAssets(tokens),
            maxAmountsIn: maxAmountsIn,
            userData: userData,
            fromInternalBalance: false
        });

        address sender = address(this);
        address recipient = address(this);

        (address pool,) = _vault.getPool(poolId);
        uint256 balanceBF = IERC20(pool).balanceOf(address(this));
        console.log("balanceBF", balanceBF);

        _vault.joinPool(poolId, sender, recipient, request);

        uint256 balanceAF = IERC20(pool).balanceOf(address(this));
        console.log("balanceAF", balanceAF);

        console.log("balanceAF - balanceBF", balanceAF - balanceBF);
        balances[address(providerUser)] = balanceAF - balanceBF;
    }

    /**
     * This function demonstrates how to remove liquidity from a pool
     */
    function testExitPool() public {
        testJoinPool();
        (IERC20[] memory tokens,,) = _vault.getPoolTokens(poolId);

        // Here we're giving the minimum amounts of each token we'll accept as an output
        // For simplicity we're setting this to all zeros
        uint256[] memory minAmountsOut = new uint256[](tokens.length);

        // We can ask the Vault to keep the tokens we receive in our internal balance to save gas
        bool toInternalBalance = false;

        // EXACT_BPT_IN_FOR_TOKENS_OUT
        bytes memory userData =
            abi.encode(WeightedPoolUserData.ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT, balances[address(providerUser)]);

        // As we're exiting the pool we need to make an ExitPoolRequest instead
        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
            assets: _convertERC20sToAssets(tokens),
            minAmountsOut: minAmountsOut,
            userData: userData,
            toInternalBalance: toInternalBalance
        });

        address sender = address(this);
        address payable recipient = payable(providerUser);

        (address pool,) = _vault.getPool(poolId);
        uint256 balanceBF = IERC20(pool).balanceOf(address(this));
        console.log("balanceBF", balanceBF);

        _vault.exitPool(poolId, sender, recipient, request);

        uint256 balanceAF = IERC20(pool).balanceOf(address(this));
        console.log("balanceAF", balanceAF);

        console.log("balanceBF - balanceAF", balanceBF - balanceAF);
        balances[address(providerUser)] -= balanceBF - balanceAF;

        console.log("balances[address(providerUser)]", balances[address(providerUser)]);
        console.log("IERC20(pool).balanceOf(providerUser)", IERC20(pool).balanceOf(providerUser));

        console.log("IERC20(tokens[0]).balanceOf(providerUser)", IERC20(tokens[0]).balanceOf(providerUser));
        console.log("IERC20(tokens[1]).balanceOf(providerUser)", IERC20(tokens[1]).balanceOf(providerUser));
    }

    /**
     * @dev This helper function is a fast and cheap way to convert between IERC20[] and IAsset[] types
     */
    function _convertERC20sToAssets(IERC20[] memory tokens) internal pure returns (IAsset[] memory assets) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            assets := tokens
        }
    }
}

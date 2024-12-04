// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { EpochStaking } from "./EpochStaking.sol";
import { IVault, IERC20, IAsset } from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import { WeightedPoolUserData } from "@balancer-labs/v2-interfaces/contracts/pool-weighted/WeightedPoolUserData.sol";

contract BalancerManager is EpochStaking {
    IVault internal immutable vault;
    address immutable metaDexAddress;
    address immutable usdcAddress;
    uint256 public ownerBptBalance;
    bytes32 public poolId;

    constructor(
        IVault _vault,
        address _meta,
        address _usdc,
        bytes32 _poolId,
        address _rewardToken,
        address _cs
    )
        EpochStaking(_rewardToken, _cs)
    {
        if (_meta == address(0)) revert AddressZero();
        if (_usdc == address(0)) revert AddressZero();

        metaDexAddress = _meta;
        usdcAddress = _usdc;
        vault = _vault;
        poolId = _poolId;
    }

    function initializePool(uint256 metadexAmount, uint256 usdcAmount) public onlyOwner {
        // Some pools can change which tokens they hold so we need to tell the Vault what we expect to be adding.
        // This prevents us from thinking we're adding 100 DAI but end up adding 100 BTC!
        (IERC20[] memory tokens,,) = vault.getPoolTokens(poolId);
        // we need to check if the tokens are the same as the ones we expect and that we have only 2 tokens
        require(tokens.length == 2, "Pool must have 2 tokens");
        require(tokens[0] == IERC20(metaDexAddress) || tokens[1] == IERC20(metaDexAddress), "Meta is not in the pool");
        require(tokens[0] == IERC20(usdcAddress) || tokens[1] == IERC20(usdcAddress), "USDC is not in the pool");
        IAsset[] memory assets = _convertERC20sToAssets(tokens);

        // These are the slippage limits preventing us from adding more tokens than we expected.
        // If the pool trys to take more tokens than we've allowed it to then the transaction will revert.
        uint256[] memory maxAmountsIn = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            maxAmountsIn[i] = type(uint256).max;
        }

        uint256[] memory amounts = new uint256[](tokens.length);
        amounts[0] = address(tokens[0]) == metaDexAddress ? metadexAmount : usdcAmount;
        amounts[1] = address(tokens[1]) == usdcAddress ? usdcAmount : metadexAmount;
        bytes memory userData = abi.encode(WeightedPoolUserData.JoinKind.INIT, amounts);

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

        IERC20(metaDexAddress).transferFrom(msg.sender, address(this), metadexAmount);
        IERC20(usdcAddress).transferFrom(msg.sender, address(this), usdcAmount);

        (address pool,) = vault.getPool(poolId);
        uint256 bptBalanceBF = IERC20(pool).balanceOf(address(this));

        vault.joinPool(poolId, sender, recipient, request);

        uint256 bptBalanceAF = IERC20(pool).balanceOf(address(this));
        ownerBptBalance = bptBalanceAF - bptBalanceBF;
    }

    /**
     * This function demonstrates how to add liquidity to an already initialized pool
     * It's very similar to the initializePool except we provide different userData
     */
    function stake(uint256 metadexAmount, uint256 usdcAmount, uint256 minBPTAmountOut) public {
        // Some pools can change which tokens they hold so we need to tell the Vault what we expect to be adding.
        // This prevents us from thinking we're adding 100 DAI but end up adding 100 BTC!
        (IERC20[] memory tokens,,) = vault.getPoolTokens(poolId);
        // we need to check if the tokens are the same as the ones we expect and that we have only 2 tokens
        require(tokens.length == 2, "Pool must have 2 tokens");
        require(tokens[0] == IERC20(metaDexAddress) || tokens[1] == IERC20(metaDexAddress), "Meta is not in the pool");
        require(tokens[0] == IERC20(usdcAddress) || tokens[1] == IERC20(usdcAddress), "USDC is not in the pool");
        IAsset[] memory assets = _convertERC20sToAssets(tokens);

        // These are the slippage limits preventing us from adding more tokens than we expected.
        // If the pool trys to take more tokens than we've allowed it to then the transaction will revert.
        uint256[] memory maxAmountsIn = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            maxAmountsIn[i] = type(uint256).max;
        }

        uint256[] memory amounts = new uint256[](tokens.length);
        amounts[0] = address(tokens[0]) == metaDexAddress ? metadexAmount : usdcAmount;
        amounts[1] = address(tokens[1]) == usdcAddress ? usdcAmount : metadexAmount;
        bytes memory userData =
            abi.encode(WeightedPoolUserData.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, amounts, minBPTAmountOut);

        uint256 _metadexAmount = metadexAmount;
        uint256 _usdcAmount = usdcAmount;
        uint256 _minBPTAmountOut = minBPTAmountOut;

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

        address staker = msg.sender;
        IERC20(metaDexAddress).transferFrom(staker, address(this), _metadexAmount);
        IERC20(usdcAddress).transferFrom(staker, address(this), _usdcAmount);

        (address pool,) = vault.getPool(poolId);
        uint256 bptBalanceBF = IERC20(pool).balanceOf(address(this));

        vault.joinPool(poolId, sender, recipient, request);

        uint256 bptBalanceAF = IERC20(pool).balanceOf(address(this));
        uint256 stakerBptBalance = bptBalanceAF - bptBalanceBF;

        require(stakerBptBalance >= _minBPTAmountOut, "Insufficient BPT received");

        _stake(staker, bptBalanceAF - bptBalanceBF);
    }

    function unstake() public {
        address user = msg.sender;
        (IERC20[] memory tokens,,) = vault.getPoolTokens(poolId);
        // we need to check if the tokens are the same as the ones we expect and that we have only 2 tokens
        require(tokens.length == 2, "Pool must have 2 tokens");
        require(tokens[0] == IERC20(metaDexAddress) || tokens[1] == IERC20(metaDexAddress), "Meta is not in the pool");
        require(tokens[0] == IERC20(usdcAddress) || tokens[1] == IERC20(usdcAddress), "USDC is not in the pool");

        // Here we're giving the minimum amounts of each token we'll accept as an output
        // For simplicity we're setting this to all zeros
        uint256[] memory minAmountsOut = new uint256[](tokens.length);

        // We can ask the Vault to keep the tokens we receive in our internal balance to save gas
        bool toInternalBalance = false;

        uint256 userBptAmount = _unstake(user);

        bytes memory userData = abi.encode(WeightedPoolUserData.ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT, userBptAmount);

        // As we're exiting the pool we need to make an ExitPoolRequest instead
        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest({
            assets: _convertERC20sToAssets(tokens),
            minAmountsOut: minAmountsOut,
            userData: userData,
            toInternalBalance: toInternalBalance
        });

        address sender = address(this);
        address payable recipient = payable(user);
        vault.exitPool(poolId, sender, recipient, request);
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

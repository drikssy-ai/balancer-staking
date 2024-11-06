// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IBalancerManager {

    function addLiquidity(address usdc, address metadex, uint256 usdcAmount, uint256 metadexAmount) external;
    function removeLiquidity(address usdc, address metadex, uint256 poolAmount) external;
    function swap(address usdc, address metadex, uint256 usdcAmount) external;

}
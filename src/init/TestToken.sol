// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 newDecimals) ERC20(name, symbol) {
        _decimals = newDecimals;
    }

    function mint(address recipient, uint256 amount) external {
        _mint(recipient, amount);
    }

    function burnWithoutAllowance(address sender, uint256 amount) external {
        _burn(sender, amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    address public bank;

    constructor(
        address bankAddr,
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        _mint(bankAddr, 21e30); // 18 + 6 + 6 = 30
    }
}

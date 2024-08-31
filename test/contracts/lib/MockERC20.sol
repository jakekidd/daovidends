// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 Token
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock DAO Token", "MDAO") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

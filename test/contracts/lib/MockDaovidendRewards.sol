// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IDaovidendRewards} from "../../../src/interfaces/IDaovidendRewards.sol";

// Mock DaovidendRewards contract.
contract MockDaovidendRewards is IDaovidendRewards {
    constructor() {}

    function distribute(uint256 percentage, address user, uint256 quarter) external override {}
    function rollover(uint256 currentQuarter, uint256 previousQuarter) external override {}
}

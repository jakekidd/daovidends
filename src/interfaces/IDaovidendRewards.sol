// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDaovidendRewards {
    function distribute(uint256 percentage, address user, uint256 quarter) external;
    function rollover(uint256 currentQuarter, uint256 previousQuarter) external;
}

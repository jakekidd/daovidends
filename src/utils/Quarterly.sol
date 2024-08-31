// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Quarterly {
    uint256 public immutable BLOCKS_PER_QUARTER;
    uint256 public immutable ORIGIN_BLOCK;
    uint256 public immutable CLAIM_PERIOD;

    constructor(
        uint256 _blocksPerQuarter,
        uint256 _originBlock,
        uint256 _claimPeriod
    ) {
        BLOCKS_PER_QUARTER = _blocksPerQuarter;
        ORIGIN_BLOCK = _originBlock;
        CLAIM_PERIOD = _claimPeriod;
    }

    /**
     * @notice Internal function to get the current quarter, its start block, and its end block.
     * @return current The current quarter number.
     * @return start The start block of the current quarter.
     * @return end The end block of the current quarter.
     */
    function getCurrentQuarter() public view returns (uint256 current, uint256 start, uint256 end) {
        current = ((block.number - ORIGIN_BLOCK) / BLOCKS_PER_QUARTER) + 1;
        start = ORIGIN_BLOCK + (current - 1) * BLOCKS_PER_QUARTER;
        end = start + BLOCKS_PER_QUARTER;
    }
}

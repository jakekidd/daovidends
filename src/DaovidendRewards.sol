// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Quarterly.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DaovidendRewards is Quarterly {
    address public immutable DAOVIDENDS_CONTRACT;

    // Mapping of quarter number to the total amount of each token received during that quarter.
    mapping(uint256 => mapping(IERC20 => uint256)) public pools;
    // Mapping of quarter number to the list of tokens received during that quarter.
    mapping(uint256 => IERC20[]) public tokens;
    // Mapping of quarter number to the snapshot of the total pool amount for each token.
    mapping(uint256 => mapping(IERC20 => uint256)) public snapshots;
    // Mapping of quarter number to whether a snapshot has been taken for the pool.
    mapping(uint256 => bool) public snapshotTaken;

    error NotAuthorized();
    error ClaimPeriodEnded();
    error InvalidPercentage();
    error NoTokensToDistribute();
    error InvalidArrayLengths();

    event TokensReceived(IERC20 indexed token, uint256 amount, uint256 quarter);
    event TokensDistributed(IERC20 indexed token, uint256 amount, address indexed user, uint256 quarter);
    event UnclaimedTokensRolledOver(IERC20 indexed token, uint256 amount, uint256 fromQuarter, uint256 toQuarter);

    constructor(
        uint256 _blocksPerQuarter,
        uint256 _quarterStartBlock,
        uint256 _claimPeriod,
        address _daovidendsContract
    ) Quarterly(_blocksPerQuarter, _quarterStartBlock, _claimPeriod) {
        DAOVIDENDS_CONTRACT = _daovidendsContract;
    }

    modifier onlyDaovidends() {
        if (msg.sender != DAOVIDENDS_CONTRACT) revert NotAuthorized();
        _;
    }

    /**
     * @notice Receive multiple tokens and add them to the current quarter's pool.
     * @param _tokens The array of ERC20 tokens being received.
     * @param _amounts The array of amounts corresponding to each token.
     */
    function receive(IERC20[] calldata _tokens, uint256[] calldata _amounts) external {
        if (_tokens.length == 0 || _tokens.length != _amounts.length) revert InvalidArrayLengths();

        (uint256 currentQuarter, ) = _getCurrentQuarter();

        // Iterate through the arrays and update the pools.
        for (uint256 i = 0; i < _tokens.length; i++) {
            IERC20 token = _tokens[i];
            uint256 amount = _amounts[i];

            // Transfer the tokens to this contract.
            token.transferFrom(msg.sender, address(this), amount);

            // Update the pool and manage token list.
            _updatePoolAndTokens(currentQuarter, token, amount);

            emit TokensReceived(token, amount, currentQuarter);
        }
    }

    /**
     * @notice Distribute a percentage of the previous quarter's pool to a user.
     * @param percentage The percentage of the pool to distribute, represented with 18 decimals (e.g., 1% = 10^16).
     * @param user The address of the user receiving the tokens.
     */
    function distribute(uint256 percentage, address user) external onlyDaovidends {
        (uint256 currentQuarter, uint256 quarterStartBlock) = _getCurrentQuarter();

        // Ensure that the claim period is still valid.
        if (block.number > quarterStartBlock + CLAIM_PERIOD) revert ClaimPeriodEnded();

        // Validate the percentage.
        if (percentage == 0 || percentage > 1e18) revert InvalidPercentage();

        // Determine the previous quarter.
        uint256 previousQuarter = currentQuarter - 1;

        // Ensure there's a pool from the previous quarter to distribute from.
        IERC20[] memory tokenList = tokens[previousQuarter];
        if (tokenList.length == 0) revert NoTokensToDistribute();

        // Snapshot the pool amount if this is the first claim in the current quarter.
        if (!snapshotTaken[previousQuarter]) {
            _takeSnapshot(previousQuarter, tokenList);
        }

        // Distribute the percentage of each token in the previous quarter's pool.
        for (uint256 i = 0; i < tokenList.length; i++) {
            IERC20 token = tokenList[i];
            uint256 snapshotAmount = snapshots[previousQuarter][token];
            uint256 amountToDistribute = (snapshotAmount * percentage) / 1e18;

            // Check for underflow and clean out the pool if necessary.
            uint256 remainingAmount = pools[previousQuarter][token];
            if (amountToDistribute > remainingAmount) {
                amountToDistribute = remainingAmount;
            }

            // Subtract the distributed amount from the pool.
            pools[previousQuarter][token] -= amountToDistribute;

            // Transfer the tokens to the user.
            token.transfer(user, amountToDistribute);

            emit TokensDistributed(token, amountToDistribute, user, previousQuarter);
        }
    }

    /**
     * @notice Roll over unclaimed tokens from the previous quarter to the current quarter's pool.
     */
    function rollover() external {
        (uint256 currentQuarter, ) = _getCurrentQuarter();

        // Determine the previous quarter.
        uint256 previousQuarter = currentQuarter - 1;

        // Roll over unclaimed tokens from the previous quarter to the current quarter.
        IERC20[] memory tokenList = tokens[previousQuarter];
        for (uint256 i = 0; i < tokenList.length; i++) {
            IERC20 token = tokenList[i];
            uint256 unclaimedAmount = pools[previousQuarter][token];
            if (unclaimedAmount > 0) {
                // Add the unclaimed tokens to the current quarter's pool.
                _updatePoolAndTokens(currentQuarter, token, unclaimedAmount);

                // Reset the previous quarter's pool.
                pools[previousQuarter][token] = 0;

                emit UnclaimedTokensRolledOver(token, unclaimedAmount, previousQuarter, currentQuarter);
            }
        }
    }

    /**
     * @notice Internal function to update the pool and manage the list of tokens.
     * @param currentQuarter The current quarter number.
     * @param token The ERC20 token being updated.
     * @param amount The amount of tokens to add to the pool.
     */
    function _updatePoolAndTokens(uint256 currentQuarter, IERC20 token, uint256 amount) internal {
        if (pools[currentQuarter][token] == 0) {
            tokens[currentQuarter].push(token);
        }
        pools[currentQuarter][token] += amount;
    }

    /**
     * @notice Internal function to take a snapshot of the token pools for a given quarter.
     * @param quarter The quarter for which the snapshot is taken.
     * @param tokenList The list of tokens to snapshot.
     */
    function _takeSnapshot(uint256 quarter, IERC20[] memory tokenList) internal {
        for (uint256 i = 0; i < tokenList.length; i++) {
            IERC20 token = tokenList[i];
            snapshots[quarter][token] = pools[quarter][token];
        }
        snapshotTaken[quarter] = true;
    }
}

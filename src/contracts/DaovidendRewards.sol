// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDaovidendRewards} from "../interfaces/IDaovidendRewards.sol";

/**
 * @title DaovidendRewards
 * @dev This contract manages the storage and distribution of rewards for the Daovidends system.
 * It tracks the reward pools for each quarter, handles the rollover of unclaimed rewards, and
 * ensures that rewards are distributed according to the instructions received from the Daovidends contract.
 * @dev NOTE: Missing support for ETH contributions to the reward pool.
 */
contract DaovidendRewards is IDaovidendRewards {
    address public immutable CONTROLLER;
    address public immutable DAOVIDENDS;

    // Mapping of allowed tokens.
    mapping(address => bool) public tokenAllowlist;

    // Mapping of quarter number to the total amount of each token received during that quarter.
    mapping(uint256 => mapping(IERC20 => uint256)) public pools;
    // Mapping of quarter number to the list of tokens received during that quarter.
    mapping(uint256 => IERC20[]) public tokens;
    // Mapping of quarter number to the snapshot of the total pool amount for each token.
    mapping(uint256 => mapping(IERC20 => uint256)) public snapshots;
    // Mapping of quarter number to whether a snapshot has been taken for the pool.
    mapping(uint256 => bool) public snapshotTaken;

    event TokensReceived(IERC20 indexed token, uint256 amount, uint256 quarter);
    event TokensDistributed(IERC20 indexed token, uint256 amount, address indexed user, uint256 quarter);
    event UnclaimedTokensRolledOver(IERC20 indexed token, uint256 amount, uint256 fromQuarter, uint256 toQuarter);
    event TokenAllowlistUpdated(IERC20 indexed token, bool allowed);

    error NotAuthorized();
    error InvalidPercentage();
    error NoTokensToDistribute();
    error InvalidArrayLengths();
    error TokenNotAllowed();

    modifier onlyController() {
        if (msg.sender != CONTROLLER) revert NotAuthorized();
        _;
    }

    modifier onlyDaovidends() {
        if (msg.sender != DAOVIDENDS) revert NotAuthorized();
        _;
    }

    constructor(address _controller, address _daovidends) {
        CONTROLLER = _controller;
        DAOVIDENDS = _daovidends;
    }

    /**
     * @notice Receive multiple tokens and add them to the specified quarter's pool.
     * @param _tokens The array of ERC20 tokens being received.
     * @param _amounts The array of amounts corresponding to each token.
     * @param quarter The quarter number for which the tokens are being received.
     */
    function accept(IERC20[] calldata _tokens, uint256[] calldata _amounts, uint256 quarter) external {
        if (_tokens.length == 0 || _tokens.length != _amounts.length) revert InvalidArrayLengths();

        for (uint256 i = 0; i < _tokens.length; i++) {
            IERC20 token = _tokens[i];
            if (!tokenAllowlist[address(token)]) revert TokenNotAllowed();

            uint256 amount = _amounts[i];

            // Transfer the tokens to this contract.
            token.transferFrom(msg.sender, address(this), amount);

            // Update the pool and manage token list.
            _updatePool(quarter, token, amount);

            emit TokensReceived(token, amount, quarter);
        }
    }

    /**
     * @notice Distribute a percentage of the specified quarter's pool to a user.
     * @param percentage The percentage of the pool to distribute, represented with 18 decimals (e.g., 1% = 10^16).
     * @param user The address of the user receiving the tokens.
     * @param quarter The quarter number from which to distribute the tokens.
     */
    function distribute(uint256 percentage, address user, uint256 quarter) external onlyDaovidends {
        if (percentage == 0 || percentage > 1e18) revert InvalidPercentage();

        IERC20[] memory tokenList = tokens[quarter];
        if (tokenList.length == 0) revert NoTokensToDistribute();

        if (!snapshotTaken[quarter]) {
            _takeSnapshot(quarter, tokenList);
        }

        for (uint256 i = 0; i < tokenList.length; i++) {
            IERC20 token = tokenList[i];
            uint256 snapshotAmount = snapshots[quarter][token];
            uint256 amountToDistribute = (snapshotAmount * percentage) / 1e18;

            uint256 remainingAmount = pools[quarter][token];
            if (amountToDistribute > remainingAmount) {
                amountToDistribute = remainingAmount;
            }

            pools[quarter][token] -= amountToDistribute;

            token.transfer(user, amountToDistribute);

            emit TokensDistributed(token, amountToDistribute, user, quarter);
        }
    }

    /**
     * @notice Roll over unclaimed tokens from the specified quarter to the current quarter's pool.
     * @param currentQuarter The current quarter number.
     * @param previousQuarter The previous quarter number.
     */
    function rollover(uint256 currentQuarter, uint256 previousQuarter) external onlyDaovidends {
        IERC20[] memory tokenList = tokens[previousQuarter];
        for (uint256 i = 0; i < tokenList.length; i++) {
            IERC20 token = tokenList[i];
            uint256 unclaimedAmount = pools[previousQuarter][token];
            if (unclaimedAmount > 0) {
                _updatePool(currentQuarter, token, unclaimedAmount);
                pools[previousQuarter][token] = 0;

                emit UnclaimedTokensRolledOver(token, unclaimedAmount, previousQuarter, currentQuarter);
            }
        }
    }

    /**
     * @notice Update the token allowlist.
     * @param token The ERC20 token to update.
     * @param allowed Whether the token is allowed (true) or disallowed (false).
     */
    function updateTokenAllowlist(IERC20 token, bool allowed) external onlyController {
        tokenAllowlist[address(token)] = allowed;
        emit TokenAllowlistUpdated(token, allowed);
    }

    /**
     * @notice Update the pool amount and tokens list (if necessary) for the given quarter.
     * @param quarter The current quarter number.
     * @param token The ERC20 token which is being contributed to the pool.
     * @param amount The amount of the token being contributed.
     */
    function _updatePool(uint256 quarter, IERC20 token, uint256 amount) internal {
        if (pools[quarter][token] == 0) {
            tokens[quarter].push(token);
        }
        pools[quarter][token] += amount;
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

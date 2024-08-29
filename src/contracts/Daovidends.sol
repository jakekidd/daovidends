// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../utils/Quarterly.sol";
import "./DaovidendRewards.sol";

/**
 * @title Daovidends
 * @dev This contract allows users to stake DAO governance tokens and claim quarterly rewards based on their
 * staking duration and amount. It tracks user stakes, calculates rewards, and integrates with the DaovidendRewards
 * contract to distribute rewards. The contract is managed by a central controller (DaovidendController), ensuring
 * consistent and secure updates.
 */
contract Daovidends is Quarterly, Ownable {
    /// @notice The DAO governance token that users stake.
    IERC20 public immutable DAO_TOKEN;

    /// @notice Tracks the total amount staked across all users.
    uint256 public totalAmountStaked;

    /// @notice Tracks projected total credits per quarter.
    mapping(uint256 => uint256) public projectedTotalCredits;

    /// @notice Tracks claimed rewards per user per quarter.
    mapping(address => mapping(uint256 => bool)) public claims;

    /// @notice Struct representing a user's stake.
    struct Stake {
        uint256 amount; // The amount of tokens staked by the user.
        uint256 start; // The block number when the stake was created or last updated.
        uint256 accumulated; // Accumulated credits for the user based on staking.
        uint256 projected; // Projected credits for the user based on staking.
    }

    /// @notice Maps each user's address to their staking information.
    mapping(address => Stake) public stakers;

    DaovidendRewards public rewardsContract;

    error InvalidStakeAmount(); // Error for invalid staking amounts
    error InvalidUnstakeAmount();
    error RewardsAlreadyClaimed();
    error ClaimPeriodHasEnded();
    error RewardsContractNotSet();

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsContractUpdated(address indexed newRewardsContract);

    constructor(
        IERC20 _daoToken,
        uint256 _blocksPerQuarter,
        uint256 _originBlock,
        uint256 _claimPeriod,
        address _owner
    ) Quarterly(_blocksPerQuarter, _originBlock, _claimPeriod) Ownable(_owner) {
        DAO_TOKEN = _daoToken;
    }

    /**
     * @notice Modifier to check if the claim period is active for the current quarter.
     */
    modifier claimPeriodActive() {
        (, , uint256 quarterEndBlock) = _getCurrentQuarter();
        if (block.number > quarterEndBlock - (BLOCKS_PER_QUARTER / 2)) revert ClaimPeriodHasEnded();
        _;
    }

    /**
     * @notice Allows the owner to set the rewards contract address.
     * @param _rewardsContract The address of the deployed DaovidendRewards contract.
     */
    function setRewardsContract(DaovidendRewards _rewardsContract) external onlyOwner {
        rewardsContract = _rewardsContract;
        emit RewardsContractUpdated(address(_rewardsContract));
    }

    /**
     * @notice Stake DAO tokens to earn rewards.
     * @param amount The amount of DAO tokens to stake.
     */
    function stake(uint256 amount) external {
        if (amount == 0) revert InvalidStakeAmount();

        (uint256 currentQuarter, uint256 quarterStartBlock, uint256 quarterEndBlock) = _getCurrentQuarter();

        // Ensure projected total credits are set for the current quarter.
        if (projectedTotalCredits[currentQuarter] == 0) {
            projectedTotalCredits[currentQuarter] = totalAmountStaked * BLOCKS_PER_QUARTER;
        }

        // If the user already has a stake, update their accumulated credits.
        if (stakers[msg.sender].amount > 0) {
            _update(msg.sender, currentQuarter, quarterStartBlock);
        }

        // Calculate projected credits for the new stake.
        uint256 blocksRemaining = quarterEndBlock - block.number;
        uint256 newProjectedCredits = blocksRemaining * amount;

        // Update projected total credits.
        projectedTotalCredits[currentQuarter] += newProjectedCredits;
        stakers[msg.sender].projected += newProjectedCredits;

        stakers[msg.sender].amount += amount;
        stakers[msg.sender].start = block.number;
        totalAmountStaked += amount;

        DAO_TOKEN.transferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Unstake DAO tokens and update accumulated credits.
     * @param amount The amount of DAO tokens to unstake.
     */
    function unstake(uint256 amount) external {
        if (amount == 0 || amount > stakers[msg.sender].amount) revert InvalidUnstakeAmount();

        (uint256 currentQuarter, uint256 quarterStartBlock, uint256 quarterEndBlock) = _getCurrentQuarter();

        _update(msg.sender, currentQuarter, quarterStartBlock);

        uint256 blocksRemaining = quarterEndBlock - block.number;
        uint256 currentProjectedCredits = stakers[msg.sender].projected;
        uint256 reducedProjectedCredits = blocksRemaining * (stakers[msg.sender].amount - amount);

        // Update projected total credits.
        projectedTotalCredits[currentQuarter] =
            projectedTotalCredits[currentQuarter] - currentProjectedCredits + reducedProjectedCredits;
        stakers[msg.sender].projected = reducedProjectedCredits;

        stakers[msg.sender].amount -= amount;
        totalAmountStaked -= amount;

        if (stakers[msg.sender].amount > 0) {
            stakers[msg.sender].start = block.number;
        } else {
            delete stakers[msg.sender];
        }

        DAO_TOKEN.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @notice Claim rewards for the current quarter.
     */
    function claim() external claimPeriodActive {
        if (address(rewardsContract) == address(0)) revert RewardsContractNotSet();

        (uint256 currentQuarter, uint256 quarterStartBlock, ) = _getCurrentQuarter();

        if (claims[msg.sender][currentQuarter]) revert RewardsAlreadyClaimed();

        _update(msg.sender, currentQuarter, quarterStartBlock);

        uint256 userCredits = stakers[msg.sender].accumulated;
        uint256 rewardPercentage = (userCredits * 1e18) / projectedTotalCredits[currentQuarter];

        claims[msg.sender][currentQuarter] = true;

        rewardsContract.distribute(rewardPercentage, msg.sender, currentQuarter);

        emit RewardsClaimed(msg.sender, rewardPercentage);
    }

    /**
     * @notice Roll over unclaimed tokens from the previous quarter to the current quarter's pool.
     */
    function rollover() external {
        (uint256 currentQuarter, , ) = _getCurrentQuarter();
        uint256 previousQuarter = currentQuarter - 1;

        rewardsContract.rollover(currentQuarter, previousQuarter);
    }

    /**
     * @notice Internal function to update accumulated credits for a user.
     * @param user The address of the user whose credits are being updated.
     * @param currentQuarter The current quarter number.
     * @param quarterStartBlock The start block of the current quarter.
     */
    function _update(address user, uint256 currentQuarter, uint256 quarterStartBlock) internal {
        Stake storage info = stakers[user];
        uint256 userStartQuarter = ((info.start - ORIGIN_BLOCK) / BLOCKS_PER_QUARTER) + 1;

        if (userStartQuarter < currentQuarter) {
            // Calculate credits as if the start block was the start of the current quarter.
            uint256 blocksStaked = block.number - quarterStartBlock;
            info.accumulated = blocksStaked * info.amount;
        } else {
            uint256 blocksStaked = block.number - info.start;
            uint256 newCredits = blocksStaked * info.amount;
            info.accumulated += newCredits;
        }

        info.start = block.number;
    }
}

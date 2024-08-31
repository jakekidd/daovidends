// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import {Daovidends} from "../../src/contracts/Daovidends.sol";
import {DaovidendRewards} from "../../src/contracts/DaovidendRewards.sol";
import {MockERC20} from "./lib/MockERC20.sol";
import {MockDaovidendRewards} from "./lib/MockDaovidendRewards.sol";

contract DaovidendsTest is Test {
    Daovidends daovidends;
    MockERC20 daoToken;
    MockDaovidendRewards rewardsContract;
    address owner;
    address user1;
    address user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);

        // Deploy mock DAO token
        daoToken = new MockERC20();
        daoToken.mint(user1, 1000 ether);
        daoToken.mint(user2, 1000 ether);

        // Deploy Daovidends contract
        daovidends = new Daovidends(
            daoToken,
            100, // blocks per quarter
            block.number, // origin block
            50, // claim period in blocks
            owner
        );

        // Deploy Mock DaovidendRewards contract
        rewardsContract = new MockDaovidendRewards();

        // Set rewards contract
        daovidends.setRewardsContract(rewardsContract);
    }

    function test_Daovidends__stake_shouldStakeSuccessfully() public {
        // User1 stakes 100 DAO tokens
        vm.startPrank(user1);
        daoToken.approve(address(daovidends), 100 ether);
        daovidends.stake(100 ether);
        vm.stopPrank();

        // Verify the staked amount and the state of the contract
        assertEq(daovidends.totalAmountStaked(), 100 ether);
        (uint256 amount, uint256 start, uint256 accumulated, uint256 projected) = daovidends.stakers(user1);
        assertEq(amount, 100 ether);
        assertEq(start, block.number);
        assertEq(accumulated, 0);
        assertEq(projected, 100 * (100 - 0)); // 100 blocks left in quarter, * staked amount
    }

    function test_Daovidends__unstake_shouldUnstakeSuccessfully() public {
        // User1 stakes 100 DAO tokens
        vm.startPrank(user1);
        daoToken.approve(address(daovidends), 100 ether);
        daovidends.stake(100 ether);

        // User1 unstakes 50 DAO tokens
        daovidends.unstake(50 ether);
        vm.stopPrank();

        // Verify the remaining staked amount
        assertEq(daovidends.totalAmountStaked(), 50 ether);
        (uint256 amount, uint256 start, uint256 accumulated, ) = daovidends.stakers(user1);
        assertEq(amount, 50 ether);
        assertEq(start, block.number);
        assertEq(accumulated, 50 * (100 - 50)); // 50 blocks left in quarter, * staked amount
    }

    function test_Daovidends__unstake_shouldFailWhenAmountExceedsStake() public {
        // User1 stakes 100 DAO tokens
        vm.startPrank(user1);
        daoToken.approve(address(daovidends), 100 ether);
        daovidends.stake(100 ether);

        // Try to unstake more than staked amount, expect revert
        vm.expectRevert("InvalidUnstakeAmount");
        daovidends.unstake(150 ether);
        vm.stopPrank();
    }

    function test_Daovidends__claim_shouldClaimSuccessfully() public {
        // User1 stakes 100 DAO tokens
        vm.startPrank(user1);
        daoToken.approve(address(daovidends), 100 ether);
        daovidends.stake(100 ether);

        // Fast forward to the claim period
        vm.roll(block.number + 50);

        // Claim rewards
        vm.expectEmit(true, true, true, true);
        emit Daovidends.RewardsClaimed(user1, 100 ether);
        daovidends.claim();
        vm.stopPrank();

        // Verify that the claim was successful
        (uint256 quarter, , ) = daovidends.getCurrentQuarter();
        bool claimed = daovidends.claims(user1, quarter);
        assertTrue(claimed);
    }

    function test_Daovidends__claim_shouldFailWhenClaimPeriodHasEnded() public {
        // User1 stakes 100 DAO tokens
        vm.startPrank(user1);
        daoToken.approve(address(daovidends), 100 ether);
        daovidends.stake(100 ether);

        // Fast forward beyond the claim period
        vm.roll(block.number + 100);

        // Try to claim rewards after the claim period, expect revert
        vm.expectRevert(Daovidends.ClaimPeriodHasEnded.selector);
        daovidends.claim();
        vm.stopPrank();
    }

    function test_Daovidends__claim_shouldFailWhenAlreadyClaimed() public {
        // User1 stakes 100 DAO tokens
        vm.startPrank(user1);
        daoToken.approve(address(daovidends), 100 ether);
        daovidends.stake(100 ether);

        // Fast forward to the claim period
        vm.roll(block.number + 50);

        // First claim should succeed
        daovidends.claim();

        // Second claim should fail
        vm.expectRevert(Daovidends.RewardsAlreadyClaimed.selector);
        daovidends.claim();
        vm.stopPrank();
    }

    function test_Daovidends__rollover_shouldRolloverSuccessfully() public {
        // Fast forward to the next quarter
        vm.roll(block.number + 100);

        // Call rollover
        daovidends.rollover();

        // The test here would be more meaningful with a real rewards contract to check the state after rollover.
        // Since we are using a mock, this is a placeholder to ensure the function is callable.
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Daovidends} from "./Daovidends.sol";
import {DaovidendRewards} from "./DaovidendRewards.sol";

/**
 * @title DaovidendController
 * @dev The DaovidendController contract is designed to manage the deployment and updates of
 * the Daovidends and DaovidendRewards contracts. It acts as the central authority, ensuring
 * that both contracts are deployed with consistent configurations and that any updates to 
 * the rewards contract are performed securely. The controller is intended to be owned by 
 * the DAO, providing decentralized governance over the deployment and management of these contracts.
 */
contract DaovidendController is Ownable {
    Daovidends public daovidends;
    DaovidendRewards public rewards;
    bool public deployed;

    event ContractsDeployed(address indexed daovidends, address indexed rewards);
    event RewardsContractUpdated(
        address indexed daovidends,
        address indexed oldRewardsContract,
        address indexed newRewardsContract
    );
    event TokenAllowlistUpdated(address indexed rewardsContract, address indexed token, bool allowed);

    constructor(address _dao) Ownable(_dao) {}

    /**
     * @notice Deploys the Daovidends and DaovidendRewards contracts with the same configuration.
     * Can only be called once.
     * @param _daoToken The DAO token that users will stake.
     * @param _blocksPerQuarter The number of blocks per quarter.
     * @param _originBlock The block number when the first quarter starts.
     * @param _claimPeriod The number of blocks during which rewards can be claimed each quarter.
     */
    function deployContracts(
        IERC20 _daoToken,
        uint256 _blocksPerQuarter,
        uint256 _originBlock,
        uint256 _claimPeriod
    ) external onlyOwner {
        require(!deployed, "Contracts have already been deployed.");

        // Deploy the Daovidends contract.
        daovidends = new Daovidends(
            _daoToken,
            _blocksPerQuarter,
            _originBlock,
            _claimPeriod,
            address(this) // Controller will be the owner.
        );

        // Deploy the DaovidendRewards contract with the correct configuration.
        rewards = new DaovidendRewards(
            address(this),
            address(daovidends)
        );

        // Set the rewards contract in the Daovidends contract.
        daovidends.setRewardsContract(rewards);

        // Mark the deployment as complete.
        deployed = true;

        emit ContractsDeployed(address(daovidends), address(rewards));
    }

    /**
     * @notice Updates the rewards contract with a new instance.
     */
    function updateRewardsContract() external onlyOwner {
        require(deployed, "Contracts must be deployed first.");

        // Deploy a new DaovidendRewards contract with the same configuration.
        DaovidendRewards newRewards = new DaovidendRewards(
            address(this),
            address(daovidends)
        );

        // Get the old rewards contract for logging.
        DaovidendRewards oldRewards = rewards;

        // Update the rewards contract in the Daovidends contract.
        daovidends.setRewardsContract(newRewards);

        // Update the reference in the controller.
        rewards = newRewards;

        emit RewardsContractUpdated(address(daovidends), address(oldRewards), address(newRewards));
    }

    /**
     * @notice Updates the token allowlist in the specified rewards contract.
     * @param token The ERC20 token to update.
     * @param allowed Whether the token is allowed (true) or disallowed (false).
     */
    function updateTokenAllowlist(IERC20 token, bool allowed) external onlyOwner {
        rewards.updateTokenAllowlist(token, allowed);
        emit TokenAllowlistUpdated(address(rewards), address(token), allowed);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Daovidends.sol";
import "./DaovidendRewards.sol";

/**
 * @title DaovidendController
 * @dev The DaovidendController contract is designed to manage the deployment and updates of
 * the Daovidends and DaovidendRewards contracts. It acts as the central authority, ensuring
 * that both contracts are deployed with consistent configurations and that any updates to 
 * the rewards contract are performed securely. The controller is intended to be owned by 
 * the DAO, providing decentralized governance over the deployment and management of these contracts.
 */
contract DaovidendController is Ownable {
    address public immutable DAO;
    Daovidends public daovidends;
    DaovidendRewards public daovidendRewards;
    bool public deployed;

    event ContractsDeployed(address indexed daovidends, address indexed daovidendRewards);
    event RewardsContractUpdated(address indexed daovidends, address indexed oldRewardsContract, address indexed newRewardsContract);

    constructor(address _dao) Ownable(msg.sender) {
        DAO = _dao;
    }

    modifier onlyDAO() {
        require(msg.sender == DAO, "Caller is not the DAO");
        _;
    }

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
    ) external onlyDAO {
        require(!deployed, "Contracts have already been deployed");

        // Deploy the Daovidends contract.
        daovidends = new Daovidends(
            _daoToken,
            _blocksPerQuarter,
            _originBlock,
            _claimPeriod,
            address(this) // Controller will be the owner.
        );

        // Deploy the DaovidendRewards contract with the correct configuration.
        daovidendRewards = new DaovidendRewards(
            _blocksPerQuarter,
            _originBlock,
            _claimPeriod,
            address(daovidends)
        );

        // Set the rewards contract in the Daovidends contract.
        daovidends.setRewardsContract(daovidendRewards);

        // Mark the deployment as complete.
        deployed = true;

        emit ContractsDeployed(address(daovidends), address(daovidendRewards));
    }

    /**
     * @notice Updates the rewards contract with a new instance.
     * @param _blocksPerQuarter The number of blocks per quarter.
     * @param _originBlock The block number when the first quarter starts.
     * @param _claimPeriod The number of blocks during which rewards can be claimed each quarter.
     */
    function updateRewardsContract(
        uint256 _blocksPerQuarter,
        uint256 _originBlock,
        uint256 _claimPeriod
    ) external onlyDAO {
        require(deployed, "Contracts must be deployed first");

        // Deploy a new DaovidendRewards contract with the same configuration.
        DaovidendRewards newRewards = new DaovidendRewards(
            _blocksPerQuarter,
            _originBlock,
            _claimPeriod,
            address(daovidends)
        );

        // Get the old rewards contract for logging.
        DaovidendRewards oldRewards = daovidends.rewardsContract();

        // Update the rewards contract in the Daovidends contract.
        daovidends.setRewardsContract(newRewards);

        emit RewardsContractUpdated(address(daovidends), address(oldRewards), address(newRewards));
    }
}

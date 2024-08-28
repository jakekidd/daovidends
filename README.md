# Daovidends

### Overview

The Daovidend ecosystem is a set of smart contracts designed to provide DAOs with the ability to distribute quarterly rewards to participants who stake governance tokens. This system ensures that participants are rewarded proportionally based on the duration and amount of their stake within each quarter. The contracts are managed through a central controller, the `DaovidendController`, which ensures secure and consistent deployment and management.

### Contracts

1. **Daovidends**:

   - This contract handles staking and rewards distribution. Participants can stake their DAO governance tokens, and at the end of each quarter, they can claim rewards based on their accumulated staking credits, which are determined by the stake amount and duration. At the end of the quarter a snapshot of the reward tokens pool is taken, and the percentage share of those rewards that participating users will receive is determined by the user's accumulated credits / total credits pool.

2. **DaovidendRewards**:

   - This contract holds the reward tokens and tracks the distribution for each quarter. It ensures that rewards are distributed fairly based on the staking information from the `Daovidends` contract. Rewards may come from fees from an exchange, lending, or yield farming system, for example.

3. **DaovidendController**:
   - The central authority that manages the deployment and updates of the `Daovidends` and `DaovidendRewards` contracts. It ensures that the contracts are deployed with consistent configurations and allows for secure updates to the rewards contract.

### How It Works

1. **Staking**:

   - Participants stake their governance tokens in the `Daovidends` contract. The amount and duration of the stake are tracked to calculate the staking credits.

2. **Quarterly Distribution**:

   - At the end of each quarter, participants can claim rewards from the `DaovidendRewards` contract. The rewards are distributed based on the participant’s share of the total staking credits accumulated during the quarter.

3. **Controller Management**:
   - The `DaovidendController` contract is responsible for deploying the `Daovidends` and `DaovidendRewards` contracts and managing any updates to the rewards contract. This ensures that the system remains consistent and secure under the governance of the DAO.

### Why Quarterly Distribution?

Quarterly distribution aligns with typical financial reporting periods and provides a predictable schedule for rewards distribution. It encourages long-term participation in the DAO by rewarding participants who maintain their stake throughout the quarter. This approach also reduces the frequency of rewards distribution, lowering gas costs and simplifying the management of rewards.

User stake can be consulted if the implementing DAO wants to maintain the ability for users to reuse their stake for voting and governance participation purposes.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IEpochStaking {
    // Structure pour stocker les informations d'une époch
    struct Epoch {
        uint256 totalStaked; // Montant total staké dans l'époch
        uint256 rewardAmount; // Montant total des récompenses pour cette époch
        bool isFinalized; // Statut de l'époch (finalisée ou non)
    }

    // Event pour notifier qu'un utilisateur a staké des tokens pour une époch donnée
    event Stake(address indexed user, uint256 amount, uint256 epoch);

    // Event pour notifier qu'un utilisateur a retiré ses tokens stakés pour une époch donnée
    event Unstake(address indexed user, uint256 amount, uint256 epoch);

    // Event pour notifier qu'un utilisateur a réclamé ses récompenses pour une époch donnée
    event Claim(address indexed user, uint256 rewardAmount, uint256 epoch);

    // Event pour notifier la finalisation d'une époch et l'ajout de récompenses
    event RewardsSet(uint256 epoch, uint256 rewardAmount);

    // Event pour notifier une mise à jour de la durée des époques
    event EpochDurationUpdated(uint256 newDuration);

    // Event pour notifier une mise à jour des adresses des tokens
    event TokenAddressesUpdated(address stakingToken, address rewardToken);

    // Fonction pour staker des tokens dans le contrat
    function stake(uint256 amount) external;

    // Fonction pour réclamer uniquement les récompenses d'une époch finalisée
    function claim(uint256 epoch) external;

    // Fonction pour retirer uniquement les tokens stakés pour une époch finalisée
    function unstake(uint256 epoch) external;

    // Fonction pour finaliser une époch et définir le montant de récompenses
    function finalizeEpoch(uint256 epoch, uint256 rewardAmount) external;

    // Fonction pour mettre à jour la durée de chaque époch
    function setEpochDuration(uint256 newDuration) external;

    // Fonction pour définir les adresses des tokens de staking et de récompense
    function setTokenAddresses(address stakingToken, address rewardToken) external;

    // Fonction pour obtenir le numéro de l'époch actuelle
    function getCurrentEpoch() external view returns (uint256);

    // Fonction pour obtenir le timestamp de début d'une époch donnée
    function getEpochStartTimestamp(uint256 epoch) external view returns (uint256);

    // Fonction pour obtenir le montant staké par un utilisateur pour une époch
    function getUserStakeForEpoch(uint256 epoch, address user) external view returns (uint256);
}

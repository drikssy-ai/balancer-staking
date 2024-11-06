// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "src/interfaces/IERC20.sol";

interface IStakingPool {
    // Définir l'adresse des tokens de staking et de récompense
    function setStakingAddress(IERC20 _stakingAddress) external;
    function setRewardsAddress(IERC20 _rewardsAddress) external;

    // Ajouter des récompenses au pool
    function addRewards(uint256 amount) external;

    // Définir les récompenses journalières
    function setDailyRewards(uint256 _dailyRewards) external;

    // Déposer des tokens pour obtenir des parts (shares)
    function deposit(uint256 amount) external;

    // Retirer des parts et récupérer les tokens stakés
    function withdraw(uint256 shareAmount) external;

    // Réclamer les récompenses accumulées
    function claim() external;

    // Obtenir le nombre de tokens stakés pour un utilisateur en fonction de ses parts
    function currentStake(uint256 shareAmount) external view returns (uint256);

    // Obtenir les récompenses actuelles, le timestamp et le taux de récompense par seconde
    function getCurrentRewards(address _address)
        external
        view
        returns (uint256 _currentRewards, uint256 _timestamp, uint256 _tokenPerSecond);

    // Obtenir le taux de récompense par seconde pour un utilisateur
    function rewardRatePerSecond(address _address) external view returns (uint256);
}

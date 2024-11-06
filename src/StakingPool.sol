// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IERC20 } from "src/interfaces/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IStakingPool } from "src/interfaces/IStakingPool.sol";

contract StakingPool is IStakingPool, Ownable {
    uint256 public constant CLAIM_DELAY = 7 days;

    // Adresse du token que les utilisateurs peuvent staker
    IERC20 public stakingToken;

    // Adresse du token utilisé pour les récompenses
    IERC20 public rewardToken;

    // Montant total de tokens actuellement stakés dans le contrat
    uint256 public totalStakedTokens;

    // Montant total de parts (shares) dans le pool
    uint256 public totalShares;

    // Montant de récompenses disponibles dans le pool
    uint256 public rewardPoolBalance;

    // Montant de récompenses distribuées par jour
    uint256 public dailyRewardAmount;

    // Dernier timestamp de mise à jour des récompenses
    uint256 public lastUpdateTimestamp;

    // Variable pour stocker les récompenses par part accumulées
    uint256 public accumulatedRewardPerShare;

    mapping(address => uint256) public lastStakeTime;

    // Mapping pour suivre les parts (shares) de chaque utilisateur
    mapping(address => uint256) public userShares;

    // Mapping pour stocker les récompenses accumulées par utilisateur
    mapping(address => uint256) public userRewardCheckpoint;

    // Mapping pour suivre les récompenses non réclamées de chaque utilisateur
    mapping(address => uint256) public pendingRewards;

    // Event pour notifier un dépôt
    event Deposit(address indexed user, uint256 amount);

    // Event pour notifier un retrait
    event Withdraw(address indexed user, uint256 amount);

    // Event pour notifier une réclamation de récompense
    event RewardClaimed(address indexed user, uint256 rewardAmount);

    constructor(IERC20 _stakingToken, IERC20 _rewardToken) Ownable(msg.sender) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        lastUpdateTimestamp = block.timestamp;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Deposit amount must be greater than zero");

        // Met à jour les récompenses accumulées dans le pool
        updatePoolRewards();

        // Si l'utilisateur a déjà des parts, met à jour ses récompenses en attente
        if (userShares[msg.sender] > 0) {
            uint256 pending =
                (userShares[msg.sender] * accumulatedRewardPerShare) / 1e18 - userRewardCheckpoint[msg.sender];
            pendingRewards[msg.sender] += pending;
        }

        // Transfère les tokens de staking de l'utilisateur vers le contrat
        stakingToken.transferFrom(msg.sender, address(this), amount);

        // Calcule les parts pour l'utilisateur en fonction de son dépôt
        uint256 shares;
        if (totalStakedTokens == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalStakedTokens;
        }

        // Met à jour les parts de l'utilisateur et les totaux du pool
        userShares[msg.sender] += shares;
        totalShares += shares;
        totalStakedTokens += amount;

        // Met à jour le "checkpoint" des récompenses pour l'utilisateur
        userRewardCheckpoint[msg.sender] = (userShares[msg.sender] * accumulatedRewardPerShare) / 1e18;

        // Enregistre le timestamp de ce dépôt
        lastStakeTime[msg.sender] = block.timestamp;

        emit Deposit(msg.sender, amount);
    }

    function claim() external {
        // Vérifie que le délai de réclamation est respecté
        require(block.timestamp >= lastStakeTime[msg.sender] + CLAIM_DELAY, "Claim delay not yet passed");

        // Met à jour les récompenses accumulées dans le pool
        updatePoolRewards();

        // Calcule les récompenses en attente pour l'utilisateur
        uint256 pending = (userShares[msg.sender] * accumulatedRewardPerShare) / 1e18 - userRewardCheckpoint[msg.sender];
        require(pending > 0, "No rewards to claim");

        // Réinitialise les récompenses en attente
        pendingRewards[msg.sender] = 0;
        userRewardCheckpoint[msg.sender] = (userShares[msg.sender] * accumulatedRewardPerShare) / 1e18;

        // Transfert des récompenses à l'utilisateur
        rewardToken.transfer(msg.sender, pending);

        emit RewardClaimed(msg.sender, pending);
    }

    function withdraw(uint256 shareAmount) external {
        require(shareAmount > 0 && shareAmount <= userShares[msg.sender], "Invalid share amount");

        // Vérifie que le délai de réclamation est respecté
        require(block.timestamp >= lastStakeTime[msg.sender] + CLAIM_DELAY, "Withdraw delay not yet passed");

        // Met à jour les récompenses accumulées dans le pool
        updatePoolRewards();

        // Calcul des récompenses en attente pour l'utilisateur
        uint256 _pendingRewards =
            (userShares[msg.sender] * accumulatedRewardPerShare) / 1e18 - userRewardCheckpoint[msg.sender];
        uint256 totalRewards = _pendingRewards + pendingRewards[msg.sender];

        // Calcule le montant de tokens de staking à retirer
        uint256 tokenAmount = (shareAmount * totalStakedTokens) / totalShares;

        // Met à jour les parts et les totaux du pool
        userShares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        totalStakedTokens -= tokenAmount;

        // Met à jour le "checkpoint" des récompenses pour l'utilisateur
        userRewardCheckpoint[msg.sender] = (userShares[msg.sender] * accumulatedRewardPerShare) / 1e18;

        // Transfère les tokens de staking à l'utilisateur
        stakingToken.transfer(msg.sender, tokenAmount);

        // Si des récompenses sont disponibles, on les transfère également
        if (totalRewards > 0) {
            rewardToken.transfer(msg.sender, totalRewards);
            pendingRewards[msg.sender] = 0; // Réinitialise les récompenses en attente
            emit RewardClaimed(msg.sender, totalRewards);
        }

        emit Withdraw(msg.sender, tokenAmount);
    }

    // Définit le montant de récompenses distribuées chaque jour
    function setDailyRewards(uint256 _dailyRewardAmount) external onlyOwner {
        // Met à jour les récompenses accumulées avant de changer le montant de récompenses journalières
        updatePoolRewards();

        dailyRewardAmount = _dailyRewardAmount;
    }

    function addRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Reward amount must be greater than zero");

        // Transfère les tokens de récompense vers le contrat
        rewardToken.transferFrom(msg.sender, address(this), amount);

        // Augmente le solde total des récompenses disponibles
        rewardPoolBalance += amount;
    }

    // Met à jour les récompenses dans le pool en fonction du temps écoulé
    function updatePoolRewards() internal {
        // Si aucun token n'est staké, aucune récompense n'est ajoutée
        if (totalStakedTokens == 0) {
            lastUpdateTimestamp = block.timestamp;
            return;
        }

        // Calcul du temps écoulé depuis la dernière mise à jour
        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;

        // Calcul des récompenses accumulées pour l'intervalle de temps
        uint256 rewardsAccumulated = (dailyRewardAmount * timeElapsed) / 86_400; // 86400 = nombre de secondes par jour

        // Mise à jour des récompenses accumulées par part
        accumulatedRewardPerShare += (rewardsAccumulated * 1e18) / totalShares; // Multiplie par 1e18 pour garder une
            // précision

        // Met à jour le dernier timestamp
        lastUpdateTimestamp = block.timestamp;
    }

    function setStakingAddress(IERC20 _stakingToken) external onlyOwner {
        require(address(stakingToken) == address(0), "Staking address is already set");
        stakingToken = _stakingToken;
    }

    function setRewardsAddress(IERC20 _rewardToken) external override onlyOwner {
        require(address(rewardToken) == address(0), "Rewards address is already set");
        rewardToken = _rewardToken;
    }

    function currentStake(uint256 shareAmount) public view override returns (uint256) {
        if (totalShares == 0) {
            return 0;
        }
        // Calcule le montant de tokens correspondant aux parts fournies
        return (shareAmount * totalStakedTokens) / totalShares;
    }

    function getCurrentRewards(address _user)
        external
        view
        override
        returns (uint256 currentRewards, uint256 timestamp, uint256 rewardPerSecond)
    {
        timestamp = block.timestamp;
        uint256 _pendingRewards = (userShares[_user] * accumulatedRewardPerShare) / 1e18 - userRewardCheckpoint[_user];
        currentRewards = _pendingRewards + pendingRewards[_user];

        // Calcul du taux de récompense par seconde pour l'utilisateur
        rewardPerSecond = rewardRatePerSecond(_user);
    }

    function rewardRatePerSecond(address _user) public view override returns (uint256) {
        if (totalStakedTokens == 0) {
            return 0;
        }

        uint256 userShareRatio = userShares[_user] * 1e18 / totalShares;
        return (dailyRewardAmount * userShareRatio) / 86_400; // Divisé par 86400 pour un taux par seconde
    }
}

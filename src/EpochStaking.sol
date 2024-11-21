// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEpochStaking } from "./interfaces/IEpochStaking.sol";

contract EpochStaking is Ownable {
    struct EpochInfo {
        uint256 totalStaked; // Montant total staké dans l'époch
        uint256 rewardAmount; // Montant total des récompenses pour cette époch
        bool isFinalized; // Statut de l'époch (finalisée ou non)
    }

    struct Stake {
        uint256 amount; // Montant staké par l'utilisateur
        uint256 epoch; // Numéro de l'époch pour laquelle l'utilisateur a staké
    }

    IERC20 public stakingToken; // Token utilisé pour le staking (en verité il n'y a pas de token ERC20 pour le staking, on utilise le storage)
    IERC20 public rewardToken; // Token utilisé pour les récompenses USDC

    uint256 public epochDuration; // Durée de chaque époch en secondes
    uint256 public contractStartTimestamp; // Timestamp de départ pour calculer les époques

    mapping(uint256 epoch => bool updated) public epochUpdates; // Mapping pour suivre les mises à jour des époques
    mapping(uint256 epoch => EpochInfo) public epochStakes; // Informations sur les époques
    mapping(uint256 epoch => uint256 amounToUnstake) public epochUnstakes; // Montants prêts à être untakés par époch
    mapping(address user => Stake stake) public userStakes; // Montants stakés par utilisateur et par époch
    mapping(address user => Stake unstake) public userUnstakes; // Montants prêts à être untakés par utilisateur
        // et par époch

    constructor(IERC20 _stakingToken, IERC20 _rewardToken, uint256 _epochDuration) Ownable(msg.sender) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        epochDuration = _epochDuration; // above 0
        contractStartTimestamp = block.timestamp;
    }

    function stake(address staker, uint256 amount) external {
        _update();
        require(amount > 0, "Stake amount must be greater than zero");
        require(stakingToken.balanceOf(staker) >= amount, "Insufficient staking token balance");
        Stake storage userStake = userStakes[staker];
        require(userStake.amount == 0, "User already has a stake");

        // Récupère l'époch actuelle et l'époch suivante
        // le staker ne peut stake que pour l'époch suivante
        uint256 nextEpoch = getCurrentEpoch() + 1;

        // Ajoute le montant staké de l'utilisateur pour l'époch suivante
        userStake.amount += amount;
        userStake.epoch = nextEpoch;

        epochStakes[nextEpoch].totalStaked += amount;

        // Transfert des tokens de staking vers le contrat
        // stakingToken.transferFrom(staker, address(this), amount);

        // emit Stake(msg.sender, amount, nextEpoch);
    }

    function unstake(address staker) external {
        _update();
        Stake storage userStake = userStakes[staker];
        require(userStake.amount > 0, "user has no stake");
        uint256 currentEpoch = getCurrentEpoch();

        // on check si le user a déjà un unstake en cours
        Stake storage userUnstake = userUnstakes[staker];

        // si le montant de unstake est egal au montant de stake alors rien à unstake
        require(userUnstake.amount < userStake.amount, "Nothing to unstake");

        uint256 amountToWithdraw = userStake.amount;

        if (currentEpoch < userStake.epoch) {
            // retrait du stake
            uint256 stakedEpoch = userStake.epoch;
            require(stakedEpoch == currentEpoch + 1, "Can only unstake for next epoch");
            userStake.amount = 0;
            userStake.epoch = 0;
            epochStakes[stakedEpoch].totalStaked -= amountToWithdraw; // normally should contain at least current stake
                // amount
            stakingToken.transfer(staker, amountToWithdraw);
            // emit Unstake(msg.sender, userStake, epoch);
            // emit Withdraw(staker, amountToWithdraw, stakedEpoch);
            return;
        }

        // on retire son stake pour l'epoch suivante
        userUnstake.amount += amountToWithdraw;
        userUnstake.epoch = currentEpoch + 1;
        epochUnstakes[currentEpoch + 1] += amountToWithdraw;
        // emit Unstake(msg.sender, userStake, epoch);
    }

    function claim(address user, uint256 epoch) public {
        _update();
        require(epochStakes[epoch].isFinalized, "Epoch not finalized by admin");
        uint256 currentEpoch = getCurrentEpoch();
        require(currentEpoch > epoch, "can claim only for past epochs");
        Stake memory userStake = userStakes[user];
        uint256 stakedEpoch = userStake.epoch;
        uint256 stakedAmount = userStake.amount;
        require(stakedAmount > 0, "user has no stake");
        require(stakedEpoch <= epoch, "user has no stake for this epoch");

        // On determine si le user a de quoi claim

        //1. on recupere le montant de staking et celui du unstaking pour le user
        Stake memory userUnstake = userUnstakes[user];
        uint256 unstakeAmount;
        if (userUnstake.epoch <= epoch) {
            unstakeAmount = userUnstake.amount;
        }
        uint256 claimedAmount = stakedAmount - unstakeAmount;
        require(claimedAmount > 0, "user has no claimable amount");

        // on calcule le reward du user

        uint256 rewardAmount = epochStakes[epoch].rewardAmount;
        uint256 totalStaked = epochStakes[epoch].totalStaked - epochUnstakes[epoch];

        // Calcul des récompenses en fonction de la part de l'utilisateur
        // faire une fonction pour le calcul avec le scale des decimals et du wad operation
        uint256 userRewards = (userStake.amount * rewardAmount) / totalStaked;

        // Transfert des récompenses à l'utilisateur
        rewardToken.transfer(msg.sender, userRewards);

        // emit Claim(msg.sender, userReward, epoch);
    }

    function withdraw(address user) external {
        _update();
        uint256 currentEpoch = getCurrentEpoch();
        Stake storage userStake = userStakes[user];
        Stake storage userUnstake = userUnstakes[user];
        require(userUnstake.amount >= 0, "Nothing to withdraw");
        require(userUnstake.epoch < currentEpoch, "Can only withdraw for past epochs");

        uint256 amountToWithdraw = userUnstake.amount;

        // on update le montant staked du user
        userStake.amount -= amountToWithdraw;
        // if (userStakes[user].amount == userWithdrawal.amount) {
        //     userStakes[user].epoch = 0;
        // }

        // on update le montant de unstake
        userUnstake.amount = 0;
        userUnstake.epoch = 0;

        // Transfère les tokens de staking à l'utilisateur
        stakingToken.transfer(msg.sender, amountToWithdraw);

        // emit Withdrawn(user, amountToWithdraw);
    }

    function setRewards(uint256 rewardAmount) external onlyOwner {
        _update();
        uint256 currentEpoch = getCurrentEpoch();
        require(currentEpoch > 0, "current epoch must be greater than zero");
        uint256 lastEpoch = currentEpoch - 1;
        require(!epochStakes[lastEpoch].isFinalized, "Rewards already set for this epoch");
        epochStakes[lastEpoch].rewardAmount = rewardAmount;
        epochStakes[lastEpoch].isFinalized = true;
    }

    /**
     * @dev Needs to be updated on every epochs!!
     */
    function _update() private {
        uint256 currentEpoch = getCurrentEpoch();
        if (epochUpdates[currentEpoch]) {
            return;
        }

        if (currentEpoch == 0) {
            epochUpdates[currentEpoch] = true;
            return;
        }

        epochStakes[currentEpoch].totalStaked +=
            (epochStakes[currentEpoch - 1].totalStaked - epochUnstakes[currentEpoch - 1]);
        epochUpdates[currentEpoch] = true;
    }

    // // --- Fonctions Utilitaires pour les Époques ---

    // Calcule l'époch actuelle en fonction de l'epochDuration
    function getCurrentEpoch() public view returns (uint256) {
        return (block.timestamp - contractStartTimestamp) / epochDuration + 1;
    }

    // Retourne le timestamp de début d'une époch donnée
    function getEpochStartTimestamp(uint256 epoch) public view returns (uint256) {
        return contractStartTimestamp + (epoch - 1) * epochDuration;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEpochStaking } from "./interfaces/IEpochStaking.sol";
import { console } from "@forge-std/console.sol";

abstract contract EpochStaking is Ownable {
    // errors
    error StakingAmountIsZero();
    error InsufficientStakingTokenBalance();
    error UserHasNoStake();
    error NoRewardsToClaim();
    error RewardsAlreadySetForThisEpoch();
    error AddressZero();
    error NotAuthorized(address caller);

    struct EpochInfo {
        uint256 totalStaked; // Montant total staké dans l'époch
        uint256 rewardAmount; // Montant total des récompenses pour cette époch
        bool isFinalized; // Statut de l'époch (finalisée ou non)
    }

    struct Stake {
        uint256 amount; // Montant staké par l'utilisateur
        uint256 epoch; // Numéro de l'époch pour laquelle l'utilisateur a staké
        bool rewardsClaimed; // Statut des récompenses de l'utilisateur (claimées ou non)
    }

    IERC20 public immutable rewardToken; // Token utilisé pour les récompenses USDC
    address public immutable orchestrator; // Adresse de l'orchestrateur
    address public immutable admin; // Adresse de l'orchestrateur

    uint256 public currentEpoch; // Époque actuelle

    mapping(uint256 epoch => bool updated) public epochUpdates; // Mapping pour suivre les mises à jour des époques
    mapping(uint256 epoch => EpochInfo) public epochStakes; // Informations sur les époques
    mapping(uint256 epoch => uint256 amounToUnstake) public epochUnstakes; // Montants prêts à être untakés par époch
    mapping(address user => Stake stake) public userStakes; // Montants stakés par utilisateur et par époch
        // et par époch
    mapping(address user => uint256 rewards) public pendingRewards; // Récompenses en attente pour les utilisateurs
    mapping(address user => uint256 epoch) public lastClaimEpoch; // Dernière époch pour laquelle l'utilisateur a
        // réclamé des récompenses

    constructor(address _rewardToken, address _cs) Ownable(msg.sender) {
        if (_rewardToken == address(0)) revert AddressZero();
        if (_cs == address(0)) revert AddressZero();
        rewardToken = IERC20(_rewardToken);
        admin = _cs;
    }

    modifier onlyCS() {
        if (msg.sender != admin) revert NotAuthorized(msg.sender);
        _;
    }

    function claim(address user) public {
        _updateUser(user);
        uint256 _pendingRewards = pendingRewards[user];
        if (_pendingRewards == 0) {
            revert("No rewards to claim");
        }
        uint256 _currentEpoch = getCurrentEpoch();
        lastClaimEpoch[user] = _currentEpoch - 1; // we set the last claim epoch to the previous one
        pendingRewards[user] = 0;
        rewardToken.transfer(msg.sender, _pendingRewards);

        // emit Claim(msg.sender, userReward, _currentEpoch - 1);
    }

    function setRewards(uint256 rewardAmount) external onlyCS {
        _update();
        uint256 _currentEpoch = getCurrentEpoch();
        require(!epochStakes[_currentEpoch].isFinalized, "Rewards already set for this epoch");
        epochStakes[_currentEpoch].rewardAmount = rewardAmount;
        epochStakes[_currentEpoch].isFinalized = true;
        _incrementCurrentEpoch();
        _update();
        rewardToken.transferFrom(msg.sender, address(this), rewardAmount);
    }

    function _stake(address staker, uint256 amount) internal {
        if (amount == 0) revert StakingAmountIsZero();
        _updateUser(staker);
        Stake storage userStake = userStakes[staker];

        // Récupère l'époch actuelle et l'époch suivante
        // le staker ne peut stake que pour l'époch suivante
        uint256 _currentEpoch = getCurrentEpoch();

        // Ajoute le montant staké de l'utilisateur pour l'époch suivante
        userStake.amount += amount;
        userStake.epoch = _currentEpoch;

        epochStakes[_currentEpoch].totalStaked += amount;

        // Transfert des tokens de staking vers le contrat
        // stakingToken.transferFrom(staker, address(this), amount);

        // emit Stake(msg.sender, amount, nextEpoch);
    }

    function _unstake(address staker) internal returns (uint256) {
        _updateUser(staker);
        Stake storage userStake = userStakes[staker];
        uint256 stakedAmount = userStake.amount;
        // we need to check if the user has a stake
        require(stakedAmount > 0, "user has no stake");

        // we get the current epoch
        uint256 _currentEpoch = getCurrentEpoch();

        // retrait du stake
        userStake.amount = 0;
        userStake.epoch = 0;
        epochUnstakes[_currentEpoch] += stakedAmount;
        // emit Unstake(msg.sender, userStake, epoch);

        return stakedAmount;
    }

    /**
     * @dev Needs to be updated on every epochs!!
     */
    function _update() private {
        uint256 _currentEpoch = getCurrentEpoch();
        if (epochUpdates[_currentEpoch]) {
            return;
        }

        if (_currentEpoch == 0) {
            epochUpdates[_currentEpoch] = true;
            return;
        }

        console.log("Updating epoch %s", epochStakes[_currentEpoch - 1].totalStaked);

        epochStakes[_currentEpoch].totalStaked +=
            (epochStakes[_currentEpoch - 1].totalStaked - epochUnstakes[_currentEpoch - 1]);
        epochUpdates[_currentEpoch] = true;
    }

    function _updateUser(address _user) private {
        // first we need to update the total staked amount of the contract (if not updated yet)
        _update();
        //we need to calculate the pending rewards on each epoch from the one
        // he originally staked to the current epoch -1
        uint256 _currentEpoch = getCurrentEpoch();
        Stake memory userStake = userStakes[_user];
        uint256 stakedAmount = userStake.amount;
        uint256 stakedEpoch = userStake.epoch;

        // !! @audit: becareful if there are too many epochs, this loop can be expensive and/or revert for gas limit
        // reasons
        uint256 startingClaimEpoch = lastClaimEpoch[_user] > stakedEpoch ? lastClaimEpoch[_user] : stakedEpoch;
        for (uint256 i = startingClaimEpoch; i < _currentEpoch; i++) {
            if (epochStakes[i].isFinalized && !userStake.rewardsClaimed) {
                uint256 totalStaked = epochStakes[i].totalStaked;
                // if the total staked amount is 0, we skip the epoch
                if (totalStaked == 0) continue;

                uint256 rewardAmount = epochStakes[i].rewardAmount;
                uint256 userRewards = (stakedAmount * rewardAmount) / totalStaked; // use math lib here
                pendingRewards[_user] += userRewards;
                // once  the rewards are calculated, we set the rewardsClaimed to true
                userStake.rewardsClaimed = true;
                // potentially we can emit an event here
                // emit RewardsCalculated(_user, userRewards, i);
            }
        }
    }

    function _incrementCurrentEpoch() private {
        currentEpoch++;
    }

    // // --- Fonctions Utilitaires pour les Époques ---

    // Calcule l'époch actuelle en fonction de l'epochDuration
    function getCurrentEpoch() public view returns (uint256) {
        return currentEpoch;
    }

    function getUserStake(address user) public view returns (Stake memory) {
        return userStakes[user];
    }

    function getEpochInfo(uint256 epoch) public view returns (EpochInfo memory) {
        return epochStakes[epoch];
    }
}

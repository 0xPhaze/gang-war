// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GMCChild} from "./tokens/GMCChild.sol";
import {GangToken} from "./tokens/GangToken.sol";

import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

// ------------- constants

struct Reward {
    uint8 gang;
    uint248 amount;
}

struct GangWarRewardsDS {
    uint256 currentRewardId;
    mapping(uint256 => Reward) rewards;
    mapping(uint256 => mapping(uint256 => bool)) claimed;
}

// ------------- storage

bytes32 constant DIAMOND_STORAGE_GANG_WAR_REWARDS = keccak256("diamond.storage.gang.war.rewards");

function s() pure returns (GangWarRewardsDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_GANG_WAR_REWARDS;
    assembly {
        diamondStorage.slot := slot
    }
}

// ------------- errors

error InvalidGang();
error NotAuthorized();
error InvalidReward();
error RewardAlreadyClaimed();

/// @title Gang War Rewards
/// @author phaze (https://github.com/0xPhaze)
contract GangWarRewards is UUPSUpgrade, OwnableUDS {
    GangWarRewardsDS private __storageLayout;

    GMCChild public immutable gmc;
    GangToken public immutable mice;

    constructor(GMCChild gmc_, GangToken mice_) {
        gmc = gmc_;
        mice = mice_;
    }

    /* ------------- init ------------- */

    function init() external initializer {
        __Ownable_init();
    }

    /* ------------- view ------------- */

    function currentReward() external view returns (Reward memory reward) {
        uint256 rewardId = s().currentRewardId;

        return s().rewards[rewardId];
    }

    function claimableReward(uint256 id) external view returns (uint256) {
        uint256 rewardId = s().currentRewardId;

        Reward storage reward = s().rewards[rewardId];

        if (s().claimed[rewardId][id]) return 0;
        if (uint256(gmc.gangOf(id)) != reward.gang) return 0;

        return reward.amount;
    }

    /* ------------- external ------------- */

    function claimReward(uint256[] calldata ids) external {
        uint256 rewardId = s().currentRewardId;

        Reward storage reward = s().rewards[rewardId];

        uint256 winnerGang = reward.gang;
        uint256 rewardAmount = reward.amount;

        if (rewardAmount == 0) revert InvalidReward();

        for (uint256 i; i < ids.length; ++i) {
            if (s().claimed[rewardId][ids[i]]) revert RewardAlreadyClaimed();
            if (gmc.ownerOf(ids[i]) != msg.sender) revert NotAuthorized();
            if (uint256(gmc.gangOf(ids[i])) != winnerGang) revert InvalidGang();

            s().claimed[rewardId][ids[i]] = true;
        }

        uint256 totalReward = ids.length * rewardAmount;

        mice.mint(msg.sender, totalReward);
    }

    /* ------------- owner ------------- */

    function addReward(uint8 gang, uint248 amount) external onlyOwner {
        uint256 rewardId = ++s().currentRewardId;

        s().rewards[rewardId].gang = gang;
        s().rewards[rewardId].amount = amount;
    }

    function setReward(uint256 rewardId, uint8 gang, uint248 amount) external onlyOwner {
        s().rewards[rewardId].gang = gang;
        s().rewards[rewardId].amount = amount;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external;

    function transfer(address to, uint256 amount) external;

    function mint(address to, uint256 amount) external;

    function balanceOf(address owner) external view returns (uint256);
}

/* ============= Storage ============= */

// keccak256("diamond.storage.gang.war.rewards") == 0x7663b7593c6b325747ef3546beebff6d1594934779e6cd28a66d956dd6fcb247;
bytes32 constant DIAMOND_STORAGE_GANG_WAR_REWARDS = 0x7663b7593c6b325747ef3546beebff6d1594934779e6cd28a66d956dd6fcb247;

struct GangWarRewardsDS {
    IERC20[3] rewardsToken;
    uint256[3] totalShares;
    uint256[3] lastUpdateTime;
    uint256[3][3] totalRewardPerToken;
    uint256[3][3] rewardRate;
    mapping(address => uint256[3]) shares;
    mapping(address => uint256[3][3]) lastUserRewardPerToken;
}

function s() pure returns (GangWarRewardsDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_GANG_WAR_REWARDS
    }
}

// adapted from https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol
contract GangRewards {
    /* ------------- Constructor ------------- */

    constructor(address[] memory _rewardsToken) {
        for (uint256 i; i < 3; i++) s().rewardsToken[i] = IERC20(_rewardsToken[i]);
    }

    /* ------------- External ------------- */

    function _enter(uint256 gang, uint256 amount) internal {
        _updateReward(gang, msg.sender);

        s().totalShares[gang] += amount;
        s().shares[msg.sender][gang] += amount;
    }

    function _exit(uint256 gang, uint256 amount) internal {
        _updateReward(gang, msg.sender);

        s().totalShares[gang] -= amount;
        s().shares[msg.sender][gang] -= amount;
    }

    /* ------------- Internal ------------- */

    function _updateReward(uint256 gang, address account) internal {
        uint256 rpt_0 = s().totalRewardPerToken[gang][0];
        uint256 rpt_1 = s().totalRewardPerToken[gang][1];
        uint256 rpt_2 = s().totalRewardPerToken[gang][2];

        uint256 totalShares_ = s().totalShares[gang];

        if (totalShares_ != 0) {
            uint256 timeScaled = (block.timestamp - s().lastUpdateTime[gang]);

            rpt_0 += (timeScaled * s().rewardRate[gang][0]) / totalShares_;
            rpt_1 += (timeScaled * s().rewardRate[gang][1]) / totalShares_;
            rpt_2 += (timeScaled * s().rewardRate[gang][2]) / totalShares_;

            s().totalRewardPerToken[gang][0] = rpt_0;
            s().totalRewardPerToken[gang][1] = rpt_1;
            s().totalRewardPerToken[gang][2] = rpt_2;
        }

        s().lastUpdateTime[gang] = block.timestamp;

        if (account != address(0)) {
            uint256 share = s().shares[account][gang];

            s().rewardsToken[0].mint(account, (share * (rpt_0 - s().lastUserRewardPerToken[account][gang][0])));
            s().rewardsToken[1].mint(account, (share * (rpt_1 - s().lastUserRewardPerToken[account][gang][1])));
            s().rewardsToken[2].mint(account, (share * (rpt_2 - s().lastUserRewardPerToken[account][gang][2])));

            s().lastUserRewardPerToken[account][gang][0] = rpt_0;
            s().lastUserRewardPerToken[account][gang][1] = rpt_1;
            s().lastUserRewardPerToken[account][gang][2] = rpt_2;
        }
    }

    /* ------------- Owner ------------- */

    function _setRewardRate(
        uint256 gang,
        uint256 token,
        uint256 rate
    ) internal {
        _updateReward(gang, address(0));

        s().rewardRate[gang][token] = rate;
    }
}

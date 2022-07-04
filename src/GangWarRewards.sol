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
    IERC20[3] gangToken;
    uint256[3] totalShares;
    uint256[3] lastUpdateTime;
    uint256[3][3] totalYieldPerToken;
    uint256[3][3] yield;
    mapping(address => uint256[3]) userShares;
    mapping(address => uint256[3][3]) lastUserYieldPerToken;
}

function s() pure returns (GangWarRewardsDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_GANG_WAR_REWARDS
    }
}

// adapted from https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol
contract GangWarRewards {
    /* ------------- View ------------- */

    function getYield() external view returns (uint256[3][3] memory) {
        // return s().yield; //Fix
    }

    /* ------------- Internal ------------- */

    function _setGangTokens(address[] memory _rewardsToken) internal {
        for (uint256 i; i < 3; i++) s().gangToken[i] = IERC20(_rewardsToken[i]);
    }

    function _enterRewardPool(uint256 gang, uint80 amount) internal {
        _updateReward(gang, msg.sender);

        s().totalShares[gang] += amount;
        s().userShares[msg.sender][gang] += amount;
    }

    function _exitRewardPool(uint256 gang, uint80 amount) internal {
        _updateReward(gang, msg.sender);

        s().totalShares[gang] -= amount;
        s().userShares[msg.sender][gang] -= amount;
    }

    function _setYield(
        uint256 gang,
        uint256 token,
        uint256 yield
    ) internal {
        _updateReward(gang, address(0));

        s().yield[gang][token] = uint80(yield);
    }

    function _transferYield(
        uint256 gangFrom,
        uint256 gangTo,
        uint256 token,
        uint256 yield
    ) internal {
        _updateReward(gangFrom, address(0));
        _updateReward(gangTo, address(0));

        s().yield[gangFrom][token] -= uint80(yield);
        s().yield[gangTo][token] += uint80(yield);
    }

    function _updateReward(uint256 gang, address account) internal {
        uint256 ypt_0 = s().totalYieldPerToken[gang][0];
        uint256 ypt_1 = s().totalYieldPerToken[gang][1];
        uint256 ypt_2 = s().totalYieldPerToken[gang][2];

        uint256 divisor = s().totalShares[gang] * 1 days;

        if (divisor != 0) {
            uint256 timeScaled = (block.timestamp - s().lastUpdateTime[gang]);

            ypt_0 += (timeScaled * s().yield[gang][0]) / divisor;
            ypt_1 += (timeScaled * s().yield[gang][1]) / divisor;
            ypt_2 += (timeScaled * s().yield[gang][2]) / divisor;

            s().totalYieldPerToken[gang][0] = uint80(ypt_0);
            s().totalYieldPerToken[gang][1] = uint80(ypt_1);
            s().totalYieldPerToken[gang][2] = uint80(ypt_2);
        }

        s().lastUpdateTime[gang] = uint80(block.timestamp);

        if (account != address(0)) {
            uint256 share = s().userShares[account][gang];

            s().gangToken[0].mint(account, (share * (ypt_0 - s().lastUserYieldPerToken[account][gang][0])));
            s().gangToken[1].mint(account, (share * (ypt_1 - s().lastUserYieldPerToken[account][gang][1])));
            s().gangToken[2].mint(account, (share * (ypt_2 - s().lastUserYieldPerToken[account][gang][2])));

            s().lastUserYieldPerToken[account][gang][0] = uint80(ypt_0);
            s().lastUserYieldPerToken[account][gang][1] = uint80(ypt_1);
            s().lastUserYieldPerToken[account][gang][2] = uint80(ypt_2);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";

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
    uint40[3] totalShares;
    uint40[3] lastUpdateTime;
    uint80[3][3] yield;
    uint80[3][3] totalYieldPerToken;
    mapping(address => uint80[3]) userShares;
    mapping(address => uint80[3]) userBalance;
    mapping(address => uint80[3][3]) lastUserYieldPerToken;
}

function s() pure returns (GangWarRewardsDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_GANG_WAR_REWARDS
    }
}

/// @notice Gang Staking Rewards
/// @author phaze (https://github.com/0xPhaze)
/// @author Adapted from Synthetix StakingRewards (https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol)
contract GangWarRewards {
    uint256 public immutable gangVaultFeesPercent;

    constructor(uint256 gangVaultFees) {
        require(gangVaultFees < 100); // invalid range

        gangVaultFeesPercent = gangVaultFees;
    }

    /* ------------- View ------------- */

    function getYield() external view returns (uint256[3][3] memory out) {
        uint80[3][3] memory yield = s().yield;
        assembly {out := yield} //prettier-ignore
    }

    // should only be called as view
    function getClaimableUserBalance(address account) external returns (uint256[3] memory out) {
        require(msg.sender == address(0));

        _updateUserReward(0, account);
        _updateUserReward(1, account);
        _updateUserReward(2, account);

        out[0] = uint256(s().userBalance[account][0]) * 1e10;
        out[1] = uint256(s().userBalance[account][1]) * 1e10;
        out[2] = uint256(s().userBalance[account][2]) * 1e10;
    }

    function getGangVaultBalance(uint256 gang) external returns (uint256[3] memory out) {
        require(msg.sender == address(0));

        // gang vault balances are stuck in user balances under address 1000, 1001, 1002.
        address gangVault = address(uint160(1000 + gang));
        uint256 numSharesTimes100 = s().totalShares[gang] * gangVaultFeesPercent;

        _updateReward(gang, gangVault, numSharesTimes100);

        out[0] = uint256(s().userBalance[gangVault][0]) * 1e10;
        out[1] = uint256(s().userBalance[gangVault][1]) * 1e10;
        out[2] = uint256(s().userBalance[gangVault][2]) * 1e10;
    }

    /* ------------- Enter/Exit ------------- */

    function _enterRewardPool(
        address account,
        uint256 gang,
        uint40 amount
    ) internal {
        _updateUserReward(gang, account);

        s().totalShares[gang] += amount;
        s().userShares[account][gang] += amount;
    }

    function _exitRewardPool(
        address account,
        uint256 gang,
        uint40 amount
    ) internal {
        _updateUserReward(gang, account);

        s().totalShares[gang] -= amount;
        s().userShares[account][gang] -= amount;
    }

    /* ------------- Claim/Spend ------------- */

    function _claimUserBalance(address account) internal {
        _updateUserReward(0, account);
        _updateUserReward(1, account);
        _updateUserReward(2, account);

        uint256 balance_0 = uint256(s().userBalance[account][0]) * 1e10;
        uint256 balance_1 = uint256(s().userBalance[account][1]) * 1e10;
        uint256 balance_2 = uint256(s().userBalance[account][2]) * 1e10;

        s().gangToken[0].mint(account, balance_0);
        s().gangToken[1].mint(account, balance_1);
        s().gangToken[2].mint(account, balance_2);

        s().userBalance[account][0] = 0;
        s().userBalance[account][1] = 0;
        s().userBalance[account][2] = 0;
    }

    function _spendGangVaultBalance(
        uint256 gang,
        uint256 amount_0,
        uint256 amount_1,
        uint256 amount_2
    ) internal {
        address gangVault = address(uint160(1000 + gang));
        uint256 numSharesTimes100 = s().totalShares[gang] * gangVaultFeesPercent;

        _updateReward(gang, gangVault, numSharesTimes100);

        uint256 balance_0 = uint256(s().userBalance[gangVault][0]) * 1e10;
        uint256 balance_1 = uint256(s().userBalance[gangVault][1]) * 1e10;
        uint256 balance_2 = uint256(s().userBalance[gangVault][2]) * 1e10;

        s().userBalance[gangVault][0] = uint80((balance_0 - amount_0) / 1e10);
        s().userBalance[gangVault][1] = uint80((balance_1 - amount_1) / 1e10);
        s().userBalance[gangVault][2] = uint80((balance_2 - amount_2) / 1e10);
    }

    /* ------------- Update ------------- */

    function _updateUserReward(uint256 gang, address account) internal {
        uint256 numSharesTimes100 = s().userShares[account][gang] * (100 - gangVaultFeesPercent);

        _updateReward(gang, account, numSharesTimes100);
    }

    function _updateGangReward(uint256 gang) internal {
        address account = address(uint160(1000 + gang));
        uint256 numSharesTimes100 = s().totalShares[gang] * gangVaultFeesPercent;

        _updateReward(gang, account, numSharesTimes100);
    }

    function _updateReward(
        uint256 gang,
        address account,
        uint256 numSharesTimes100
    ) private {
        // first update all cumulative yields per token
        uint256 ypt_0 = s().totalYieldPerToken[gang][0];
        uint256 ypt_1 = s().totalYieldPerToken[gang][1];
        uint256 ypt_2 = s().totalYieldPerToken[gang][2];

        uint256 divisor = uint256(s().totalShares[gang]) * 1 days;

        // if divisor is 0 then that means that totalShares = 0
        // meaning no one entered the stake and we don't need to update ypt
        // although note that because of this, a gang vault won't earn
        // if there are no stakers, even when owning districts
        if (divisor != 0) {
            // needs to be in the correct range
            // yield is daily yield with implicit 1e18 decimals
            // this number thus needs to be multiplied by 1e18
            // multiply by 1e8 first to ensure valid range (1e18 would overflow in 2^80)
            // multiply by 1e10 when claiming
            //
            // analysis for overflow assumptions (for 1e4 days / 30 years of staking):
            // s().yield[gang][token] < 1e12 (closer to 1e8)
            // timeScaled < (1e4 days) * 1e8 = 1e12 days
            // => numerator < 1e24 days
            // => divisor > 1 days
            // => max_ypt < 1e24 < 2^80

            uint256 timeScaled = (block.timestamp - s().lastUpdateTime[gang]) * 1e8;

            ypt_0 += (timeScaled * s().yield[gang][0]) / divisor;
            ypt_1 += (timeScaled * s().yield[gang][1]) / divisor;
            ypt_2 += (timeScaled * s().yield[gang][2]) / divisor;

            s().totalYieldPerToken[gang][0] = uint80(ypt_0);
            s().totalYieldPerToken[gang][1] = uint80(ypt_1);
            s().totalYieldPerToken[gang][2] = uint80(ypt_2);
        }

        s().lastUpdateTime[gang] = uint40(block.timestamp);

        // now update accrued user balances by calculating the difference with their last stored yield per token
        if (account != address(0)) {
            // for users:
            // uint256 numSharesTimes100 = s().userShares[account][gang] * 20;
            // for gang vault (all userShares sum to totalShares):
            // uint256 numSharesTimes100 = s().totalShares[gang] * 80;

            // further overflow assumptions:
            // divisor > 1 days * totalShares
            // userShares < totalShares
            // => s().userBalance <= max_ypt < 1e24 < 2^80
            s().userBalance[account][0] += uint80(numSharesTimes100 * (ypt_0 - s().lastUserYieldPerToken[account][gang][0]) / 100); //prettier-ignore
            s().userBalance[account][1] += uint80(numSharesTimes100 * (ypt_1 - s().lastUserYieldPerToken[account][gang][1]) / 100); //prettier-ignore
            s().userBalance[account][2] += uint80(numSharesTimes100 * (ypt_2 - s().lastUserYieldPerToken[account][gang][2]) / 100); //prettier-ignore

            s().lastUserYieldPerToken[account][gang][0] = uint80(ypt_0);
            s().lastUserYieldPerToken[account][gang][1] = uint80(ypt_1);
            s().lastUserYieldPerToken[account][gang][2] = uint80(ypt_2);
        }
    }

    /* ------------- Set ------------- */

    function _setGangTokens(address[3] memory _rewardsToken) internal {
        for (uint256 i; i < 3; i++) s().gangToken[i] = IERC20(_rewardsToken[i]);
    }

    function _setYield(
        uint256 gang,
        uint256 token,
        uint256 yield
    ) internal {
        _updateReward(gang, address(0), 0);

        require(yield <= 1e12); // implicit 1e18 decimals

        s().yield[gang][token] = uint80(yield);
    }

    function _transferYield(
        uint256 gangFrom,
        uint256 gangTo,
        uint256 token,
        uint256 yield
    ) internal {
        _updateReward(gangFrom, address(0), 0);
        _updateReward(gangTo, address(0), 0);

        s().yield[gangFrom][token] -= uint80(yield);
        s().yield[gangTo][token] += uint80(yield);
    }
}

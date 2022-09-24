// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GangToken} from "./tokens/GangToken.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {AccessControlUDS} from "UDS/auth/AccessControlUDS.sol";

// ------------- storage

bytes32 constant DIAMOND_STORAGE_GANG_VAULT = keccak256("diamond.storage.gang.vault.season.xxx.10");

struct GangVaultDS {
    uint40[3] totalShares;
    uint40[3] lastUpdateTime;
    uint80[3][3] yield;
    uint80[3][3] accruedYieldPerShare;
    mapping(address => uint40[3]) userShares;
    mapping(address => uint80[3]) userBalance;
    mapping(address => uint80[3]) accruedBalances;
    mapping(address => uint80[3][3]) lastUserYieldPerShare;
}

function s() pure returns (GangVaultDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_GANG_VAULT;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

/// @title Gangsta Mice City Gang Vault Rewards
/// @author phaze (https://github.com/0xPhaze)
contract GangVault is UUPSUpgrade, AccessControlUDS {
    GangVaultDS private __storageLayoutPersistent;

    event Burn(uint256 indexed gang, uint256 indexed token, uint256 amount);

    GangToken immutable token0;
    GangToken immutable token1;
    GangToken immutable token2;

    uint256 public immutable startTime;
    uint256 public immutable endTime;
    uint256 immutable gangVaultFeePercent;
    bytes32 constant CONTROLLER = keccak256("GANG.VAULT.CONTROLLER");

    constructor(
        uint256 startTime_,
        uint256 endTime_,
        address[3] memory gangTokens,
        uint256 gangVaultFee
    ) {
        // startTime = block.timestamp;
        // endTime = block.timestamp + 48 hours;
        endTime = endTime_;
        startTime = startTime_;
        gangVaultFeePercent = gangVaultFee;

        require(startTime < endTime);
        require(gangVaultFee < 100);
        // require(block.timestamp <= startTime);

        token0 = GangToken(gangTokens[0]);
        token1 = GangToken(gangTokens[1]);
        token2 = GangToken(gangTokens[2]);
    }

    function init() external initializer {
        __AccessControl_init();
    }

    /* ------------- external ------------- */

    function claimUserBalance() external {
        _updateUserBalance(0, msg.sender);
        _updateUserBalance(1, msg.sender);
        _updateUserBalance(2, msg.sender);

        uint256 balance_0 = uint256(s().userBalance[msg.sender][0]) * 1e10;
        uint256 balance_1 = uint256(s().userBalance[msg.sender][1]) * 1e10;
        uint256 balance_2 = uint256(s().userBalance[msg.sender][2]) * 1e10;

        token0.mint(msg.sender, balance_0);
        token1.mint(msg.sender, balance_1);
        token2.mint(msg.sender, balance_2);

        s().userBalance[msg.sender][0] = 0;
        s().userBalance[msg.sender][1] = 0;
        s().userBalance[msg.sender][2] = 0;
    }

    /* ------------- view ------------- */

    function getYield() external view returns (uint256[3][3] memory out) {
        uint80[3][3] memory yield = s().yield;
        assembly { out := yield } // prettier-ignore
    }

    function getUserShares(address account) external view returns (uint256[3] memory out) {
        uint40[3] memory shares = s().userShares[account];
        assembly { out := shares } // prettier-ignore
    }

    function getClaimableUserBalance(address account) public view returns (uint256[3] memory out) {
        uint256[3] memory unclaimed = _getUnclaimedUserBalance(account);

        out[0] = uint256(s().userBalance[account][0]) * 1e10 + unclaimed[0];
        out[1] = uint256(s().userBalance[account][1]) * 1e10 + unclaimed[1];
        out[2] = uint256(s().userBalance[account][2]) * 1e10 + unclaimed[2];
    }

    function getAccruedBalance(address account) external view returns (uint256[3] memory out) {
        uint256[3] memory unclaimed = _getUnclaimedUserBalance(account);

        out[0] = uint256(s().accruedBalances[account][0]) * 1e10 + unclaimed[0];
        out[1] = uint256(s().accruedBalances[account][1]) * 1e10 + unclaimed[1];
        out[2] = uint256(s().accruedBalances[account][2]) * 1e10 + unclaimed[2];
    }

    function getGangVaultBalance(uint256 gang) external view returns (uint256[3] memory out) {
        address gangAccount = _getGangAccount(gang);
        uint256[3] memory unclaimed = _getUnclaimedGangBalance(gang);

        out[0] = uint256(s().userBalance[gangAccount][0]) * 1e10 + unclaimed[0];
        out[1] = uint256(s().userBalance[gangAccount][1]) * 1e10 + unclaimed[1];
        out[2] = uint256(s().userBalance[gangAccount][2]) * 1e10 + unclaimed[2];
    }

    function getAccruedGangVaultBalances(uint256 gang) external view returns (uint256[3] memory out) {
        address gangAccount = _getGangAccount(gang);
        uint256[3] memory unclaimed = _getUnclaimedGangBalance(gang);

        out[0] = uint256(s().accruedBalances[gangAccount][0]) * 1e10 + unclaimed[0];
        out[1] = uint256(s().accruedBalances[gangAccount][1]) * 1e10 + unclaimed[1];
        out[2] = uint256(s().accruedBalances[gangAccount][2]) * 1e10 + unclaimed[2];
    }

    /* ------------- controller ------------- */

    function setYield(uint256 gang, uint256[3] calldata yield) external onlyRole(CONTROLLER) {
        _updateYieldPerShare(gang);

        // implicit 1e18 decimals
        require(yield[0] <= 1e12);
        require(yield[1] <= 1e12);
        require(yield[2] <= 1e12);

        s().yield[gang][0] = uint80(yield[0]);
        s().yield[gang][1] = uint80(yield[1]);
        s().yield[gang][2] = uint80(yield[2]);
    }

    function addShares(
        address account,
        uint256 gang,
        uint40 amount
    ) external onlyRole(CONTROLLER) {
        _updateYieldPerShare(gang);
        _updateUserBalance(gang, account);

        s().totalShares[gang] += amount;
        s().userShares[account][gang] += amount;
    }

    function removeShares(
        address account,
        uint256 gang,
        uint40 amount
    ) external onlyRole(CONTROLLER) {
        _updateYieldPerShare(gang);
        _updateUserBalance(gang, account);

        s().totalShares[gang] -= amount;
        s().userShares[account][gang] -= amount;
    }

    function transferShares(
        address from,
        address to,
        uint256 gang,
        uint40 amount
    ) external onlyRole(CONTROLLER) {
        _updateYieldPerShare(gang);
        _updateUserBalance(gang, from);
        _updateUserBalance(gang, to);

        s().userShares[from][gang] -= amount;
        s().userShares[to][gang] += amount;
    }

    function resetShares(address account, uint40[3] memory shares) external onlyRole(CONTROLLER) {
        for (uint256 i; i < 3; ++i) {
            _updateYieldPerShare(i);
            _updateUserBalance(i, account);

            s().totalShares[i] -= s().userShares[account][i];
            s().totalShares[i] += shares[i];
            s().userShares[account][i] = shares[i];
        }
    }

    function transferYield(
        uint256 gangFrom,
        uint256 gangTo,
        uint256 token,
        uint256 yield
    ) external onlyRole(CONTROLLER) {
        _updateYieldPerShare(gangFrom);
        _updateYieldPerShare(gangTo);

        s().yield[gangFrom][token] -= uint80(yield);
        s().yield[gangTo][token] += uint80(yield);
    }

    function spendGangVaultBalance(
        uint256 gang,
        uint256 amount_0,
        uint256 amount_1,
        uint256 amount_2,
        bool strict
    ) external onlyRole(CONTROLLER) {
        address gangAccount = _getGangAccount(gang);
        uint256 totalShares = s().totalShares[gang];
        uint256 numSharesTimes100 = max(totalShares, 1) * gangVaultFeePercent;

        _updateUserBalance(gang, gangAccount, numSharesTimes100);

        uint256 balance_0 = uint256(s().userBalance[gangAccount][0]) * 1e10;
        uint256 balance_1 = uint256(s().userBalance[gangAccount][1]) * 1e10;
        uint256 balance_2 = uint256(s().userBalance[gangAccount][2]) * 1e10;

        if (!strict) {
            amount_0 = balance_0 > amount_0 ? amount_0 : balance_0;
            amount_1 = balance_1 > amount_1 ? amount_1 : balance_1;
            amount_2 = balance_2 > amount_2 ? amount_2 : balance_2;
        }

        s().userBalance[gangAccount][0] = uint80((balance_0 - amount_0) / 1e10);
        s().userBalance[gangAccount][1] = uint80((balance_1 - amount_1) / 1e10);
        s().userBalance[gangAccount][2] = uint80((balance_2 - amount_2) / 1e10);

        if (amount_0 > 0) emit Burn(gang, 0, amount_0);
        if (amount_1 > 0) emit Burn(gang, 1, amount_1);
        if (amount_2 > 0) emit Burn(gang, 2, amount_2);
    }

    /* ------------- private ------------- */

    /// @dev gang vault balances are stuck in user balances under accounts 13370, 13371, 13372.
    function _getGangAccount(uint256 gang) private pure returns (address) {
        return address(uint160(13370 + gang));
    }

    function _updateYieldPerShare(uint256 gang) private {
        (uint256 yps_0, uint256 yps_1, uint256 yps_2) = _accruedYieldPerShare(gang);

        s().accruedYieldPerShare[gang][0] = uint80(yps_0);
        s().accruedYieldPerShare[gang][1] = uint80(yps_1);
        s().accruedYieldPerShare[gang][2] = uint80(yps_2);

        s().lastUpdateTime[gang] = uint40(block.timestamp);
    }

    function _accruedYieldPerShare(uint256 gang)
        private
        view
        returns (
            uint256 yps_0,
            uint256 yps_1,
            uint256 yps_2
        )
    {
        yps_0 = s().accruedYieldPerShare[gang][0];
        yps_1 = s().accruedYieldPerShare[gang][1];
        yps_2 = s().accruedYieldPerShare[gang][2];

        // setting to 1 allows gangs to earn if there are no stakers
        // though this is a degenerate case
        uint256 totalShares = max(s().totalShares[gang], 1);

        // needs to be in the correct range
        // yield is daily yield with implicit 1e18 decimals
        // this number thus needs to be multiplied by 1e18
        // multiply by 1e8 first to ensure valid range (1e18 would overflow in 2^80)
        // multiply by 1e10 when claiming

        // overflow assumptions (for 1e4 days / 30 years of staking):
        // s().yield[gang][token] < 1e12 (closer to 1e8)
        // timeScaled < (1e4 days) * 1e8 = 1e12 days
        // => numerator < 1e24 days
        // => divisor > 1 days
        // => max_yps < 1e24 < 2^80
        uint256 divisor = totalShares * 1 days;
        uint256 lastUpdateTime = s().lastUpdateTime[gang];

        // `lastUpdateTime` can become 0 when resetting to a new season.
        if (lastUpdateTime < startTime) lastUpdateTime = startTime;

        uint256 timestamp = block.timestamp > endTime ? endTime : block.timestamp;
        uint256 timeScaled = (timestamp > lastUpdateTime) ? (timestamp - lastUpdateTime) * 1e8 : 0;

        yps_0 += (timeScaled * s().yield[gang][0]) / divisor;
        yps_1 += (timeScaled * s().yield[gang][1]) / divisor;
        yps_2 += (timeScaled * s().yield[gang][2]) / divisor;
    }

    function _updateUserBalance(uint256 gang, address account) private {
        uint256 numSharesTimes100 = s().userShares[account][gang] * (100 - gangVaultFeePercent);

        _updateUserBalance(gang, account, numSharesTimes100);
    }

    function _updateUserBalance(
        uint256 gang,
        address account,
        uint256 numSharesTimes100
    ) private {
        (uint256 yps_0, uint256 yps_1, uint256 yps_2) = _accruedYieldPerShare(gang);

        // userBalance <= max_yps < 1e24 < 2^80
        uint80 addBalance_0 = uint80(numSharesTimes100 * (yps_0 - s().lastUserYieldPerShare[account][gang][0]) / 100); //prettier-ignore
        uint80 addBalance_1 = uint80(numSharesTimes100 * (yps_1 - s().lastUserYieldPerShare[account][gang][1]) / 100); //prettier-ignore
        uint80 addBalance_2 = uint80(numSharesTimes100 * (yps_2 - s().lastUserYieldPerShare[account][gang][2]) / 100); //prettier-ignore

        s().userBalance[account][0] += addBalance_0;
        s().userBalance[account][1] += addBalance_1;
        s().userBalance[account][2] += addBalance_2;

        s().accruedBalances[account][0] += addBalance_0;
        s().accruedBalances[account][1] += addBalance_1;
        s().accruedBalances[account][2] += addBalance_2;

        s().lastUserYieldPerShare[account][gang][0] = uint80(yps_0);
        s().lastUserYieldPerShare[account][gang][1] = uint80(yps_1);
        s().lastUserYieldPerShare[account][gang][2] = uint80(yps_2);
    }

    function _getUnclaimedUserBalance(address account) private view returns (uint256[3] memory out) {
        uint256 sharesFactor = 100 - gangVaultFeePercent;

        uint256 numSharesTimes100_0 = uint256(s().userShares[account][0]) * sharesFactor;
        uint256 numSharesTimes100_1 = uint256(s().userShares[account][1]) * sharesFactor;
        uint256 numSharesTimes100_2 = uint256(s().userShares[account][2]) * sharesFactor;

        uint256[3] memory balances_0 = _getUnclaimedUserBalance(0, account, numSharesTimes100_0);
        uint256[3] memory balances_1 = _getUnclaimedUserBalance(1, account, numSharesTimes100_1);
        uint256[3] memory balances_2 = _getUnclaimedUserBalance(2, account, numSharesTimes100_2);

        out[0] = balances_0[0] + balances_1[0] + balances_2[0];
        out[1] = balances_0[1] + balances_1[1] + balances_2[1];
        out[2] = balances_0[2] + balances_1[2] + balances_2[2];
    }

    function _getUnclaimedUserBalance(
        uint256 gang,
        address account,
        uint256 numSharesTimes100
    ) private view returns (uint256[3] memory balances) {
        (uint256 yps_0, uint256 yps_1, uint256 yps_2) = _accruedYieldPerShare(gang);

        balances[0] = numSharesTimes100 * (yps_0 - s().lastUserYieldPerShare[account][gang][0]) * 1e10 / 100; //prettier-ignore
        balances[1] = numSharesTimes100 * (yps_1 - s().lastUserYieldPerShare[account][gang][1]) * 1e10 / 100; //prettier-ignore
        balances[2] = numSharesTimes100 * (yps_2 - s().lastUserYieldPerShare[account][gang][2]) * 1e10 / 100; //prettier-ignore
    }

    function _getUnclaimedGangBalance(uint256 gang) private view returns (uint256[3] memory balances) {
        address gangAccount = _getGangAccount(gang);
        uint256 totalShares = s().totalShares[gang];
        uint256 numSharesTimes100 = max(totalShares, 1) * gangVaultFeePercent;

        balances = _getUnclaimedUserBalance(gang, gangAccount, numSharesTimes100);
    }

    /* ------------- upgrade ------------- */

    function _authorizeUpgrade() internal view override onlyRole(DEFAULT_ADMIN_ROLE) {}
}

function max(uint256 a, uint256 b) pure returns (uint256) {
    return a < b ? b : a;
}

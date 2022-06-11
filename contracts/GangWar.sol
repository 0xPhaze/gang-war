// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeV} from "UDS/proxy/UUPSUpgradeV.sol";
import {OwnableUDS} from "UDS/OwnableUDS.sol";
import {ERC721UDS} from "UDS/ERC721UDS.sol";

// import {GangWarBase} from "./GangWarBase.sol";
import {GMCMarket} from "./GMCMarket.sol";
// import {ds, settings, District, Gangster} from
import "./GangWarStorage.sol";
import "./GangWarRewards.sol";
// import "./GangWarBase.sol";

import "forge-std/console.sol";

import "./lib/ArrayUtils.sol";

/* ============= Error ============= */

error BaronMustDeclareInitialAttack();
error IdsMustBeOfSameGang();
error ConnectingDistrictNotOwnedByGang();
error InvalidConnectingDistrict();
error GangsterInactionable();
error BaronInactionable();
error CallerNotOwner();

error MoveOnCooldown();
error TokenMustBeGangster();
error TokenMustBeBaron();
error BaronAttackAlreadyDeclared();
error CannotAttackDistrictOwnedByGang();

contract GangWar is UUPSUpgradeV(1), OwnableUDS, GangWarStorage, GangWarBase, GangWarRewards, GMCMarket {
    ERC721UDS gmc;

    function init(ERC721UDS gmc_) external initializer {
        __Ownable_init();

        gmc = gmc_;

        constants().TIME_GANG_WAR = 100;
        constants().TIME_LOCKUP = 100;
        constants().TIME_RECOVERY = 100;
        constants().TIME_REINFORCEMENTS = 100;

        constants().DEFENSE_FAVOR_LIM = 150;
        constants().BARON_DEFENSE_FORCE = 50;
        constants().ATTACK_FAVOR = 65;
        constants().DEFENSE_FAVOR = 200;

        for (uint256 id; id < 21; ++id) {
            ds().districts[id].roundId = 1;
            ds().districts[id].occupants = GANG((id % 3) + 1);
            ds().districtYield[id] = 100 + (id / 3);
        }

        initializeGangRewards();
    }

    /* ------------- Public ------------- */

    function baronDeclareAttack(
        uint256 connectingId,
        uint256 districtId,
        uint256 tokenId
    ) public {
        GANG gang = gangOf(tokenId);
        District storage district = ds().districts[districtId];

        // console.log('occupants', ds().districts[connecting])

        if (!isBaron(tokenId)) revert TokenMustBeBaron();
        if (gmc.ownerOf(tokenId) != msg.sender) revert CallerNotOwner();
        if (district.baronAttackId != 0) revert BaronAttackAlreadyDeclared();
        if (ds().districts[districtId].occupants == gang) revert CannotAttackDistrictOwnedByGang();
        if (ds().districts[connectingId].occupants != gang) revert ConnectingDistrictNotOwnedByGang();
        if (districtId == connectingId || !isConnecting(connectingId, districtId)) revert InvalidConnectingDistrict();

        (PLAYER_STATE state, ) = _gangsterStateAndCountdown(tokenId);

        if (state != PLAYER_STATE.IDLE) revert BaronInactionable();

        Gangster storage baron = ds().gangsters[1001];

        baron.location = districtId;
        baron.roundId = ds().districts[districtId].roundId;

        district.attackers = gang;
        district.baronAttackId = tokenId;
        district.attackDeclarationTime = block.timestamp;
    }

    function joinGangAttack(
        uint256 connectingId,
        uint256 districtId,
        uint256[] calldata tokenIds
    ) public {
        GANG gang = gangOf(tokenIds[0]);
        District storage district = ds().districts[districtId];

        // validate baron attack declaration / (+special items)
        if (ds().districts[connectingId].occupants != gang) revert InvalidConnectingDistrict();
        if (gangOf(district.baronAttackId) != gang) revert BaronMustDeclareInitialAttack();
        if (districtId == connectingId || !ds().districtConnections[connectingId][districtId])
            revert InvalidConnectingDistrict();

        _joinGangWar(districtId, tokenIds);
    }

    function joinGangDefense(uint256 districtId, uint256[] calldata tokenIds) public {
        GANG gang = gangOf(tokenIds[0]);

        if (ds().districts[districtId].occupants != gang) revert InvalidConnectingDistrict();

        _joinGangWar(districtId, tokenIds);
    }

    function _joinGangWar(uint256 districtId, uint256[] calldata tokenIds) internal {
        uint256 tokenId;
        Gangster storage gangster;
        District storage district = ds().districts[districtId];

        GANG gang = gangOf(tokenIds[0]);

        uint256 districtRoundId = district.roundId;

        for (uint256 i; i < tokenIds.length; ++i) {
            tokenId = tokenIds[i];

            if (isBaron(tokenId)) revert TokenMustBeGangster();
            if (gang != gangOf(tokenId)) revert IdsMustBeOfSameGang();
            if (gmc.ownerOf(tokenId) != msg.sender) revert CallerNotOwner();

            gangster = ds().gangsters[tokenId];

            (PLAYER_STATE state, ) = _gangsterStateAndCountdown(tokenId);

            if (
                state == PLAYER_STATE.ATTACK_LOCKED ||
                state == PLAYER_STATE.DEFEND_LOCKED ||
                state == PLAYER_STATE.INJURED ||
                state == PLAYER_STATE.LOCKUP
            ) revert GangsterInactionable();

            gangster.location = districtId;
            gangster.roundId = districtRoundId;

            // _validateGangMemberIsActionable(gangster);

            // remove from old district
        }

        ds().districtAttackForces[districtId][districtRoundId][gang] += tokenIds.length;
    }

    /* ------------- Internal ------------- */

    function isConnecting(uint256 districtA, uint256 districtB) internal view returns (bool) {
        return
            districtA < districtB
                ? ds().districtConnections[districtA][districtB]
                : ds().districtConnections[districtB][districtA]; // prettier-ignore
    }

    function _validateConnectingDistrict(uint256 districtId, uint256 connectingId) internal view {
        if (!(districtId == connectingId || ds().districtConnections[districtId][connectingId]))
            revert InvalidConnectingDistrict();
    }

    function isBaron(uint256 tokenId) internal pure returns (bool) {
        return tokenId >= 1000;
    }

    function _gangsterStateAndCountdown(uint256 gangsterId) internal view returns (PLAYER_STATE, int256) {
        Gangster storage gangster = ds().gangsters[gangsterId];

        uint256 districtId = gangster.location;
        District storage district = ds().districts[districtId];

        GANG gang = gangOf(gangsterId);

        uint256 roundId = district.roundId;

        // gangster not in sync with district => IDLE
        if (gangster.roundId != roundId) return (PLAYER_STATE.IDLE, 0);

        bool attacking;

        if (district.attackers == gang) attacking = true;
        else assert(district.occupants == gang);
        // else if (district.occupants == gang) {
        //     attacking = false;
        // }

        int256 stateCountdown;

        // -------- check lockup
        stateCountdown = int256(constants().TIME_LOCKUP) - int256(block.timestamp - district.lockupTime);
        if (stateCountdown > 0) return (PLAYER_STATE.LOCKUP, stateCountdown);

        // -------- check gang war outcome
        stateCountdown =
            int256(constants().TIME_REINFORCEMENTS) -
            int256(block.timestamp - district.attackDeclarationTime);
        uint256 outcome = ds().gangWarOutcomes[districtId][roundId];

        // player in attack/defense mode; not committed yet
        if (stateCountdown > 0) return (attacking ? PLAYER_STATE.ATTACK : PLAYER_STATE.DEFEND, stateCountdown);

        stateCountdown += int256(constants().TIME_GANG_WAR);

        // outcome can only be triggered by upkeep after additional TIME_GANG_WAR has passed
        // this will release players from lock after injury has been checked
        if (outcome == 0) return (attacking ? PLAYER_STATE.ATTACK_LOCKED : PLAYER_STATE.DEFEND_LOCKED, stateCountdown);

        // -------- check injury
        bool injured = outcome & 1 == 0;

        if (!injured) return (PLAYER_STATE.IDLE, 0);

        stateCountdown = int256(constants().TIME_RECOVERY) + stateCountdown;
        if (stateCountdown > 0) return (PLAYER_STATE.INJURED, stateCountdown);

        return (PLAYER_STATE.IDLE, 0);
    }

    function _districtStatus(District storage district) internal view returns (DISTRICT_STATUS) {
        uint256 attackDeclarationTime = district.attackDeclarationTime;

        if (attackDeclarationTime == 0 || attackDeclarationTime < district.lastUpkeepTime) {
            return DISTRICT_STATUS.IDLE;
        }
        if (block.timestamp - attackDeclarationTime < constants().TIME_REINFORCEMENTS + constants().TIME_GANG_WAR) {
            return DISTRICT_STATUS.ATTACK;
        }
        return DISTRICT_STATUS.POST_ATTACK;
    }

    /* ------------- Upkeep ------------- */

    uint256 public immutable UPKEEP_INTERVAL = 15;

    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view returns (bool, bytes memory) {
        bool upkeepNeeded;
        District storage district;

        uint256[] memory districtUpkeepIds;

        for (uint256 id; id < 21; ++id) {
            district = ds().districts[id];

            if (_districtStatus(district) == DISTRICT_STATUS.POST_ATTACK) {
                upkeepNeeded = true;
                districtUpkeepIds = ArrayUtils.extend(districtUpkeepIds, id);
            }
        }

        return (upkeepNeeded, abi.encode(districtUpkeepIds));
    }

    // @note could exceed gas limits
    // @note should request via VRF
    function performUpkeep(bytes calldata performData) external {
        uint256[] memory districtIds = abi.decode(performData, (uint256[]));

        uint256 length = districtIds.length;
        // sole.log("len", length);

        for (uint256 i; i < length; ++i) {
            // nsole.log("i", districtIds[i]);

            uint256 districtId = districtIds[i];
            District storage district = ds().districts[districtId];

            GANG occupants = district.occupants;
            GANG attackers = district.attackers;

            if (_districtStatus(district) == DISTRICT_STATUS.POST_ATTACK) {
                district.attackDeclarationTime = 0;
                district.lastUpkeepTime = block.timestamp;

                uint256 roundId = district.roundId++;

                uint256 rand = uint256(blockhash(block.number - 1));

                ds().gangWarOutcomes[districtId][roundId] = rand;

                if (gangWarWon(districtId, roundId, rand)) {
                    updateGangRewards(attackers, occupants, districtId);

                    district.occupants = attackers;
                    district.attackers = GANG.NONE;
                }

                district.baronAttackId = 0;
                district.baronDefenseId = 0;

                // request
            }
        }
    }

    function gangWarWon(
        uint256 districtId,
        uint256 roundId,
        uint256 rand
    ) public view returns (bool) {
        District storage district = ds().districts[districtId];

        uint256 attackForce = ds().districtAttackForces[districtId][roundId][district.attackers];
        uint256 defenseForce = ds().districtDefenseForces[districtId][roundId][district.occupants];

        bool baronDefense = district.baronDefenseId != 0;

        return rand % 10_000 < gangWarWonProb(attackForce, defenseForce, baronDefense);
    }

    function gangWarWonProb(
        uint256 attackForce,
        uint256 defenseForce,
        bool baronDefense
    ) public view returns (uint256) {
        attackForce += 1;
        defenseForce += 1;

        // if (attackForce == 0) return 0;

        // @note make more precise with shifts
        uint256 defenseFavorLim = constants().DEFENSE_FAVOR_LIM;
        uint256 s = attackForce > defenseFavorLim ? 10_000 : 10_000 - (100 - (100 * attackForce) / defenseFavorLim)**2;

        defenseForce =
            ((s * constants().ATTACK_FAVOR + (10_000 - s) * constants().DEFENSE_FAVOR) * defenseForce) /
            10_000 /
            100;

        // constants().BARON_DEFENSE_FORCE;
        if (baronDefense) defenseForce += 10_000 * constants().BARON_DEFENSE_FORCE;

        uint256 p = (10_000 * 10_000 * attackForce) / (10_000 * attackForce + defenseForce);

        if (p > 10_000) p = 10_000**3 - 4 * (10_000 - p)**3;
        else p = 4 * (p)**3;

        return p / 10_000**2;
    }

    function gangOf(uint256 id) public pure returns (GANG) {
        return id == 0 ? GANG.NONE : GANG(((id < 1000 ? id - 1 : id - 1001) % 3) + 1);
    }

    function getGangster(uint256 tokenId) external view returns (GangsterView memory gangster) {
        Gangster storage gangsterStore = ds().gangsters[tokenId];

        (gangster.state, gangster.stateCountdown) = _gangsterStateAndCountdown(tokenId);
        gangster.roundId = gangsterStore.roundId;
        gangster.location = gangsterStore.location;
    }

    /* ------------- Owner ------------- */

    function setDistrictsInitialOwnership(uint256[] calldata districtIds, GANG[] calldata gangs) external onlyOwner {
        for (uint256 i; i < districtIds.length; ++i) {
            ds().districts[districtIds[i]].occupants = gangs[i];
        }
    }

    function addDistrictConnections(uint256[] calldata districtsA, uint256[] calldata districtsB) external onlyOwner {
        for (uint256 i; i < districtsA.length; ++i) {
            assert(districtsA[i] < districtsB[i]);
            ds().districtConnections[districtsA[i]][districtsB[i]] = true;
        }
    }

    function removeDistrictConnections(uint256[] calldata districtsA, uint256[] calldata districtsB)
        external
        onlyOwner
    {
        for (uint256 i; i < districtsA.length; ++i) {
            assert(districtsA[i] < districtsB[i]);
            ds().districtConnections[districtsA[i]][districtsB[i]] = false;
        }
    }

    /* ------------- Internal ------------- */

    modifier validOwner(uint256 id) {
        // if (!gmc.ownerOf(id) == msg.sender) revert NotAuthorized();
        _;
    }

    function _authorizeUpgrade() internal override onlyOwner {}
}

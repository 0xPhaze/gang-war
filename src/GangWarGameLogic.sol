// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeV} from "UDS/proxy/UUPSUpgradeV.sol";
import {OwnableUDS} from "UDS/OwnableUDS.sol";
import {ERC721UDS} from "UDS/ERC721UDS.sol";

// import {s, settings, District, Gangster} from
import "./GangWarStorage.sol";

// import "forge-std/console.sol";

import "./lib/ArrayUtils.sol";
import {VRFConsumerV2} from "./lib/VRFConsumerV2.sol";

/* ============= Error ============= */

error BaronMustDeclareInitialAttack();
error IdsMustBeOfSameGang();
error ConnectingDistrictNotOwnedByGang();
error GangsterInactionable();
error BaronInactionable();
error InvalidConnectingDistrict();

error MoveOnCooldown();
error TokenMustBeGangster();
error TokenMustBeBaron();
error BaronAttackAlreadyDeclared();
error CannotAttackDistrictOwnedByGang();

function gangWarWonProb(
    uint256 attackForce,
    uint256 defenseForce,
    bool baronDefense,
    uint256 c_attackFavor,
    uint256 c_defenseFavor,
    uint256 c_defenseFavorLim,
    uint256 c_baronDefenseForce
) pure returns (uint256) {
    attackForce += 1;
    defenseForce += 1;

    uint256 s = attackForce < c_defenseFavorLim
            ? ((1 << 32) - (attackForce << 32) / c_defenseFavorLim)**2
            : 0; // prettier-ignore

    defenseForce = ((s * c_defenseFavor + ((1 << 64) - s) * c_attackFavor) * defenseForce) / 100;

    if (baronDefense) defenseForce += c_baronDefenseForce << 64;

    uint256 p = (attackForce << 128) / ((attackForce << 64) + defenseForce);

    if (p > 1 << 63) p = (1 << 192) - ((((1 << 64) - p)**3) << 2);
    else p = (p**3) << 2;

    return p >> 64; // >> 128
}

abstract contract GangWarGameLogic is GangWarBase, VRFConsumerV2 {
    function __GangWarGameLogic_init() internal {}

    /* ------------- Public ------------- */

    function baronDeclareAttack(
        uint256 connectingId,
        uint256 districtId,
        uint256 tokenId
    ) external {
        Gang gang = gangOf(tokenId);
        District storage district = s().districts[districtId];

        // console.log('occupants', s().districts[connecting])

        _validateOwnership(msg.sender, tokenId);

        if (!isBaron(tokenId)) revert TokenMustBeBaron();
        if (district.baronAttackId != 0) revert BaronAttackAlreadyDeclared();
        if (s().districts[districtId].occupants == gang) revert CannotAttackDistrictOwnedByGang();
        if (s().districts[connectingId].occupants != gang) revert ConnectingDistrictNotOwnedByGang();
        if (districtId == connectingId || !isConnecting(connectingId, districtId)) revert InvalidConnectingDistrict();

        (PLAYER_STATE state, ) = _gangsterStateAndCountdown(tokenId);

        if (state != PLAYER_STATE.IDLE) revert BaronInactionable();

        Gangster storage baron = s().gangsters[tokenId];

        baron.location = districtId;
        baron.roundId = s().districts[districtId].roundId;

        district.attackers = gang;
        district.baronAttackId = tokenId;
        district.attackDeclarationTime = block.timestamp;
    }

    function joinGangAttack(
        uint256 connectingId,
        uint256 districtId,
        uint256[] calldata tokenIds
    ) public {
        Gang gang = gangOf(tokenIds[0]);
        District storage district = s().districts[districtId];

        if (s().districts[connectingId].occupants != gang) revert InvalidConnectingDistrict();
        if (gangOf(district.baronAttackId) != gang) revert BaronMustDeclareInitialAttack();
        if (districtId == connectingId || !s().districtConnections[connectingId][districtId])
            revert InvalidConnectingDistrict();

        _joinGangWar(districtId, tokenIds);
    }

    function joinGangDefense(uint256 districtId, uint256[] calldata tokenIds) public {
        Gang gang = gangOf(tokenIds[0]);

        if (s().districts[districtId].occupants != gang) revert InvalidConnectingDistrict();

        _joinGangWar(districtId, tokenIds);
    }

    function _joinGangWar(uint256 districtId, uint256[] calldata tokenIds) internal {
        uint256 tokenId;
        Gangster storage gangster;
        District storage district = s().districts[districtId];

        Gang gang = gangOf(tokenIds[0]);

        uint256 districtRoundId = district.roundId;

        for (uint256 i; i < tokenIds.length; ++i) {
            tokenId = tokenIds[i];

            if (isBaron(tokenId)) revert TokenMustBeGangster();
            if (gang != gangOf(tokenId)) revert IdsMustBeOfSameGang();
            _validateOwnership(msg.sender, tokenId);

            gangster = s().gangsters[tokenId];

            (PLAYER_STATE state, ) = _gangsterStateAndCountdown(tokenId);

            if (
                state == PLAYER_STATE.ATTACK_LOCKED ||
                state == PLAYER_STATE.DEFEND_LOCKED ||
                state == PLAYER_STATE.INJURED ||
                state == PLAYER_STATE.LOCKUP
            ) revert GangsterInactionable();

            gangster.location = districtId;
            gangster.roundId = districtRoundId;

            // @remove from old district
        }

        s().districtAttackForces[districtId][districtRoundId][gang] += tokenIds.length;
    }

    /* ------------- Internal ------------- */

    function getGangster(uint256 tokenId) external view returns (GangsterView memory gangster) {
        Gangster storage gangsterStore = s().gangsters[tokenId];

        (gangster.state, gangster.stateCountdown) = _gangsterStateAndCountdown(tokenId);
        gangster.roundId = gangsterStore.roundId;
        gangster.location = gangsterStore.location;
    }

    function getDistrictAndState(uint256 districtId) external view returns (District memory, DISTRICT_STATE) {
        return (s().districts[districtId], _districtStatus(s().districts[districtId]));
    }

    function _gangsterStateAndCountdown(uint256 gangsterId) internal view returns (PLAYER_STATE, int256) {
        Gangster storage gangster = s().gangsters[gangsterId];

        uint256 districtId = gangster.location;
        District storage district = s().districts[districtId];

        Gang gang = gangOf(gangsterId);

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
        uint256 outcome = s().gangWarOutcomes[districtId][roundId];

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

    function _districtStatus(District storage district) internal view returns (DISTRICT_STATE) {
        uint256 attackDeclarationTime = district.attackDeclarationTime;

        // console.log("atk", attackDeclarationTime);
        // console.log("upk", district.lastUpkeepTime);

        if (attackDeclarationTime == 0 || attackDeclarationTime < district.lastOutcomeTime) {
            if (block.timestamp - district.lastOutcomeTime < constants().TIME_TRUCE) return DISTRICT_STATE.TRUCE;

            return DISTRICT_STATE.IDLE;
        }
        uint256 timeDelta = block.timestamp - attackDeclarationTime;
        if (timeDelta < constants().TIME_REINFORCEMENTS) {
            return DISTRICT_STATE.REINFORCEMENT;
        }
        timeDelta -= constants().TIME_REINFORCEMENTS;
        if (timeDelta < constants().TIME_GANG_WAR) {
            return DISTRICT_STATE.GANG_WAR;
        }
        return DISTRICT_STATE.POST_GANG_WAR;
    }

    /* ------------- Upkeep ------------- */

    uint256 private constant UPKEEP_INTERVAL = 5 minutes;

    function checkUpkeep(bytes calldata) external view returns (bool, bytes memory) {
        bool upkeepNeeded;
        District storage district;

        uint256[] memory districtUpkeepIds;

        for (uint256 id; id < 21; ++id) {
            district = s().districts[id];

            if (
                _districtStatus(district) == DISTRICT_STATE.POST_GANG_WAR &&
                block.timestamp - district.lastUpkeepTime > UPKEEP_INTERVAL // at least wait 1 minute for re-run
            ) {
                upkeepNeeded = true;
                districtUpkeepIds = ArrayUtils.extend(districtUpkeepIds, id);
            }
        }

        return (upkeepNeeded, abi.encode(districtUpkeepIds));
    }

    // @note could exceed gas limits
    function performUpkeep(bytes calldata performData) external {
        uint256[] memory districtIds = abi.decode(performData, (uint256[]));

        uint256 length = districtIds.length;

        for (uint256 i; i < length; ++i) {
            uint256 districtId = districtIds[i];
            District storage district = s().districts[districtId];

            if (
                _districtStatus(district) == DISTRICT_STATE.POST_GANG_WAR &&
                block.timestamp - district.lastUpkeepTime > UPKEEP_INTERVAL // at least wait 1 minute for re-run
            ) {
                district.lastUpkeepTime = block.timestamp;
                uint256 requestId = requestRandomWords(1);
                s().requestIdToDistrictIds[requestId] = districtIds;
            }
        }
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256[] storage districtIds = s().requestIdToDistrictIds[requestId];
        uint256 length = districtIds.length;
        uint256 rand = randomWords[0];

        for (uint256 i; i < length; ++i) {
            uint256 districtId = districtIds[i];

            District storage district = s().districts[districtId];

            if (_districtStatus(district) == DISTRICT_STATE.POST_GANG_WAR) {
                Gang occupants = district.occupants;
                Gang attackers = district.attackers;

                uint256 roundId = district.roundId++;

                uint256 r = uint256(keccak256(abi.encode(rand, i)));

                s().gangWarOutcomes[districtId][roundId] = r;
                district.lastOutcomeTime = block.timestamp;

                if (gangWarWon(districtId, roundId, r)) {
                    _afterDistrictTransfer(attackers, occupants, districtId);

                    district.occupants = attackers;
                    district.attackers = Gang.NONE;
                }

                district.attackDeclarationTime = 0;
                district.baronAttackId = 0;
                district.baronDefenseId = 0;
            }
        }

        delete s().requestIdToDistrictIds[requestId];
    }

    /* ------------- Private ------------- */

    function gangWarWon(
        uint256 districtId,
        uint256 roundId,
        uint256 rand
    ) private view returns (bool) {
        District storage district = s().districts[districtId];

        uint256 attackForce = s().districtAttackForces[districtId][roundId][district.attackers];
        uint256 defenseForce = s().districtDefenseForces[districtId][roundId][district.occupants];

        bool baronDefense = district.baronDefenseId != 0;

        uint256 c_defenseFavorLim = constants().DEFENSE_FAVOR_LIM;
        uint256 c_baronDefenseForce = constants().BARON_DEFENSE_FORCE;
        uint256 c_attackFavor = constants().ATTACK_FAVOR;
        uint256 c_defenseFavor = constants().DEFENSE_FAVOR;

        return
            rand >> 128 <
            gangWarWonProb(
                attackForce,
                defenseForce,
                baronDefense,
                c_attackFavor,
                c_defenseFavor,
                c_defenseFavorLim,
                c_baronDefenseForce
            );
    }

    /* ------------- Internal ------------- */
}

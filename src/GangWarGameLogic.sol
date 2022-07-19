// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";

// import {s, settings, District, Gangster} from
import "./GangWarBase.sol";

// import "forge-std/console.sol";

import "./lib/ArrayUtils.sol";
import {VRFConsumerV2} from "./lib/VRFConsumerV2.sol";

// ------------- Error

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

error InvalidVRFRequest();

function gangWarWonProb(
    uint256 attackForce,
    uint256 defenseForce,
    bool baronDefense
) pure returns (uint256) {
    attackForce += 1;
    defenseForce += 1;

    uint256 q = attackForce < DEFENSE_FAVOR_LIM
            ? ((1 << 32) - (attackForce << 32) / DEFENSE_FAVOR_LIM)**2
            : 0; // prettier-ignore

    defenseForce = ((q * DEFENSE_FAVOR + ((1 << 64) - q) * ATTACK_FAVOR) * defenseForce) / 100;

    if (baronDefense) defenseForce += BARON_DEFENSE_FORCE << 64;

    uint256 p = (attackForce << 128) / ((attackForce << 64) + defenseForce);

    if (p > 1 << 63) p = (1 << 192) - ((((1 << 64) - p)**3) << 2);
    else p = (p**3) << 2;

    return p >> 64; // >> 128
}

abstract contract GangWarGameLogic is GangWarBase, VRFConsumerV2 {
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
        if (districtId == connectingId || !isConnecting(connectingId, districtId)) revert InvalidConnectingDistrict();

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
        return (s().districts[districtId], _districtState(s().districts[districtId]));
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
        // else assert(district.occupants == gang);

        int256 stateCountdown;

        // -------- check lockup (takes precedence)
        uint256 lockupTime = district.lockupTime;
        stateCountdown = int256(TIME_LOCKUP) - int256(block.timestamp - lockupTime);
        if (stateCountdown > 0 && lockupTime != 0) return (PLAYER_STATE.LOCKUP, stateCountdown);

        // -------- check gang war outcome
        uint256 attackDeclarationTime = district.attackDeclarationTime;

        if (attackDeclarationTime == 0) return (PLAYER_STATE.IDLE, 0);

        stateCountdown = int256(TIME_REINFORCEMENTS) - int256(block.timestamp - attackDeclarationTime);

        // player in reinforcement phase; not committed yet
        if (stateCountdown > 0) return (attacking ? PLAYER_STATE.ATTACK : PLAYER_STATE.DEFEND, stateCountdown);

        stateCountdown += int256(TIME_GANG_WAR);

        if (stateCountdown > 0)
            return (attacking ? PLAYER_STATE.ATTACK_LOCKED : PLAYER_STATE.DEFEND_LOCKED, stateCountdown);

        // outcome can only be triggered by upkeep after additional TIME_GANG_WAR has passed
        // this will release players from lock after injury has been checked
        uint256 gRand = s().gangWarOutcomes[districtId][roundId];

        // this is when the vrf callback hasn't completed yet
        if (gRand == 0) return (attacking ? PLAYER_STATE.ATTACK_LOCKED : PLAYER_STATE.DEFEND_LOCKED, 0);

        // -------- check injury
        bool injured = isInjured(gangsterId, districtId, roundId, gRand);

        if (!injured) return (PLAYER_STATE.IDLE, 0);

        stateCountdown = int256(TIME_RECOVERY) + stateCountdown;
        if (stateCountdown > 0) return (PLAYER_STATE.INJURED, stateCountdown);

        return (PLAYER_STATE.IDLE, 0);
    }

    function _districtState(District storage district) internal view returns (DISTRICT_STATE) {
        uint256 attackDeclarationTime = district.attackDeclarationTime;
        uint256 lastOutcomeTime = district.lastOutcomeTime;

        // console.log("atk", attackDeclarationTime);
        // console.log("upk", district.lastUpkeepTime);

        if (attackDeclarationTime == 0 || attackDeclarationTime < lastOutcomeTime) {
            if (block.timestamp - lastOutcomeTime < TIME_TRUCE) return DISTRICT_STATE.TRUCE;

            return DISTRICT_STATE.IDLE;
        }

        uint256 timeDelta = block.timestamp - attackDeclarationTime;

        if (timeDelta < TIME_REINFORCEMENTS) return DISTRICT_STATE.REINFORCEMENT;

        timeDelta -= TIME_REINFORCEMENTS;

        if (timeDelta < TIME_GANG_WAR) return DISTRICT_STATE.GANG_WAR;

        return DISTRICT_STATE.POST_GANG_WAR;
    }

    /* ------------- Upkeep ------------- */

    uint256 private constant UPKEEP_INTERVAL = 5 minutes;

    function checkUpkeep(bytes calldata) external view returns (bool, bytes memory) {
        uint256 ids;
        District storage district;

        for (uint256 id; id < 21; ++id) {
            district = s().districts[id];

            if (
                _districtState(district) == DISTRICT_STATE.POST_GANG_WAR &&
                block.timestamp - district.lastUpkeepTime > UPKEEP_INTERVAL // at least wait 1 minute for re-run
            ) {
                ids |= 1 << id;
            }
        }

        return (ids > 0, abi.encode(ids));
    }

    // @note could exceed gas limits
    function performUpkeep(bytes calldata performData) external {
        uint256 ids = abi.decode(performData, (uint256));
        District storage district;

        for (uint256 id; id < 21; ++id) {
            if ((ids >> id) & 1 != 0) {
                district = s().districts[id];

                if (
                    _districtState(district) == DISTRICT_STATE.POST_GANG_WAR &&
                    block.timestamp - district.lastUpkeepTime > UPKEEP_INTERVAL // at least wait 1 minute for re-run
                ) {
                    district.lastUpkeepTime = block.timestamp;
                } else {
                    ids &= ~uint256(1 << id);
                }
            }
        }

        if (ids > 0) {
            uint256 requestId = requestRandomWords(1);
            s().requestIdToDistrictIds[requestId] = ids;
        }
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 ids = s().requestIdToDistrictIds[requestId];

        if (ids == 0) revert InvalidVRFRequest();

        uint256 rand = randomWords[0];
        District storage district;

        for (uint256 id; id < 21; ++id) {
            if ((ids >> id) & 1 != 0) {
                district = s().districts[id];

                if (_districtState(district) == DISTRICT_STATE.POST_GANG_WAR) {
                    Gang occupants = district.occupants;
                    Gang attackers = district.attackers;

                    uint256 roundId = district.roundId++;

                    uint256 r = uint256(keccak256(abi.encode(rand, id)));

                    s().gangWarOutcomes[id][roundId] = r;
                    district.lastOutcomeTime = block.timestamp;

                    if (gangWarWon(id, roundId, r)) {
                        _afterDistrictTransfer(attackers, occupants, district);

                        district.occupants = attackers;
                        district.attackers = Gang.NONE;
                    }

                    district.attackDeclarationTime = 0;
                    district.baronAttackId = 0;
                    district.baronDefenseId = 0;
                }
            }
        }

        delete s().requestIdToDistrictIds[requestId];
    }

    /* ------------- Private ------------- */

    function gangWarWon(
        uint256 districtId,
        uint256 roundId,
        uint256 gRand
    ) public view returns (bool) {
        District storage district = s().districts[districtId];

        uint256 attackForce = s().districtAttackForces[districtId][roundId][district.attackers];
        uint256 defenseForce = s().districtDefenseForces[districtId][roundId][district.occupants];

        // @note should check something with round id
        bool baronDefense = district.baronDefenseId != 0;

        return gRand >> 128 < gangWarWonProb(attackForce, defenseForce, baronDefense);
    }

    function isInjured(
        uint256 gangsterId,
        uint256 districtId,
        uint256 roundId,
        uint256 gRand
    ) public view returns (bool) {
        District storage district = s().districts[districtId];

        uint256 attackForce = s().districtAttackForces[districtId][roundId][district.attackers];
        uint256 defenseForce = s().districtDefenseForces[districtId][roundId][district.occupants];

        // @note should check something with round id
        bool baronDefense = district.baronDefenseId != 0;

        uint256 p = gangWarWonProb(attackForce, defenseForce, baronDefense);
        bool won = gRand >> 128 < p;

        uint256 c = won ? INJURED_WON_FACTOR : INJURED_LOST_FACTOR;

        uint256 pRand = uint256(keccak256(abi.encode(gRand, gangsterId)));

        return pRand >> 128 < (c * ((1 << 128) - 1 - p)) / 100;
    }

    /* ------------- Internal ------------- */
}

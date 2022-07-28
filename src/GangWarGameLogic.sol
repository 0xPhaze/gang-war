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
error AlreadyInDistrict();
error DistrictInvalidState();
error GangsterInvalidState();

error MoveOnCooldown();
error TokenMustBeGangster();
error TokenMustBeBaron();
error BaronAttackAlreadyDeclared();
error CannotAttackDistrictOwnedByGang();
error DistrictNotOwnedByGang();

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

function isInjuredProb(
    uint256 attackForce,
    uint256 defenseForce,
    bool baronDefense,
    uint256 gRand
) pure returns (uint256) {
    uint256 p = gangWarWonProb(attackForce, defenseForce, baronDefense);
    bool won = gRand >> 128 < p;

    uint256 c = won ? INJURED_WON_FACTOR : INJURED_LOST_FACTOR;

    return (c * ((1 << 128) - 1 - p)) / 100; // >> 128
}

abstract contract GangWarGameLogic is GangWarBase, VRFConsumerV2 {
    event BaronAttackDeclared(
        uint256 indexed connectingId,
        uint256 indexed districtId,
        Gang indexed gang,
        uint256 tokenId
    );
    event EnterGangWar(uint256 indexed districtId, Gang indexed gang, uint256 tokenId);
    event ExitGangWar(uint256 indexed districtId, Gang indexed gang, uint256 tokenId);
    event BaronDefenseDeclared(uint256 indexed districtId, Gang indexed gang, uint256 tokenId);
    event GangWarEnd(uint256 indexed districtId, Gang indexed losers, Gang indexed winners);

    /* ------------- external ------------- */

    function baronDeclareAttack(
        uint256 connectingId,
        uint256 districtId,
        uint256 tokenId
    ) external {
        Gang gang = gangOf(tokenId);
        District storage district = s().districts[districtId];

        (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

        _verifyAuthorized(msg.sender, tokenId);
        _collectBadges(tokenId);

        if (!isBaron(tokenId)) revert TokenMustBeBaron();
        if (districtState != DISTRICT_STATE.IDLE) revert DistrictInvalidState();
        if (!isConnecting(connectingId, districtId)) revert InvalidConnectingDistrict();
        if (district.occupants == gang) revert CannotAttackDistrictOwnedByGang();
        if (s().districts[connectingId].occupants != gang) revert ConnectingDistrictNotOwnedByGang();

        (PLAYER_STATE baronState, ) = _gangsterStateAndCountdown(tokenId);
        if (baronState != PLAYER_STATE.IDLE) revert BaronInactionable();

        Gangster storage baron = s().gangsters[tokenId];

        baron.location = districtId;
        baron.roundId = district.roundId;

        district.attackers = gang;
        district.baronAttackId = tokenId;

        district.attackDeclarationTime = block.timestamp;

        emit BaronAttackDeclared(connectingId, districtId, gang, tokenId);
    }

    function baronDeclareDefense(uint256 districtId, uint256 tokenId) external {
        Gang gang = gangOf(tokenId);
        District storage district = s().districts[districtId];

        (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

        _verifyAuthorized(msg.sender, tokenId);
        _collectBadges(tokenId);

        if (!isBaron(tokenId)) revert TokenMustBeBaron();
        if (districtState != DISTRICT_STATE.REINFORCEMENT) revert DistrictInvalidState();
        if (district.occupants != gang) revert DistrictNotOwnedByGang();

        (PLAYER_STATE gangsterState, ) = _gangsterStateAndCountdown(tokenId);
        if (gangsterState != PLAYER_STATE.IDLE) revert BaronInactionable();

        Gangster storage baron = s().gangsters[tokenId];

        baron.location = districtId;
        baron.roundId = district.roundId;

        district.baronDefenseId = tokenId;

        emit BaronDefenseDeclared(districtId, gang, tokenId);
    }

    function joinGangAttack(
        uint256 connectingId,
        uint256 districtId,
        uint256[] calldata tokenIds
    ) public {
        Gang gang = gangOf(tokenIds[0]);
        District storage district = s().districts[districtId];

        if (gangOf(district.baronAttackId) != gang) revert BaronMustDeclareInitialAttack();
        if (!isConnecting(connectingId, districtId)) revert InvalidConnectingDistrict();
        if (s().districts[connectingId].occupants != gang) revert InvalidConnectingDistrict();

        _enterGangWar(districtId, tokenIds, gang, true);
    }

    function joinGangDefense(uint256 districtId, uint256[] calldata tokenIds) public {
        Gang gang = gangOf(tokenIds[0]);

        if (s().districts[districtId].occupants != gang) revert InvalidConnectingDistrict();

        _enterGangWar(districtId, tokenIds, gang, false);
    }

    function exitGangWar(uint256[] calldata tokenIds) public {
        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];

            if (isBaron(tokenId)) revert TokenMustBeGangster();

            (PLAYER_STATE state, ) = _gangsterStateAndCountdown(tokenId);

            if (state != PLAYER_STATE.ATTACK && state != PLAYER_STATE.DEFEND) revert GangsterInvalidState();

            bool attacking = state == PLAYER_STATE.ATTACK;

            _verifyAuthorized(msg.sender, tokenId);
            _collectBadges(tokenId);

            Gangster storage gangster = s().gangsters[tokenId];

            uint256 districtId = gangster.location;
            uint256 roundId = gangster.roundId;

            Gang gang = gangOf(tokenId);

            if (attacking) s().districtAttackForces[districtId][roundId]--;
            else s().districtDefenseForces[districtId][roundId]--;

            emit ExitGangWar(districtId, gang, tokenId);

            gangster.roundId = 0;
            gangster.location = 0;
        }
    }

    function _enterGangWar(
        uint256 districtId,
        uint256[] calldata tokenIds,
        Gang gang,
        bool attack
    ) internal {
        District storage district = s().districts[districtId];

        (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

        if (districtState != DISTRICT_STATE.IDLE && districtState != DISTRICT_STATE.REINFORCEMENT)
            revert DistrictInvalidState();

        uint256 districtRoundId = district.roundId;

        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];

            if (isBaron(tokenId)) revert TokenMustBeGangster();
            if (gang != gangOf(tokenId)) revert IdsMustBeOfSameGang();

            _verifyAuthorized(msg.sender, tokenId);

            Gangster storage gangster = s().gangsters[tokenId];

            (PLAYER_STATE state, ) = _gangsterStateAndCountdown(tokenId);

            if (state != PLAYER_STATE.IDLE && state != PLAYER_STATE.ATTACK && state != PLAYER_STATE.DEFEND)
                revert GangsterInactionable();

            // already attacking/defending in another district
            if (state == PLAYER_STATE.ATTACK || state == PLAYER_STATE.DEFEND) {
                if (gangster.location == districtId) revert AlreadyInDistrict();

                // remove from old district
                if (attack) s().districtAttackForces[districtId][districtRoundId]--;
                else s().districtDefenseForces[districtId][districtRoundId]--;

                emit ExitGangWar(gangster.location, gangOf(tokenId), tokenId);
            }

            gangster.location = districtId;
            gangster.roundId = districtRoundId;
            gangster.attack = attack;

            emit EnterGangWar(districtId, gang, tokenId);
        }

        if (attack) s().districtAttackForces[districtId][districtRoundId] += tokenIds.length;
        else s().districtDefenseForces[districtId][districtRoundId] += tokenIds.length;
    }

    /* ------------- internal ------------- */

    function getGangsterView(uint256 tokenId) external view returns (GangsterView memory gangster) {
        Gangster storage gangsterStore = s().gangsters[tokenId];

        (gangster.state, gangster.stateCountdown) = _gangsterStateAndCountdown(tokenId);

        gangster.roundId = gangsterStore.roundId;
        gangster.location = gangsterStore.location;
    }

    function getDistrictView(uint256 districtId) external view returns (DistrictView memory district) {
        District storage sDistrict = s().districts[districtId];

        (district.state, district.stateCountdown) = _districtStateAndCountdown(sDistrict);

        district.occupants = sDistrict.occupants;
        district.attackers = sDistrict.attackers;
        district.token = sDistrict.token;
        district.roundId = sDistrict.roundId;
        district.attackDeclarationTime = sDistrict.attackDeclarationTime;
        district.baronAttackId = sDistrict.baronAttackId;
        district.baronDefenseId = sDistrict.baronDefenseId;
        district.lastUpkeepTime = sDistrict.lastUpkeepTime;
        district.lastOutcomeTime = sDistrict.lastOutcomeTime;
        district.lockupTime = sDistrict.lockupTime;
        district.yield = sDistrict.yield;

        district.attackForces = s().districtAttackForces[districtId][district.roundId];
        district.defenseForces = s().districtDefenseForces[districtId][district.roundId];
    }

    function _gangsterStateAndCountdown(uint256 gangsterId) internal view returns (PLAYER_STATE, int256) {
        Gangster storage gangster = s().gangsters[gangsterId];

        uint256 districtId = gangster.location;
        District storage district = s().districts[districtId];

        uint256 roundId = district.roundId;

        // gangster not in sync with district => IDLE
        if (gangster.roundId != roundId) return (PLAYER_STATE.IDLE, 0);

        Gang gang = gangOf(gangsterId);

        bool attacking = district.attackers == gang;
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
        bool injured = isInjured(gangsterId, districtId, roundId);

        if (!injured) return (PLAYER_STATE.IDLE, 0);

        stateCountdown = int256(TIME_RECOVERY) + stateCountdown;
        if (stateCountdown > 0) return (PLAYER_STATE.INJURED, stateCountdown);

        return (PLAYER_STATE.IDLE, 0);
    }

    function _districtStateAndCountdown(District storage district) internal view returns (DISTRICT_STATE, int256) {
        uint256 lastOutcomeTime = district.lastOutcomeTime;

        int256 stateCountdown = int256(TIME_TRUCE) - int256(block.timestamp - lastOutcomeTime);

        if (stateCountdown > 0) return (DISTRICT_STATE.TRUCE, stateCountdown);

        uint256 attackDeclarationTime = district.attackDeclarationTime;

        if (attackDeclarationTime == 0) return (DISTRICT_STATE.IDLE, 0);

        stateCountdown = int256(TIME_REINFORCEMENTS) - int256(block.timestamp - attackDeclarationTime);

        if (stateCountdown > 0) return (DISTRICT_STATE.REINFORCEMENT, stateCountdown);

        stateCountdown += int256(TIME_GANG_WAR);

        if (stateCountdown > 0) return (DISTRICT_STATE.GANG_WAR, stateCountdown);

        return (DISTRICT_STATE.POST_GANG_WAR, stateCountdown);
    }

    /* ------------- upkeep ------------- */

    uint256 private constant UPKEEP_INTERVAL = 5 minutes;

    function checkUpkeep(bytes calldata) external view returns (bool, bytes memory) {
        uint256 ids;
        District storage district;

        for (uint256 id; id < 21; ++id) {
            district = s().districts[id];

            (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

            if (
                districtState == DISTRICT_STATE.POST_GANG_WAR &&
                block.timestamp - district.lastUpkeepTime > UPKEEP_INTERVAL // at least wait 1 minute for re-run
            ) {
                ids |= 1 << id;
            }
        }

        return (ids > 0, abi.encode(ids));
    }

    function performUpkeep(bytes calldata performData) external {
        uint256 ids = abi.decode(performData, (uint256));
        District storage district;

        uint256 upkeepIds;

        for (uint256 id; id < 21; ++id) {
            if ((ids >> id) & 1 != 0) {
                district = s().districts[id];

                (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

                if (
                    districtState == DISTRICT_STATE.POST_GANG_WAR &&
                    block.timestamp - district.lastUpkeepTime > UPKEEP_INTERVAL // at least wait 1 minute for re-run
                ) {
                    district.lastUpkeepTime = block.timestamp;
                    upkeepIds |= 1 << id;
                }
            }
        }

        if (upkeepIds != 0) {
            uint256 requestId = requestRandomWords(1);
            s().requestIdToDistrictIds[requestId] = upkeepIds;
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

                (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

                if (districtState == DISTRICT_STATE.POST_GANG_WAR) {
                    Gang attackers = district.attackers;
                    Gang occupants = district.occupants;

                    uint256 roundId = district.roundId++;

                    uint256 r = uint256(keccak256(abi.encode(rand, id)));

                    s().gangWarOutcomes[id][roundId] = r;
                    district.lastOutcomeTime = block.timestamp;

                    if (gangWarWon(id, roundId)) {
                        _afterDistrictTransfer(attackers, occupants, district);

                        district.occupants = attackers;
                        emit GangWarEnd(id, occupants, attackers);
                    } else {
                        emit GangWarEnd(id, attackers, occupants);
                    }

                    district.attackDeclarationTime = 0;
                    district.baronAttackId = 0;
                    district.baronDefenseId = 0;
                }
            }
        }

        delete s().requestIdToDistrictIds[requestId];
    }

    /* ------------- private ------------- */

    function gangWarOutcome(uint256 districtId, uint256 roundId) public view returns (uint256) {
        return s().gangWarOutcomes[districtId][roundId];
    }

    function gangWarWon(uint256 districtId, uint256 roundId) public view returns (bool) {
        uint256 gRand = s().gangWarOutcomes[districtId][roundId];

        uint256 attackForce = s().districtAttackForces[districtId][roundId];
        uint256 defenseForce = s().districtDefenseForces[districtId][roundId];

        District storage district = s().districts[districtId];

        bool baronDefense = district.baronDefenseId != 0;

        uint256 p = gangWarWonProb(attackForce, defenseForce, baronDefense);

        return gRand >> 128 < p;
    }

    function isInjured(
        uint256 gangsterId,
        uint256 districtId,
        uint256 roundId
    ) public view returns (bool) {
        uint256 gRand = s().gangWarOutcomes[districtId][roundId];

        District storage district = s().districts[districtId];

        uint256 attackForce = s().districtAttackForces[districtId][roundId];
        uint256 defenseForce = s().districtDefenseForces[districtId][roundId];

        bool baronDefense = district.baronDefenseId != 0;

        uint256 p = isInjuredProb(attackForce, defenseForce, baronDefense, gRand);

        uint256 pRand = uint256(keccak256(abi.encode(gRand, gangsterId)));

        return pRand >> 128 < p;
    }

    /* ------------- internal ------------- */

    // function lastGangWarWon(uint256 gangsterId) public returns

    function _collectBadges(uint256 gangsterId) internal virtual {
        // if (gangWarWon(districtId, roundId, r)) {}
    }
}

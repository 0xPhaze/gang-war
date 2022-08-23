// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";

// import {s, settings, District, Gangster} from
import "./GangWarBase.sol";
import {GangWarReward, s as GangWarRewardDS} from "./GangWarReward.sol";

import "forge-std/console.sol";

import "futils/futils.sol";
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
error InvalidToken();

error InvalidUpkeep();
error InvalidVRFRequest();

function gangWarWonProb(
    uint256 attackForce,
    uint256 defenseForce,
    bool baronDefense
) pure returns (uint256) {
    attackForce += 1;
    defenseForce += 1;

    uint256 q = attackForce < DEFENSE_FAVOR_LIM ? ((1 << 32) - (attackForce << 32) / DEFENSE_FAVOR_LIM) ** 2 : 0; // prettier-ignore

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

function isInjuredProb(uint256 gangWarWonP, bool gangWarWon) pure returns (uint256) {
    uint256 c = gangWarWon ? INJURED_WON_FACTOR : INJURED_LOST_FACTOR;

    return (c * ((1 << 128) - 1 - gangWarWonP)) / 100; // >> 128
}

abstract contract GangWarGameLogic is GangWarBase, GangWarReward(GANG_VAULT_FEE), VRFConsumerV2 {
    event BaronAttackDeclared(
        uint256 indexed connectingId,
        uint256 indexed districtId,
        Gang indexed gang,
        uint256 tokenId
    );
    event EnterGangWar(uint256 indexed districtId, Gang indexed gang, uint256 tokenId);
    event ExitGangWar(uint256 indexed districtId, Gang indexed gang, uint256 tokenId);
    event BaronDefenseDeclared(uint256 indexed districtId, Gang indexed gang, uint256 tokenId);
    event GangWarWon(uint256 indexed districtId, Gang indexed losers, Gang indexed winners);
    event CopsLockup(uint256 indexed districtId);

    /* ------------- external ------------- */

    function baronDeclareAttack(
        uint256 connectingId,
        uint256 districtId,
        uint256 tokenId,
        bool sewers
    ) external {
        Gang gang = gangOf(tokenId);
        District storage district = s().districts[districtId];

        (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

        _verifyAuthorized(msg.sender, tokenId);
        _collectBadges(tokenId);

        if (!isConnecting(connectingId, districtId)) {
            if (!sewers) revert InvalidConnectingDistrict();

            s().warItems[gang][ITEM_SEWER] -= 1;
        }

        if (!isBaron(tokenId)) revert TokenMustBeBaron();
        if (districtState != DISTRICT_STATE.IDLE) revert DistrictInvalidState();
        if (district.occupants == gang) revert CannotAttackDistrictOwnedByGang();
        if (s().districts[connectingId].occupants != gang) revert ConnectingDistrictNotOwnedByGang();

        (PLAYER_STATE baronState, ) = _gangsterStateAndCountdown(tokenId);
        if (baronState != PLAYER_STATE.IDLE) {
            revert BaronInactionable();
        }

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
        if (gangsterState != PLAYER_STATE.IDLE) {
            revert BaronInactionable();
        }

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

        // @note need to find reliable way to check for attackers
        uint256 baronAttackId = district.baronAttackId;
        if (baronAttackId == 0 || gangOf(baronAttackId) != gang) revert BaronMustDeclareInitialAttack();
        if (!isConnecting(connectingId, districtId)) revert InvalidConnectingDistrict();
        if (s().districts[connectingId].occupants != gang) revert InvalidConnectingDistrict();

        _enterGangWar(districtId, tokenIds, gang, true);
    }

    function joinGangDefense(uint256 districtId, uint256[] calldata tokenIds) public {
        Gang gang = gangOf(tokenIds[0]);

        if (s().districts[districtId].occupants != gang) revert InvalidConnectingDistrict();

        _enterGangWar(districtId, tokenIds, gang, false);
    }

    /* ------------- bribery ------------- */

    function bribery(
        uint256[] calldata tokenIds,
        address token,
        bool isBribery
    ) external {
        uint256 tokenFee = briberyFee(token);
        if (tokenFee == 0) revert InvalidToken();

        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];

            if (isBaron(tokenId)) revert TokenMustBeGangster();

            (PLAYER_STATE gangsterState, ) = _gangsterStateAndCountdown(tokenId);

            if (gangsterState != PLAYER_STATE.INJURED && gangsterState != PLAYER_STATE.LOCKUP)
                revert GangsterInvalidState();

            ERC20UDS(token).transferFrom(msg.sender, address(this), tokenFee);

            if (isBribery) s().gangsters[tokenId].bribery += 1;
            else s().gangsters[tokenId].recovery += 1;
        }
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
            gangster.bribery = 0;
            gangster.recovery = 0;
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
                uint256 gangsterLocation = gangster.location;
                if (gangsterLocation == districtId) revert AlreadyInDistrict();

                uint256 oldDistrictRoundId = s().districts[gangsterLocation].roundId;

                // remove from old district
                if (attack) s().districtAttackForces[gangsterLocation][oldDistrictRoundId]--;
                else s().districtDefenseForces[gangsterLocation][oldDistrictRoundId]--;

                emit ExitGangWar(gangsterLocation, gangOf(tokenId), tokenId);
            }

            gangster.bribery = 0;
            gangster.recovery = 0;
            gangster.location = districtId;
            gangster.roundId = districtRoundId;
            gangster.attack = attack;

            emit EnterGangWar(districtId, gang, tokenId);
        }

        if (attack) s().districtAttackForces[districtId][districtRoundId] += tokenIds.length;
        else s().districtDefenseForces[districtId][districtRoundId] += tokenIds.length;
    }

    /* ------------- internal ------------- */

    function getGangster(uint256 tokenId) external view returns (Gangster memory gangster) {
        gangster = s().gangsters[tokenId];

        gangster.gang = gangOf(tokenId);

        (gangster.state, gangster.stateCountdown) = _gangsterStateAndCountdown(tokenId);
    }

    function getDistrict(uint256 districtId) external view returns (District memory district) {
        District storage sDistrict = s().districts[districtId];

        district = sDistrict;

        (district.state, district.stateCountdown) = _districtStateAndCountdown(sDistrict);

        district.attackForces = s().districtAttackForces[districtId][district.roundId];
        district.defenseForces = s().districtDefenseForces[districtId][district.roundId];
    }

    function _gangsterStateAndCountdown(uint256 gangsterId) internal view returns (PLAYER_STATE, int256) {
        Gangster storage gangster = s().gangsters[gangsterId];

        uint256 districtId = gangster.location;
        District storage district = s().districts[districtId];

        uint256 districtRoundId = district.roundId;
        uint256 gangsterRoundId = gangster.roundId;

        // gangster not in sync with district => IDLE
        if (districtRoundId > 1 + gangsterRoundId) return (PLAYER_STATE.IDLE, 0);

        int256 stateCountdown;

        // -------- check lockup (takes precedence); if lockupTime is still active, then player must be in round
        uint256 lockupTime = district.lockupTime;

        if (lockupTime != 0) {
            stateCountdown = int256(TIME_LOCKUP / (1 << gangster.bribery)) - int256(block.timestamp - lockupTime);
            if (stateCountdown > 0) return (PLAYER_STATE.LOCKUP, stateCountdown);
        }

        bool isActiveRound = districtRoundId == gangsterRoundId;

        if (isActiveRound) {
            Gang gang = gangOf(gangsterId);

            bool attacking = district.attackers == gang;

            // -------- check gang war outcome
            uint256 attackDeclarationTime = district.attackDeclarationTime;

            if (attackDeclarationTime == 0) return (PLAYER_STATE.IDLE, 0);

            stateCountdown = int256(TIME_REINFORCEMENTS) - int256(block.timestamp - attackDeclarationTime);

            // player in reinforcement phase; not committed yet
            if (stateCountdown > 0) return (attacking ? PLAYER_STATE.ATTACK : PLAYER_STATE.DEFEND, stateCountdown);

            stateCountdown += int256(TIME_GANG_WAR);

            return (attacking ? PLAYER_STATE.ATTACK_LOCKED : PLAYER_STATE.DEFEND_LOCKED, stateCountdown);
        }

        // we assume district.lastOutcomeTime must be non-zero
        // as otherwise the roundIds would match

        // -------- check injury
        bool injured = isInjured(gangsterId, districtId, districtRoundId);

        if (injured) {
            stateCountdown = int256(TIME_RECOVERY / (1 << gangster.recovery)) - int256(block.timestamp - district.lastOutcomeTime); // prettier-ignore

            if (stateCountdown > 0) return (PLAYER_STATE.INJURED, stateCountdown);
        }

        return (PLAYER_STATE.IDLE, 0);
    }

    function _districtStateAndCountdown(District storage district) internal view returns (DISTRICT_STATE, int256) {
        int256 stateCountdown = int256(TIME_LOCKUP) - int256(block.timestamp - district.lockupTime);

        // console.logInt(int256(TIME_LOCKUP));
        // console.logInt(int256(block.timestamp));
        // console.logInt(int256(district.lockupTime));
        // console.logInt(int256(block.timestamp - district.lockupTime));
        // console.logInt(int256(stateCountdown));
        // console.log("----");

        if (stateCountdown > 0) return (DISTRICT_STATE.LOCKUP, stateCountdown);

        stateCountdown = int256(TIME_TRUCE) - int256(block.timestamp - district.lastOutcomeTime);
        if (stateCountdown > 0) return (DISTRICT_STATE.TRUCE, stateCountdown);

        uint256 attackDeclarationTime = district.attackDeclarationTime;
        if (attackDeclarationTime == 0) return (DISTRICT_STATE.IDLE, 0);

        int256 timeReinforcement = int256(TIME_REINFORCEMENTS * (100 - ((district.activeItems >> ITEM_BLITZ) & 1) * ITEM_BLITZ_TIME_REDUCTION) / 100); // prettier-ignore
        stateCountdown = timeReinforcement - int256(block.timestamp - attackDeclarationTime);

        if (stateCountdown > 0) return (DISTRICT_STATE.REINFORCEMENT, stateCountdown);

        stateCountdown += int256(TIME_GANG_WAR);
        if (stateCountdown > 0) return (DISTRICT_STATE.GANG_WAR, stateCountdown);

        return (DISTRICT_STATE.POST_GANG_WAR, stateCountdown);
    }

    /* ------------- upkeep ------------- */

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

        // possible lockup, need to know attackers/defenders
        // before state update. Though the lockup effect will
        // happen afterwards, just to be sure that the VRF request
        // was valid
        bool lockup = rand % 100 < LOCKUP_CHANCE;
        uint256 lockupDistrictId = rand % 21;

        bool upkeepTriggered;

        if (lockup) {
            district = s().districts[lockupDistrictId];

            Gang token = district.token;

            uint256 lockupAmount_0;
            uint256 lockupAmount_1;
            uint256 lockupAmount_2;

            if (token == Gang.YAKUZA) lockupAmount_0 = LOCKUP_FINE;
            else if (token == Gang.CARTEL) lockupAmount_1 = LOCKUP_FINE;
            else if (token == Gang.CYBERP) lockupAmount_2 = LOCKUP_FINE;

            uint256 lockupOccupants = uint256(district.occupants);
            uint256 lockupAttackers = uint256(district.attackDeclarationTime != 0 ? district.attackers : Gang.NONE);

            _spendGangVaultBalance(lockupOccupants, lockupAmount_0, lockupAmount_1, lockupAmount_2, false);

            // if attackers are present
            if (lockupAttackers != uint256(Gang.NONE)) {
                _spendGangVaultBalance(lockupAttackers, lockupAmount_0, lockupAmount_1, lockupAmount_2, false);
            }
        }

        for (uint256 id; id < 21; ) {
            if ((ids >> id) & 1 != 0) {
                district = s().districts[id];

                (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

                if (districtState == DISTRICT_STATE.POST_GANG_WAR) {
                    Gang attackers = district.attackers;
                    Gang occupants = district.occupants;

                    uint256 roundId = district.roundId++;

                    uint256 r = uint256(keccak256(abi.encode(rand, id)));

                    // advance state
                    s().gangWarOutcomes[id][roundId] = r;
                    district.lastOutcomeTime = block.timestamp;

                    if (gangWarWon(id, roundId)) {
                        _transferYield(uint256(occupants), uint256(attackers), uint256(district.token), district.yield);

                        district.occupants = attackers;

                        emit GangWarWon(id, occupants, attackers);
                    } else {
                        emit GangWarWon(id, attackers, occupants);
                    }

                    district.attackers = Gang.NONE;
                    district.attackDeclarationTime = 0;
                    district.baronAttackId = 0;
                    district.baronDefenseId = 0;
                }

                upkeepTriggered = true;
            }

            unchecked {
                ++id;
            }
        }

        if (!upkeepTriggered) revert InvalidUpkeep();

        if (lockup) {
            // only set state after processing
            s().districts[lockupDistrictId].lockupTime = block.timestamp;
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

        // console.log("injured prob", (p * 100) >> 128);
        // console.log("pRand", ((pRand >> 128) * 100) >> 128);
        // console.log("injured", pRand >> 128 < p);

        return pRand >> 128 < p;
    }

    // function gangWarOutcome(uint256 districtId, uint256 roundId) public view returns (uint256) {
    //     return s().gangWarOutcomes[districtId][roundId];
    // }

    // function gangWarWon(uint256 districtId, uint256 roundId) public view returns (bool) {
    //     uint256 gRand = s().gangWarOutcomes[districtId][roundId];

    //     uint256 p = gangWarWonDistrictProb(districtId, roundId);

    //     return gRand >> 128 < p;
    // }

    // function gangWarWonDistrictProb(uint256 districtId, uint256 roundId) private view returns (uint256) {
    //     uint256 attackForce = s().districtAttackForces[districtId][roundId];
    //     uint256 defenseForce = s().districtDefenseForces[districtId][roundId];

    //     District storage district = s().districts[districtId];

    //     uint256 items = district.activeItems;

    //     attackForce += ((items >> ITEM_SMOKE) & 1) * attackForce * ITEM_SMOKE_ATTACK_INCREASE;
    //     defenseForce += ((items >> ITEM_BARRICADES) & 1) * defenseForce * ITEM_BARRICADES_DEFENSE_INCREASE;

    //     bool baronDefense = district.baronDefenseId != 0;

    //     return gangWarWonProb(attackForce, defenseForce, baronDefense);
    // }

    // function isInjured(
    //     uint256 gangsterId,
    //     uint256 districtId,
    //     uint256 roundId
    // ) public view returns (bool) {
    //     uint256 gRand = s().gangWarOutcomes[districtId][roundId];

    //     uint256 wonP = gangWarWonDistrictProb(districtId, roundId);

    //     bool won = gRand >> 128 < wonP;

    //     uint256 p = isInjuredProb(wonP, won);

    //     uint256 pRand = uint256(keccak256(abi.encode(gRand, gangsterId)));

    //     // console.log("injured prob", (p * 100) >> 128);
    //     // console.log("pRand", ((pRand >> 128) * 100) >> 128);
    //     // console.log("injured", pRand >> 128 < p);

    //     return pRand >> 128 < p;
    // }

    /* ------------- internal ------------- */

    // function lastGangWarWon(uint256 gangsterId) public returns

    function _collectBadges(uint256 gangsterId) internal virtual;
}

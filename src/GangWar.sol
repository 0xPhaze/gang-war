// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "./Constants.sol";
import {GangVault} from "./GangVault.sol";
import {GangToken} from "./tokens/GangToken.sol";
import {LibPackedMap} from "./lib/LibPackedMap.sol";
import {VRFConsumerV2} from "./lib/VRFConsumerV2.sol";
import {GMCChild as GMC, Offer} from "./tokens/GMCChild.sol";

import {ERC20UDS} from "UDS/tokens/ERC20UDS.sol";
import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

// ------------- constants

uint256 constant SEASON_START_DATE = 1664632800;
uint256 constant SEASON_END_DATE = 1664805600;

// uint256 constant TIME_TRUCE = 20 minutes;
// uint256 constant TIME_LOCKUP = 60 minutes;
// uint256 constant TIME_GANG_WAR = 20 minutes;
// uint256 constant TIME_RECOVERY = 60 minutes;
// uint256 constant TIME_REINFORCEMENTS = 30 minutes;

uint256 constant TIME_TRUCE = 40 minutes;
uint256 constant TIME_LOCKUP = 60 minutes;
uint256 constant TIME_GANG_WAR = 40 minutes;
uint256 constant TIME_RECOVERY = 60 minutes;
uint256 constant TIME_REINFORCEMENTS = 40 minutes;

uint256 constant DEFENSE_FAVOR_LIM = 60; // 150
uint256 constant BARON_DEFENSE_FORCE = 20;
uint256 constant ATTACK_FAVOR = 65;
uint256 constant DEFENSE_FAVOR = 200;

uint256 constant LOCKUP_CHANCE = 20;
uint256 constant LOCKUP_FINE = 25_000e18;
uint256 constant RECOVERY_BARON_COST = 25_000e18;

uint256 constant INJURED_WON_FACTOR = 35;
uint256 constant INJURED_LOST_FACTOR = 65;

uint256 constant GANG_VAULT_FEE = 20;

uint256 constant BADGES_EARNED_VICTORY = 6e18;
uint256 constant BADGES_EARNED_DEFEAT = 2e18;

uint256 constant UPKEEP_INTERVAL = 1 minutes;

uint256 constant ITEM_SEWER = 0;
uint256 constant ITEM_BLITZ = 1;
uint256 constant ITEM_BARRICADES = 2;
uint256 constant ITEM_SMOKE = 3;
uint256 constant ITEM_911 = 4;

uint256 constant ITEM_911_REQUEST = 1 << 40;

uint256 constant NUM_BARON_ITEMS = 5;

uint256 constant ITEM_BLITZ_TIME_REDUCTION = 80;
uint256 constant ITEM_SMOKE_ATTACK_INCREASE = 30;
uint256 constant ITEM_BARRICADES_DEFENSE_INCREASE = 30;
uint256 constant ITEM_TIME_DELAY_USE = 0 hours;
uint256 constant ITEM_TIME_DELAY_PURCHASE = 0 hours;

// ------------- enum

enum Gang {
    YAKUZA,
    CARTEL,
    CYBERP,
    NONE
}

enum DISTRICT_STATE {
    IDLE,
    REINFORCEMENT,
    GANG_WAR,
    POST_GANG_WAR,
    TRUCE,
    LOCKUP
}

enum PLAYER_STATE {
    IDLE,
    ATTACK,
    ATTACK_LOCKED,
    DEFEND,
    DEFEND_LOCKED,
    INJURED,
    LOCKUP
}

// ------------- struct

struct Gangster {
    uint256 roundId;
    uint256 location;
    uint256 briberyTimeReduction;
    uint256 recoveryTimeReduction;
    bool attack;
    // variables from here on are not explicitly set
    // but only written to in the view functions for getters
    // don't read these directly in the contract!
    Gang gang;
    PLAYER_STATE state;
    int256 stateCountdown;
}

struct District {
    Gang occupants;
    Gang attackers;
    Gang token;
    uint256 roundId;
    uint256 attackDeclarationTime;
    uint256 baronAttackId;
    uint256 baronDefenseId;
    uint256 lastUpkeepTime; // time when upkeep is last triggered
    uint256 lastOutcomeTime; // time when vrf result is in
    uint256 lockupTime;
    uint256 yield;
    uint256 activeItems;
    uint256 blitzTimeReduction;
    // variables from here on are not explicitly set
    // but only written to in the view functions for getters
    // don't read these directly in the contract!
    DISTRICT_STATE state;
    int256 stateCountdown;
    uint256 attackForces;
    uint256 defenseForces;
}

struct GangWarDS {
    /*      id      =>   */
    mapping(uint256 => District) districts;
    mapping(uint256 => Gangster) gangsters;
    /*      id      => price  */
    mapping(uint256 => uint256) baronItemCost;
    /*      address => fee  */
    mapping(address => uint256) briberyFee;
    /*      Gang =>        itemId   => balance  */
    mapping(Gang => mapping(uint256 => uint256)) baronItems;
    /*   districtId => districtIds  */
    mapping(uint256 => uint256) requestIdToDistrictIds; // used by chainlink VRF request callbacks
    /*   districtId =>     roundId     => outcome  */
    mapping(uint256 => mapping(uint256 => uint256)) gangWarOutcomes;
    /*   districtId =>     roundId     => numForces */
    mapping(uint256 => mapping(uint256 => uint256)) districtAttackForces;
    mapping(uint256 => mapping(uint256 => uint256)) districtDefenseForces;
    mapping(uint256 => uint256) baronItemLastPurchased;
    mapping(uint256 => uint256) baronItemLastUsed;
}

// ------------- storage

string constant SEASON = "season.rumble";

bytes32 constant DIAMOND_STORAGE_GANG_WAR = keccak256("diamond.storage.gang.war.season.rumble");

function s() pure returns (GangWarDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_GANG_WAR;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

// ------------- errors

error InvalidToken();
error InvalidUpkeep();
error NotAuthorized();
error InvalidItemId();
error InvalidItemUsage();
error GangWarNotActive();
error TokenMustBeBaron();
error InvalidVRFRequest();
error ItemAlreadyActive();
error AlreadyInDistrict();
error BaronInactionable();
error TokenMustBeGangster();
error IdsMustBeOfSameGang();
error GangsterInactionable();
error DistrictInvalidState();
error GangsterInvalidState();
error BaronAlreadyDefending();
error DistrictNotOwnedByGang();
error MinimumTimeDelayNotPassed();
error InvalidConnectingDistrict();
error BaronMustDeclareInitialAttack();
error ConnectingDistrictUnderAttack();
error CannotAttackDistrictOwnedByGang();
error ConnectingDistrictNotOwnedByGang();

/// @title Gangsta Mice City's Gang Wars
/// @author phaze (https://github.com/0xPhaze)
contract GangWar is UUPSUpgrade, OwnableUDS, VRFConsumerV2 {
    GangWarDS private __storageLayout;

    event CopsLockup(uint256 indexed districtId, Gang occupants, Gang attackers);
    event GangWarWon(uint256 indexed districtId, Gang indexed losers, Gang indexed winners);
    event ExitGangWar(uint256 indexed districtId, Gang indexed gang, uint256 tokenId);
    event EnterGangWar(uint256 indexed districtId, Gang indexed gang, uint256 tokenId);
    event BadgesEarned(uint256 indexed districtId, uint256 indexed tokenId, Gang indexed gang, bool won, uint256 probability); // prettier-ignore
    event BaronItemUsed(uint256 indexed districtId, uint256 indexed baronId, Gang indexed gang, uint256 itemId);
    event GangsterInjured(uint256 indexed districtId, uint256 indexed tokenId);
    event BaronItemPurchased(uint256 indexed baronId, Gang indexed gang, uint256 itemId, uint256 price);
    event BaronAttackDeclared(uint256 indexed connectingId, uint256 indexed districtId, Gang indexed gang, uint256 tokenId); // prettier-ignore
    event BaronDefenseDeclared(uint256 indexed districtId, Gang indexed gang, uint256 tokenId);

    GMC public immutable gmc;
    GangToken public immutable badges;
    GangVault public immutable vault;
    uint256 public immutable seasonStart;
    uint256 public immutable seasonEnd;

    uint256 immutable packedDistrictConnections;

    constructor(
        GMC gmc_,
        GangVault vault_,
        GangToken badges_,
        uint256 seasonStart_,
        uint256 seasonEnd_,
        uint256 connections,
        address coordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit
    ) VRFConsumerV2(coordinator, keyHash, subscriptionId, requestConfirmations, callbackGasLimit) {
        gmc = gmc_;
        vault = vault_;
        badges = badges_;
        seasonStart = seasonStart_;
        seasonEnd = seasonEnd_;
        packedDistrictConnections = connections;
    }

    /* ------------- init ------------- */

    function init() external initializer {
        __Ownable_init();
    }

    function reset(Gang[21] calldata occupants, uint256[21] calldata yields) public onlyOwner {
        uint256[3] memory initialGangYields;

        District storage district;

        for (uint256 i; i < 21; ++i) {
            district = s().districts[i];

            // initialize rounds
            district.roundId = 1;

            // initialize occupants and yield token
            district.token = occupants[i];
            district.occupants = occupants[i];

            // initialize district yield amount
            district.yield = yields[i];

            initialGangYields[uint256(occupants[i])] += yields[i];
        }

        // initialize yields for gangs
        vault.setYield(0, [initialGangYields[0], uint256(0), uint256(0)]);
        vault.setYield(1, [uint256(0), initialGangYields[1], uint256(0)]);
        vault.setYield(2, [uint256(0), uint256(0), initialGangYields[2]]);
    }

    /* ------------- view ------------- */

    function gangAttackSuccess(uint256 districtId, uint256 roundId) public view returns (bool) {
        uint256 gRand = s().gangWarOutcomes[districtId][roundId];

        uint256 p = _gangWarWonDistrictProb(districtId, roundId);

        return gRand >> 128 < p;
    }

    function briberyFee(address token) external view returns (uint256) {
        return s().briberyFee[token];
    }

    function baronItemCost(uint256 id) external view returns (uint256) {
        return s().baronItemCost[id];
    }

    function getBaronItemBalances(uint256 gang) external view returns (uint256[] memory items) {
        items = new uint256[](NUM_BARON_ITEMS);
        for (uint256 i; i < NUM_BARON_ITEMS; ++i) items[i] = s().baronItems[Gang(gang)][i];
    }

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

    /* ------------- external ------------- */

    function purchaseBaronItem(
        uint256 baronId,
        uint256 itemId,
        uint256 exchangeType
    ) external isActiveSeason {
        _verifyAuthorizedUser(msg.sender, baronId);

        uint256 micePrice = s().baronItemCost[itemId];
        uint256 lastPurchase = s().baronItemLastPurchased[baronId];

        if (micePrice == 0) revert InvalidItemId();
        if (!isBaron(baronId)) revert TokenMustBeBaron();
        if (block.timestamp < lastPurchase + ITEM_TIME_DELAY_PURCHASE) revert MinimumTimeDelayNotPassed();

        Gang gang = gangOf(baronId);

        _spendMice(uint256(gang), micePrice, exchangeType);

        emit BaronItemPurchased(baronId, gang, itemId, micePrice);

        s().baronItems[gang][itemId] += 1;
        s().baronItemLastPurchased[baronId] = block.timestamp;
    }

    function useBaronItem(
        uint256 baronId,
        uint256 itemId,
        uint256 districtId
    ) external isActiveSeason {
        _verifyAuthorizedUser(msg.sender, baronId);

        uint256 lastUse = s().baronItemLastUsed[baronId];

        if (!isBaron(baronId)) revert TokenMustBeBaron();
        if (itemId == ITEM_SEWER) revert InvalidItemId();
        if (block.timestamp < lastUse + ITEM_TIME_DELAY_USE) revert MinimumTimeDelayNotPassed();

        Gang gang = gangOf(baronId);

        District storage district = s().districts[districtId];
        (DISTRICT_STATE districtState, int256 stateCountdown) = _districtStateAndCountdown(district);

        if (districtState != DISTRICT_STATE.IDLE && districtState != DISTRICT_STATE.REINFORCEMENT) {
            revert DistrictInvalidState();
        }
        if (itemId == ITEM_BLITZ) {
            if (
                // require attacking/defending
                (district.attackers != gang && district.occupants != gang) ||
                districtState != DISTRICT_STATE.REINFORCEMENT
            ) {
                revert InvalidItemUsage();
            }

            s().districts[districtId].blitzTimeReduction = (uint256(stateCountdown) * ITEM_BLITZ_TIME_REDUCTION) / 100;
        } else if (itemId == ITEM_BARRICADES) {
            if (
                // require defending
                district.occupants != gang ||
                (districtState != DISTRICT_STATE.REINFORCEMENT && districtState != DISTRICT_STATE.GANG_WAR)
            ) {
                revert InvalidItemUsage();
            }
        } else if (itemId == ITEM_SMOKE) {
            if (
                // require attacking
                district.attackers != gang ||
                (districtState != DISTRICT_STATE.REINFORCEMENT && districtState != DISTRICT_STATE.GANG_WAR)
            ) {
                revert InvalidItemUsage();
            }
        } else if (itemId == ITEM_911) {
            uint256 requestId = requestVRF();

            s().requestIdToDistrictIds[requestId] = ITEM_911_REQUEST;
        }

        s().baronItems[gang][itemId] -= 1;
        s().baronItemLastUsed[baronId] = block.timestamp;

        if (itemId != ITEM_911) {
            _applyBaronItemToDistrict(itemId, districtId);
        }

        emit BaronItemUsed(districtId, baronId, gang, itemId);
    }

    function bribery(uint256[] calldata tokenIds, address token) external isActiveSeason {
        uint256 tokenFee = s().briberyFee[token];
        if (tokenFee == 0) revert InvalidToken();

        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];

            if (isBaron(tokenId)) revert TokenMustBeGangster();

            (PLAYER_STATE gangsterState, int256 stateCountdown) = _gangsterStateAndCountdown(tokenId);

            if (gangsterState != PLAYER_STATE.INJURED && gangsterState != PLAYER_STATE.LOCKUP)
                revert GangsterInvalidState();

            ERC20UDS(token).transferFrom(msg.sender, address(this), tokenFee);

            if (stateCountdown > 0) {
                uint256 timeReduction = uint256(stateCountdown) / 2;

                bool isBribery = gangsterState == PLAYER_STATE.LOCKUP;

                if (isBribery) s().gangsters[tokenId].briberyTimeReduction += timeReduction;
                else s().gangsters[tokenId].recoveryTimeReduction += timeReduction;
            }
        }
    }

    function recoverBaron(uint256 baronId, uint256 exchangeType) external isActiveSeason {
        _verifyAuthorizedUser(msg.sender, baronId);

        if (!isBaron(baronId)) revert TokenMustBeBaron();

        Gang gang = gangOf(baronId);

        _spendMice(uint256(gang), RECOVERY_BARON_COST, exchangeType);

        (PLAYER_STATE gangsterState, int256 stateCountdown) = _gangsterStateAndCountdown(baronId);

        if (gangsterState != PLAYER_STATE.INJURED && gangsterState != PLAYER_STATE.LOCKUP)
            revert GangsterInvalidState();

        uint256 timeReduction = uint256(stateCountdown) / 2;

        bool isBribery = gangsterState == PLAYER_STATE.LOCKUP;

        if (isBribery) s().gangsters[baronId].briberyTimeReduction += timeReduction;
        else s().gangsters[baronId].recoveryTimeReduction += timeReduction;
    }

    function baronDeclareAttack(
        uint256 connectingId,
        uint256 districtId,
        uint256 tokenId,
        bool sewers
    ) external isActiveSeason {
        _verifyAuthorizedUser(msg.sender, tokenId);

        Gang gang = gangOf(tokenId);
        District storage district = s().districts[districtId];

        (PLAYER_STATE baronState, ) = _gangsterStateAndCountdown(tokenId);
        (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

        if (!isBaron(tokenId)) revert TokenMustBeBaron();
        if (district.occupants == gang) revert CannotAttackDistrictOwnedByGang();
        if (baronState != PLAYER_STATE.IDLE) revert BaronInactionable();
        if (districtState != DISTRICT_STATE.IDLE) revert DistrictInvalidState();

        if (sewers) {
            s().baronItems[gang][ITEM_SEWER] -= 1;

            _applyBaronItemToDistrict(ITEM_SEWER, districtId);
        } else {
            if (!isConnecting(connectingId, districtId)) revert InvalidConnectingDistrict();
            if (s().districts[connectingId].occupants != gang) revert ConnectingDistrictNotOwnedByGang();
            if (s().districts[connectingId].baronAttackId != 0) revert ConnectingDistrictUnderAttack();
        }

        _collectBadges(tokenId);

        Gangster storage baron = s().gangsters[tokenId];

        baron.attack = true;
        baron.roundId = district.roundId;
        baron.location = districtId;

        district.attackers = gang;
        district.baronAttackId = tokenId;
        district.attackDeclarationTime = block.timestamp;

        emit BaronAttackDeclared(connectingId, districtId, gang, tokenId);
    }

    function baronDeclareDefense(uint256 districtId, uint256 tokenId) external isActiveSeason {
        Gang gang = gangOf(tokenId);
        District storage district = s().districts[districtId];

        (PLAYER_STATE gangsterState, ) = _gangsterStateAndCountdown(tokenId);
        (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

        if (!isBaron(tokenId)) revert TokenMustBeBaron();
        if (district.occupants != gang) revert DistrictNotOwnedByGang();
        if (district.baronDefenseId != 0) revert BaronAlreadyDefending();
        if (gangsterState != PLAYER_STATE.IDLE) revert BaronInactionable();
        if (districtState != DISTRICT_STATE.REINFORCEMENT) revert DistrictInvalidState();

        _verifyAuthorizedUser(msg.sender, tokenId);
        _collectBadges(tokenId);

        Gangster storage baron = s().gangsters[tokenId];

        baron.attack = false;
        baron.roundId = district.roundId;
        baron.location = districtId;

        district.baronDefenseId = tokenId;

        emit BaronDefenseDeclared(districtId, gang, tokenId);
    }

    function joinGangAttack(
        uint256 districtIdFrom,
        uint256 districtIdTo,
        uint256[] calldata tokenIds
    ) external isActiveSeason {
        Gang gang = gangOf(tokenIds[0]);

        District storage district = s().districts[districtIdTo];
        District storage districtFrom = s().districts[districtIdFrom];

        uint256 baronAttackId = district.baronAttackId;
        Gang attackerGang = gangOf(baronAttackId);

        if (districtFrom.occupants != gang && (district.activeItems >> ITEM_SEWER) & 1 == 0)
            revert ConnectingDistrictNotOwnedByGang();
        if (districtFrom.baronAttackId != 0) revert ConnectingDistrictUnderAttack();
        if (baronAttackId == 0 || attackerGang != gang) revert BaronMustDeclareInitialAttack();

        _enterGangWar(districtIdTo, tokenIds, gang, true);
    }

    function joinGangDefense(uint256 districtIdTo, uint256[] calldata tokenIds) external isActiveSeason {
        Gang gang = gangOf(tokenIds[0]);
        District storage districtTo = s().districts[districtIdTo];

        if (districtTo.occupants != gang) revert InvalidConnectingDistrict();
        if (districtTo.baronAttackId == 0) revert BaronMustDeclareInitialAttack();

        _enterGangWar(districtIdTo, tokenIds, gang, false);
    }

    function exitGangWar(uint256[] calldata tokenIds) external isActiveSeason {
        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];

            (PLAYER_STATE state, ) = _gangsterStateAndCountdown(tokenId);

            if (isBaron(tokenId)) revert TokenMustBeGangster();
            if (state != PLAYER_STATE.ATTACK && state != PLAYER_STATE.DEFEND) revert GangsterInvalidState();

            _verifyAuthorizedUser(msg.sender, tokenId);
            _collectBadges(tokenId);

            bool attacking = state == PLAYER_STATE.ATTACK;

            Gangster storage gangster = s().gangsters[tokenId];

            uint256 roundId = gangster.roundId;
            uint256 districtId = gangster.location;

            if (attacking) s().districtAttackForces[districtId][roundId]--;
            else s().districtDefenseForces[districtId][roundId]--;

            emit ExitGangWar(districtId, gangOf(tokenId), tokenId);

            delete s().gangsters[tokenId];
        }
    }

    function collectBadges(uint256[] calldata tokenIds) external {
        for (uint256 i; i < tokenIds.length; ++i) {
            _verifyAuthorizedUser(msg.sender, tokenIds[i]);

            _collectBadges(tokenIds[i]);
        }
    }

    /* ------------- enter ------------- */

    function _enterGangWar(
        uint256 districtId,
        uint256[] calldata tokenIds,
        Gang gang,
        bool attack
    ) private {
        District storage district = s().districts[districtId];

        (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

        if (districtState != DISTRICT_STATE.IDLE && districtState != DISTRICT_STATE.REINFORCEMENT)
            revert DistrictInvalidState();

        uint256 districtRoundId = district.roundId;

        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];

            if (isBaron(tokenId)) revert TokenMustBeGangster();
            if (gang != gangOf(tokenId)) revert IdsMustBeOfSameGang();

            _verifyAuthorizedUser(msg.sender, tokenId);

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

                emit ExitGangWar(gangsterLocation, gang, tokenId);
            }

            _collectBadges(tokenId);

            gangster.attack = attack;
            gangster.roundId = districtRoundId;
            gangster.location = districtId;
            gangster.briberyTimeReduction = 0;
            gangster.recoveryTimeReduction = 0;

            emit EnterGangWar(districtId, gang, tokenId);
        }

        if (attack) s().districtAttackForces[districtId][districtRoundId] += tokenIds.length;
        else s().districtDefenseForces[districtId][districtRoundId] += tokenIds.length;
    }

    /* ------------- state ------------- */

    function isBaron(uint256 tokenId) private pure returns (bool) {
        return tokenId >= 10_000;
    }

    function gangOf(uint256 id) private view returns (Gang) {
        return Gang(gmc.gangOf(id));
    }

    function gangWarOutcome(uint256 districtId, uint256 roundId) external view returns (uint256) {
        return s().gangWarOutcomes[districtId][roundId];
    }

    function isConnecting(uint256 districtA, uint256 districtB) private view returns (bool) {
        return LibPackedMap.isConnecting(packedDistrictConnections, districtA, districtB);
    }

    function _spendMice(
        uint256 gang,
        uint256 micePrice,
        uint256 exchangeType
    ) internal {
        uint256 yakuzaTokenAmount;
        uint256 cartelTokenAmount;
        uint256 cyberpunkTokenAmount;

        if (exchangeType == 1) {
            yakuzaTokenAmount = micePrice * 3;
        } else if (exchangeType == 2) {
            cartelTokenAmount = micePrice * 3;
        } else if (exchangeType == 3) {
            cyberpunkTokenAmount = micePrice * 3;
        } else if (exchangeType == 4) {
            cartelTokenAmount = micePrice;
            cyberpunkTokenAmount = micePrice;
        } else if (exchangeType == 5) {
            yakuzaTokenAmount = micePrice;
            cyberpunkTokenAmount = micePrice;
        } else if (exchangeType == 6) {
            yakuzaTokenAmount = micePrice;
            cartelTokenAmount = micePrice;
        } else {
            yakuzaTokenAmount = micePrice / 2;
            cartelTokenAmount = micePrice / 2;
            cyberpunkTokenAmount = micePrice / 2;
        }

        vault.spendGangVaultBalance(uint256(gang), yakuzaTokenAmount, cartelTokenAmount, cyberpunkTokenAmount, true);
    }

    function _isInjured(
        uint256 gangsterId,
        uint256 districtId,
        uint256 roundId
    ) private view returns (bool) {
        uint256 gRand = s().gangWarOutcomes[districtId][roundId];

        uint256 wonP = _gangWarWonDistrictProb(districtId, roundId);

        bool won = gRand >> 128 < wonP;

        uint256 p = isInjuredProbFn(wonP, won);

        uint256 pRand = uint256(keccak256(abi.encode(gRand, gangsterId)));

        return pRand >> 128 < p;
    }

    function _gangWarWonDistrictProb(uint256 districtId, uint256 roundId) private view returns (uint256) {
        uint256 attackForce = s().districtAttackForces[districtId][roundId];
        uint256 defenseForce = s().districtDefenseForces[districtId][roundId];

        District storage district = s().districts[districtId];

        uint256 items = district.activeItems;

        attackForce += ((items >> ITEM_SMOKE) & 1) * attackForce * ITEM_SMOKE_ATTACK_INCREASE;
        defenseForce += ((items >> ITEM_BARRICADES) & 1) * defenseForce * ITEM_BARRICADES_DEFENSE_INCREASE;

        bool baronDefense = district.baronDefenseId != 0;

        return gangWarWonProbFn(attackForce, defenseForce, baronDefense);
    }

    function _gangsterStateAndCountdown(uint256 gangsterId) private view returns (PLAYER_STATE, int256) {
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
            stateCountdown =
                int256(TIME_LOCKUP) -
                int256(block.timestamp - lockupTime) -
                int256(gangster.briberyTimeReduction);
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
        bool injured = _isInjured(gangsterId, districtId, districtRoundId);

        if (injured) {
            stateCountdown =
                int256(TIME_RECOVERY) -
                int256(block.timestamp - district.lastOutcomeTime) -
                int256(gangster.recoveryTimeReduction);

            if (stateCountdown > 0) return (PLAYER_STATE.INJURED, stateCountdown);
        }

        return (PLAYER_STATE.IDLE, 0);
    }

    function _districtStateAndCountdown(uint256 districtId) private view returns (DISTRICT_STATE, int256) {
        return _districtStateAndCountdown(s().districts[districtId]);
    }

    function _districtStateAndCountdown(District storage district) private view returns (DISTRICT_STATE, int256) {
        // check if district is in `lockup`-state
        int256 stateCountdown = int256(TIME_LOCKUP) - int256(block.timestamp - district.lockupTime);
        if (stateCountdown > 0) return (DISTRICT_STATE.LOCKUP, stateCountdown);

        // check if district is in `truce`-state
        stateCountdown = int256(TIME_TRUCE) - int256(block.timestamp - district.lastOutcomeTime);
        if (stateCountdown > 0) return (DISTRICT_STATE.TRUCE, stateCountdown);

        // check if district is in initial `idle`-state
        uint256 attackDeclarationTime = district.attackDeclarationTime;
        if (attackDeclarationTime == 0) return (DISTRICT_STATE.IDLE, 0);

        // check if district is in all other states
        stateCountdown =
            int256(TIME_REINFORCEMENTS)
            - int256(block.timestamp - attackDeclarationTime)
            - int256(district.blitzTimeReduction); // prettier-ignore

        if (stateCountdown > 0) return (DISTRICT_STATE.REINFORCEMENT, stateCountdown);

        stateCountdown += int256(TIME_GANG_WAR);
        if (stateCountdown > 0) return (DISTRICT_STATE.GANG_WAR, stateCountdown);

        return (DISTRICT_STATE.POST_GANG_WAR, stateCountdown);
    }

    function _advanceDistrictRound(uint256 districtId) private {
        District storage district = s().districts[districtId];

        district.attackers = Gang.NONE;
        district.activeItems = 0;
        district.baronAttackId = 0;
        district.baronDefenseId = 0;
        district.lastOutcomeTime = block.timestamp;
        district.attackDeclarationTime = 0;
        district.blitzTimeReduction = 0;

        ++district.roundId;
    }

    function _call911Now(uint256 districtId) private {
        District storage district = s().districts[districtId];

        Gang token = district.token;

        uint256 lockupAmount0;
        uint256 lockupAmount1;
        uint256 lockupAmount2;

        if (token == Gang.YAKUZA) lockupAmount0 = LOCKUP_FINE;
        else if (token == Gang.CARTEL) lockupAmount1 = LOCKUP_FINE;
        else if (token == Gang.CYBERP) lockupAmount2 = LOCKUP_FINE;

        uint256 lockupOccupants = uint256(district.occupants);
        uint256 lockupAttackers = uint256(district.attackDeclarationTime != 0 ? district.attackers : Gang.NONE);

        vault.spendGangVaultBalance(lockupOccupants, lockupAmount0, lockupAmount1, lockupAmount2, false);

        // if attackers are present
        if (lockupAttackers != uint256(Gang.NONE)) {
            vault.spendGangVaultBalance(lockupAttackers, lockupAmount0, lockupAmount1, lockupAmount2, false);
        }

        _advanceDistrictRound(districtId);

        district.lockupTime = block.timestamp;

        emit CopsLockup(districtId, Gang(lockupOccupants), Gang(lockupAttackers));
    }

    function _applyBaronItemToDistrict(uint256 itemId, uint256 districtId) private {
        uint256 items = s().districts[districtId].activeItems;

        if (items & (1 << itemId) != 0) revert ItemAlreadyActive();

        s().districts[districtId].activeItems = items | (1 << itemId);
    }

    function _collectBadges(uint256 gangsterId) private {
        Gangster storage gangster = s().gangsters[gangsterId];

        uint256 roundId = gangster.roundId;

        if (roundId != 0) {
            uint256 districtId = gangster.location;

            uint256 outcome = s().gangWarOutcomes[districtId][roundId];

            if (outcome != 0) {
                bool lastRoundInjured = _isInjured(gangsterId, districtId, roundId);
                bool lastRoundVictory = gangster.attack == gangAttackSuccess(districtId, roundId);
                uint256 badgesEarned = lastRoundVictory ? BADGES_EARNED_VICTORY : BADGES_EARNED_DEFEAT;

                if (lastRoundInjured) emit GangsterInjured(districtId, gangsterId);

                // @note can we assume msg.sender?
                // should probably go into GMC contract
                address owner = gmc.ownerOf(gangsterId);

                Offer memory rental = gmc.getActiveOffer(gangsterId);

                address renter = rental.renter;

                if (renter != address(0)) {
                    uint256 renterAmount = (badgesEarned * rental.renterShare) / 100;

                    badges.mint(renter, renterAmount);

                    badgesEarned -= renterAmount;
                }

                badges.mint(owner, badgesEarned);

                uint256 p = _gangWarWonDistrictProb(districtId, roundId);

                emit BadgesEarned(districtId, gangsterId, gangOf(gangsterId), lastRoundVictory, p);

                gangster.roundId = 0;
            }
        }
    }

    function _verifyAuthorizedUser(address owner, uint256 tokenId) private view {
        if (!gmc.isAuthorizedUser(owner, tokenId)) revert NotAuthorized();
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
            uint256 requestId = requestVRF();
            s().requestIdToDistrictIds[requestId] = upkeepIds;
        }
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 ids = s().requestIdToDistrictIds[requestId];

        if (ids == 0) revert InvalidVRFRequest();

        bool copsLockupRequest = ids == ITEM_911_REQUEST;

        uint256 rand = randomWords[0];
        District storage district;

        bool lockup = copsLockupRequest || uint256(keccak256(abi.encode(rand, 0))) % 100 < LOCKUP_CHANCE;
        uint256 lockupDistrictId = rand % 21;

        if (lockup) {
            uint256 i;

            for (; i < 16 && block.timestamp - s().districts[lockupDistrictId].lockupTime < TIME_LOCKUP; ++i) {
                rand = rand >> 16;
                lockupDistrictId = rand % 21; // first 16 districts have chance of 3121 in 2^16 (vs. 3120)
            }
            // we give up after 16 tries; tough luck
            if (lockup = i != 16) {
                _call911Now(lockupDistrictId);

                // signal that it was triggered by an item
                if (copsLockupRequest) {
                    _applyBaronItemToDistrict(ITEM_911, lockupDistrictId);
                }
            }
        }

        if (!copsLockupRequest) {
            bool validUpkeep;

            for (uint256 id; id < 21; ) {
                if (gasleft() < 2_000) break; // get better estimate

                if ((ids >> id) & 1 != 0) {
                    district = s().districts[id];

                    // 911 call might've changed the district state
                    // note that we need to mark the call as valid
                    if (lockup && lockupDistrictId == id) {
                        validUpkeep = true;
                        unchecked {
                            ++id;
                        }
                        continue;
                    }

                    (DISTRICT_STATE districtState, ) = _districtStateAndCountdown(district);

                    if (districtState == DISTRICT_STATE.POST_GANG_WAR) {
                        Gang attackers = district.attackers;
                        Gang occupants = district.occupants;

                        uint256 roundId = district.roundId;

                        uint256 r = uint256(keccak256(abi.encode(rand, id)));

                        s().gangWarOutcomes[id][roundId] = r;

                        if (gangAttackSuccess(id, roundId)) {
                            vault.transferYield(
                                uint256(occupants),
                                uint256(attackers),
                                uint256(district.token),
                                district.yield
                            );

                            district.occupants = attackers;

                            emit GangWarWon(id, occupants, attackers);
                        } else {
                            emit GangWarWon(id, attackers, occupants);
                        }

                        _advanceDistrictRound(id);
                    }

                    validUpkeep = true;
                }

                unchecked {
                    ++id;
                }
            }

            // revert, because we don't want any lockup
            // to be triggered for invalid/duplicate requests
            if (!validUpkeep) revert InvalidUpkeep();
        }

        delete s().requestIdToDistrictIds[requestId];
    }

    /* ------------- modifier ------------- */

    modifier isActiveSeason() {
        if (block.timestamp < seasonStart || seasonEnd < block.timestamp) revert GangWarNotActive();
        _;
    }

    /* ------------- owner ------------- */

    function setBaronItemBalances(uint256[] calldata itemIds, uint256[] calldata amounts) external payable onlyOwner {
        for (uint256 i; i < itemIds.length; ++i) {
            for (uint256 gang; gang < 3; ++gang) {
                s().baronItems[Gang(gang)][itemIds[i]] = amounts[i];
            }
        }
    }

    function setBaronItemCost(uint256 itemId, uint256 cost) external payable onlyOwner {
        s().baronItemCost[itemId] = cost;
    }

    function setBriberyFee(address token, uint256 amount) external payable onlyOwner {
        s().briberyFee[token] = amount;
    }

    function _authorizeUpgrade() internal override onlyOwner {}
}

function gangWarWonProbFn(
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

function isInjuredProbFn(uint256 gangWarWonP, bool gangWarWon) pure returns (uint256) {
    uint256 c = gangWarWon ? INJURED_WON_FACTOR : INJURED_LOST_FACTOR;

    return (c * ((1 << 128) - 1 - gangWarWonP)) / 100; // >> 128
}

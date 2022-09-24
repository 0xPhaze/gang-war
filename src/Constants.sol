// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {LibPackedMap} from "./lib/LibPackedMap.sol";

// ------------- Constants

// new Date(' Sep 24 2022 15:00:00 GMT+0200 (Central European Summer Time)').getTime() / 1000
// uint256 constant SEASON_START_DATE = 1664024400;
// uint256 constant SEASON_END_DATE = 1664197200;
uint256 constant SEASON_START_DATE = 1664184600;
uint256 constant SEASON_END_DATE = 1664017200;

uint256 constant TIME_TRUCE = 20 minutes;
uint256 constant TIME_LOCKUP = 60 minutes;
uint256 constant TIME_GANG_WAR = 20 minutes;
uint256 constant TIME_RECOVERY = 60 minutes;
uint256 constant TIME_REINFORCEMENTS = 30 minutes;

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

string constant SEASON = "season.xxx.07";

bytes32 constant DIAMOND_STORAGE_GANG_WAR = keccak256("diamond.storage.gang.war.season.xxx.07");

function s() pure returns (GangWarDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_GANG_WAR;
    assembly { diamondStorage.slot := slot } // prettier-ignore
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

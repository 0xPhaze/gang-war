// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {IERC721} from "./interfaces/IERC721.sol";
import {LibPackedMap} from "./lib/LibPackedMap.sol";

// ------------- Constants

// TODO
// XXX
// uint256 constant TIME_TRUCE = 4 hours;
// uint256 constant TIME_LOCKUP = 12 hours;
// uint256 constant TIME_GANG_WAR = 3 hours;
// uint256 constant TIME_RECOVERY = 12 hours;
// uint256 constant TIME_REINFORCEMENTS = 5 hours;
uint256 constant TIME_TRUCE = 10 minutes;
uint256 constant TIME_LOCKUP = 10 minutes;
uint256 constant TIME_GANG_WAR = 10 minutes;
uint256 constant TIME_RECOVERY = 10 minutes;
uint256 constant TIME_REINFORCEMENTS = 10 minutes;

uint256 constant DEFENSE_FAVOR_LIM = 150;
uint256 constant BARON_DEFENSE_FORCE = 50;
uint256 constant ATTACK_FAVOR = 65;
uint256 constant DEFENSE_FAVOR = 200;

uint256 constant LOCKUP_CHANCE = 20;
uint256 constant LOCKUP_FINE = 50e18;

uint256 constant INJURED_WON_FACTOR = 35;
uint256 constant INJURED_LOST_FACTOR = 65;

uint256 constant GANG_VAULT_FEE = 20;

uint256 constant BADGES_EARNED_VICTORY = 6e18;
uint256 constant BADGES_EARNED_DEFEAT = 2e18;

uint256 constant UPKEEP_INTERVAL = 5 minutes;

uint256 constant ITEM_SEWER = 0;
uint256 constant ITEM_BLITZ = 1;
uint256 constant ITEM_BARRICADES = 2;
uint256 constant ITEM_SMOKE = 3;
uint256 constant ITEM_911 = 4;

uint256 constant NUM_BARON_ITEMS = 5;

uint256 constant ITEM_BLITZ_TIME_REDUCTION = 80;
uint256 constant ITEM_BARRICADES_DEFENSE_INCREASE = 30;
uint256 constant ITEM_SMOKE_ATTACK_INCREASE = 30;

// ------------- Enum

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

// ------------- Struct

struct Gangster {
    uint256 roundId;
    uint256 location;
    uint256 bribery;
    uint256 recovery;
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
    // variables from here on are not explicitly set
    // but only written to in the view functions for getters
    // don't read these directly in the contract!
    DISTRICT_STATE state;
    int256 stateCountdown;
    uint256 attackForces;
    uint256 defenseForces;
}

struct GangWarDS {
    address gmc;
    address badges;
    uint256 districtConnections; // packed bool matrix
    uint256 lockupTime;
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
}

// ------------- Storage

bytes32 constant DIAMOND_STORAGE_GANG_WAR = keccak256("diamond.storage.gang.war");

function s() pure returns (GangWarDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_GANG_WAR;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

// ------------- Errors

error CallerNotOwner();
error ItemAlreadyActive();

abstract contract GangWarBase is OwnableUDS {
    GangWarDS private __storageLayout;

    /* ------------- internal ------------- */

    function isBaron(uint256 tokenId) internal pure returns (bool) {
        return tokenId >= 1000;
    }

    function _verifyAuthorized(address owner, uint256 tokenId) internal view virtual;

    function isConnecting(uint256 districtA, uint256 districtB) internal view returns (bool) {
        return LibPackedMap.isConnecting(s().districtConnections, districtA, districtB);
    }

    function _useBaronItem(
        Gang gang,
        uint256 itemId,
        uint256 districtId
    ) internal {
        s().baronItems[gang][itemId] -= 1;

        uint256 items = s().districts[districtId].activeItems;

        if (items & (1 << itemId) != 0) revert ItemAlreadyActive();

        s().districts[districtId].activeItems = items | (1 << itemId);
    }

    /* ------------- view ------------- */

    function gmc() public view returns (address) {
        return s().gmc;
    }

    function gangOf(uint256 id) public pure returns (Gang) {
        return id == 0 ? Gang.NONE : Gang((id < 10000 ? id - 1 : id - (10001 - 3)) % 3);
    }

    function getBaronItemBalances(Gang gang) external view returns (uint256[] memory items) {
        items = new uint256[](NUM_BARON_ITEMS);
        unchecked {
            for (uint256 i; i < NUM_BARON_ITEMS; ++i) items[i] = s().baronItems[gang][i];
        }
    }

    function getGangWarOutcome(uint256 districtId, uint256 roundId) external view returns (uint256) {
        return s().gangWarOutcomes[districtId][roundId];
    }

    function briberyFee(address token) public view returns (uint256) {
        return s().briberyFee[token];
    }

    /* ------------- Owner ------------- */

    function setBaronItemCost(uint256 itemId, uint256 cost) external payable onlyOwner {
        s().baronItemCost[itemId] = cost;
    }

    function setBriberyFee(address token, uint256 amount) external payable onlyOwner {
        s().briberyFee[token] = amount;
    }

    // function setDistrictOccupants(Gang[21] calldata gangs) external payable onlyOwner {
    //     for (uint256 i; i < 21; ++i) {
    //         s().districts[i].occupants = gangs[i];
    //     }
    // }

    // function setDistrictConnections(uint256 connections) external payable onlyOwner {
    //     s().districtConnections = connections;
    // }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {IERC721} from "./interfaces/IERC721.sol";
import {PackedMap} from "./lib/PackedMap.sol";

// ------------- Constants

uint256 constant TIME_TRUCE = 4 hours;
uint256 constant TIME_LOCKUP = 12 hours;
uint256 constant TIME_GANG_WAR = 3 hours;
uint256 constant TIME_RECOVERY = 12 hours;
uint256 constant TIME_REINFORCEMENTS = 5 hours;

uint256 constant DEFENSE_FAVOR_LIM = 150;
uint256 constant BARON_DEFENSE_FORCE = 50;
uint256 constant ATTACK_FAVOR = 65;
uint256 constant DEFENSE_FAVOR = 200;

uint256 constant INJURED_WON_FACTOR = 35;
uint256 constant INJURED_LOST_FACTOR = 65;

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
    TRUCE
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
}

struct GangsterView {
    Gang gang;
    PLAYER_STATE state;
    int256 stateCountdown;
    uint256 roundId;
    uint256 location;
}

struct District {
    // Gang gangTokenYield;
    Gang occupants;
    Gang attackers;
    Gang token;
    uint256 roundId;
    uint256 attackDeclarationTime;
    uint256 baronAttackId;
    uint256 baronDefenseId;
    uint256 lastUpkeepTime;
    uint256 lastOutcomeTime;
    uint256 lockupTime;
    uint256 yield;
}

struct GangWarDS {
    address gmc;
    uint256 districtConnections; // packed bool matrix
    mapping(uint256 => District) districts;
    mapping(uint256 => Gangster) gangsters;
    /*   districtId => districtIds  */
    mapping(uint256 => uint256) requestIdToDistrictIds; // used by chainlink VRF request callbacks
    /*   districtId =>     roundId     => outcome  */
    mapping(uint256 => mapping(uint256 => uint256)) gangWarOutcomes;
    /*   districtId =>     roundId     =>         Gang => numForces */
    mapping(uint256 => mapping(uint256 => mapping(Gang => uint256))) districtAttackForces;
    mapping(uint256 => mapping(uint256 => mapping(Gang => uint256))) districtDefenseForces;
}

// ------------- Storage

// keccak256("diamond.storage.gang.war") == 0x1465defc4302777e9f3331026df5b673e1fdbf0798e6f23608defa528993ece8;
bytes32 constant DIAMOND_STORAGE_GANG_WAR = 0x1465defc4302777e9f3331026df5b673e1fdbf0798e6f23608defa528993ece8;

function s() pure returns (GangWarDS storage diamondStorage) {
    assembly { diamondStorage.slot := DIAMOND_STORAGE_GANG_WAR } // prettier-ignore
}

// ------------- Errors

error CallerNotOwner();

abstract contract GangWarBase is OwnableUDS {
    /* ------------- Internal ------------- */

    function isBaron(uint256 tokenId) internal pure returns (bool) {
        return tokenId >= 1000;
    }

    function _validateOwnership(address owner, uint256 tokenId) internal view {
        if (IERC721(s().gmc).ownerOf(tokenId) != owner) revert CallerNotOwner();
    }

    function isConnecting(uint256 districtA, uint256 districtB) internal view returns (bool) {
        return PackedMap.isConnecting(s().districtConnections, districtA, districtB);
    }

    /* ------------- View ------------- */

    function gangOf(uint256 id) public pure returns (Gang) {
        // return id == 0 ? Gang.NONE : Gang((id < 1000 ? id : id - 1000) % 3);
        return id == 0 ? Gang.NONE : Gang((id < 1000 ? id - 1 : id - 1001) % 3);
    }

    // function getDistrict(uint256 districtId) external view returns (District memory) {
    //     return s().districts[districtId];
    // }

    function getDistrict(uint256 districtId) external view returns (District memory) {
        return s().districts[districtId];
    }

    function getDistrictConnections() external view returns (uint256) {
        return s().districtConnections;
    }

    function getDistrictAttackForces(
        uint256 districtId,
        uint256 roundId,
        Gang gang
    ) external view returns (uint256) {
        return s().districtAttackForces[districtId][roundId][gang];
    }

    function getDistrictDefenseForces(
        uint256 districtId,
        uint256 roundId,
        Gang gang
    ) external view returns (uint256) {
        return s().districtDefenseForces[districtId][roundId][gang];
    }

    function getGangWarOutcome(uint256 districtId, uint256 roundId) external view returns (uint256) {
        return s().gangWarOutcomes[districtId][roundId];
    }

    // function getConstants() external pure returns (ConstantsDS memory) {
    //     return constants();
    // }

    /* ------------- Internal ------------- */

    function _afterDistrictTransfer(
        Gang attackers,
        Gang defenders,
        District storage district
    ) internal virtual;

    /* ------------- Owner ------------- */

    function setDistrictsInitialOwnership(Gang[21] calldata gangs) external onlyOwner {
        for (uint256 i; i < 21; ++i) s().districts[i].occupants = gangs[i];
    }

    function setDistrictConnections(uint256 connections) external onlyOwner {
        s().districtConnections = connections;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS} from "UDS/ERC721UDS.sol";
import "./GangWarBase.sol";

/* ============= Constants ============= */
// uint256 constant STATUS_IDLE = 0;
// uint256 constant STATUS_ATTACK = 1;
// uint256 constant STATUS_DEFEND = 2;
// uint256 constant STATUS_RECOVERY = 3;
// uint256 constant STATUS_LOCKUP = 4;

/* ============= Storage ============= */

// keccak256("diamond.storage.gang.war") == 0x1465defc4302777e9f3331026df5b673e1fdbf0798e6f23608defa528993ece8;
bytes32 constant DIAMOND_STORAGE_GANG_WAR = 0x1465defc4302777e9f3331026df5b673e1fdbf0798e6f23608defa528993ece8;

// keccak256("diamond.storage.gang.war.settings") == 0x8888f95c81e8a85148526340bc32f8046bd9cdfc432a8ade56077881a62383a9;
bytes32 constant DIAMOND_STORAGE_GANG_WAR_SETTINGS = 0x8888f95c81e8a85148526340bc32f8046bd9cdfc432a8ade56077881a62383a9;

/* ============= Enum ============= */

enum GANG {
    NONE,
    YAKUZA,
    CARTEL,
    CYBERP
}

enum DISTRICT_STATUS {
    IDLE,
    ATTACK,
    POST_ATTACK
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

/* ============= Struct ============= */

struct Gangster {
    uint256 roundId;
    uint256 location;
}

struct GangsterView {
    GANG gang;
    PLAYER_STATE state;
    int256 stateCountdown;
    uint256 roundId;
    uint256 location;
}

struct District {
    GANG occupants;
    GANG attackers;
    uint256 roundId;
    uint256 attackDeclarationTime;
    uint256 baronAttackId;
    uint256 baronDefenseId;
    uint256 lastUpkeepTime;
    uint256 lockupTime;
}

struct GangWarDS {
    ERC721UDS gmc;
    mapping(uint256 => District) districts;
    mapping(uint256 => Gangster) gangsters;
    /*   districtId => yield */
    mapping(uint256 => uint256) districtYield;
    /*   districtId =>     roundId     => outcome  */
    mapping(uint256 => mapping(uint256 => uint256)) gangWarOutcomes;
    /*   districtId =>     roundId     =>         GANG => numForces */
    mapping(uint256 => mapping(uint256 => mapping(GANG => uint256))) districtAttackForces;
    mapping(uint256 => mapping(uint256 => mapping(GANG => uint256))) districtDefenseForces;
    mapping(uint256 => mapping(uint256 => bool)) districtConnections;
    mapping(GANG => uint256) gangYield;
}

struct ConstantsDS {
    uint256 TIME_LOCKUP;
    uint256 TIME_GANG_WAR;
    uint256 TIME_RECOVERY;
    uint256 TIME_REINFORCEMENTS;
    uint256 DEFENSE_FAVOR_LIM;
    uint256 BARON_DEFENSE_FORCE;
    uint256 ATTACK_FAVOR;
    uint256 DEFENSE_FAVOR;
}

function ds() pure returns (GangWarDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_GANG_WAR
    }
}

function constants() pure returns (ConstantsDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_GANG_WAR_SETTINGS
    }
}

abstract contract GangWarStorage {
    /* ------------- View ------------- */

    // function getDistrict(uint256 districtId) external view returns (District memory) {
    //     return ds().districts[districtId];
    // }

    function getDistrict(uint256 districtId) external view returns (District memory) {
        return ds().districts[districtId];
    }

    function getDistrictConnections(uint256 districtA, uint256 districtB) external view returns (bool) {
        return ds().districtConnections[districtA][districtB];
    }

    function getDistrictAttackForces(
        uint256 districtId,
        uint256 roundId,
        GANG gang
    ) external view returns (uint256) {
        return ds().districtAttackForces[districtId][roundId][gang];
    }

    function getDistrictDefenseForces(
        uint256 districtId,
        uint256 roundId,
        GANG gang
    ) external view returns (uint256) {
        return ds().districtDefenseForces[districtId][roundId][gang];
    }

    function getGangWarOutcome(uint256 districtId, uint256 roundId) external view returns (uint256) {
        return ds().gangWarOutcomes[districtId][roundId];
    }

    function getConstants() external pure returns (ConstantsDS memory) {
        return constants();
    }
}

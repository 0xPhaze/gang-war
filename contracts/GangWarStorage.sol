// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS} from "UDS/ERC721UDS.sol";
import "./GangWarBase.sol";

/* ============= Constants ============= */
// uint256 constant STATUS_IDLE = 0;
// uint256 constant STATUS_ATTACKING = 1;
// uint256 constant STATUS_DEFENDING = 2;
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

enum MOVE_STATE {
    ATTACKING,
    DEFENDING
}

enum DISTRICT_STATUS {
    IDLE,
    ATTACKING,
    POST_ATTACK
}

enum PLAYER_STATE {
    IDLE,
    ATTACKING,
    DEFENDING,
    INJURED,
    LOCKUP
}

/* ============= Struct ============= */

struct Gangster {
    GANG gang;
    uint256 roundId;
    uint256 location;
}

struct District {
    uint256 roundId;
    GANG occupants;
    GANG attackers;
    /*      roundId => rand  */
    mapping(uint256 => uint256) outcomes;
    uint256 attackDeclarationTime;
    uint256 baronAttackId;
    uint256 baronDefenseId;
    uint256 lastUpkeepTime;
    uint256 lockupTime;
    /*      roundId =>         GANG => numForces */
    mapping(uint256 => mapping(GANG => uint256)) attackForces;
    mapping(uint256 => mapping(GANG => uint256)) defenseForces;
}

struct GangWarDS {
    ERC721UDS gmc;
    mapping(uint256 => District) districts;
    mapping(uint256 => Gangster) gangsters;
    mapping(uint256 => mapping(uint256 => bool)) connections;
    mapping(GANG => uint256) gangYield;
}

struct SettingsDS {
    uint256 TIME_MOVE;
    uint256 TIME_LOCKUP;
    uint256 TIME_RECOVERY;
    uint256 TIME_REINFORCEMENTS;
    mapping(uint256 => uint256) districtYield;
}

function ds() pure returns (GangWarDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_GANG_WAR
    }
}

function settings() pure returns (SettingsDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_GANG_WAR_SETTINGS
    }
}

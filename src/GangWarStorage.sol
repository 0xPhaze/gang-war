// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS} from "UDS/ERC721UDS.sol";
import {IERC721} from "./interfaces/IERC721.sol";
import {OwnableUDS} from "UDS/OwnableUDS.sol";

// import "./GangWarBase.sol";

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

enum Gang {
    NONE,
    YAKUZA,
    CARTEL,
    CYBERP
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

/* ============= Struct ============= */

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
    mapping(uint256 => District) districts;
    mapping(uint256 => Gangster) gangsters;
    /*   districtId => districtIds  */
    mapping(uint256 => uint256) requestIdToDistrictIds;
    /*   districtId =>     roundId     => outcome  */
    mapping(uint256 => mapping(uint256 => uint256)) gangWarOutcomes;
    /*   districtId =>     roundId     =>         Gang => numForces */
    mapping(uint256 => mapping(uint256 => mapping(Gang => uint256))) districtAttackForces;
    mapping(uint256 => mapping(uint256 => mapping(Gang => uint256))) districtDefenseForces;
    mapping(uint256 => mapping(uint256 => bool)) districtConnections;
    mapping(Gang => uint256) gangYield;
}

struct ConstantsDS {
    uint256 TIME_TRUCE;
    uint256 TIME_LOCKUP;
    uint256 TIME_GANG_WAR;
    uint256 TIME_RECOVERY;
    uint256 TIME_REINFORCEMENTS;
    uint256 DEFENSE_FAVOR_LIM;
    uint256 BARON_DEFENSE_FORCE;
    uint256 ATTACK_FAVOR;
    uint256 DEFENSE_FAVOR;
}

function s() pure returns (GangWarDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_GANG_WAR
    }
}

function constants() pure returns (ConstantsDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_GANG_WAR_SETTINGS
    }
}

/* ============= Errors ============= */

error CallerNotOwner();

abstract contract GangWarBase is OwnableUDS {
    function __GangWarBase_init(address gmc) internal {
        s().gmc = gmc;
    }

    function initDistrictRoundIds() internal {
        for (uint256 i; i < 21; ++i) {
            s().districts[i].roundId = 1;
        }
    }

    function initDistrictOccupantsAndYield(Gang[] calldata gangs, uint256[] calldata yield) internal {
        for (uint256 i; i < 21; ++i) {
            s().districts[i + 1].occupants = gangs[i];
            s().districts[i + 1].yield = yield[i];

            s().gangYield[gangs[i]] += yield[i];
        }
    }

    /* ------------- View ------------- */

    function requestIdToDistrictIds(uint256 requestId) public view returns (uint256) {
        return s().requestIdToDistrictIds[requestId];
    }

    function isBaron(uint256 tokenId) internal pure returns (bool) {
        return tokenId >= 1000;
    }

    function gangOf(uint256 id) public pure returns (Gang) {
        // return id == 0 ? Gang.NONE : Gang((id < 1000 ? id : id - 1000) % 3);
        return id == 0 ? Gang.NONE : Gang(((id < 1000 ? id - 1 : id - 1001) % 3) + 1);
    }

    function _validateOwnership(address owner, uint256 tokenId) internal view {
        if (IERC721(s().gmc).ownerOf(tokenId) != owner) revert CallerNotOwner();
    }

    function isConnecting(uint256 districtA, uint256 districtB) internal view returns (bool) {
        return
            districtA < districtB
                ? s().districtConnections[districtA][districtB]
                : s().districtConnections[districtB][districtA]; // prettier-ignore
    }

    // function getDistrict(uint256 districtId) external view returns (District memory) {
    //     return s().districts[districtId];
    // }

    function getDistrict(uint256 districtId) external view returns (District memory) {
        return s().districts[districtId];
    }

    function getDistrictConnections(uint256 districtA, uint256 districtB) external view returns (bool) {
        return s().districtConnections[districtA][districtB];
    }

    function getAllDistrictConnections() external view returns (bool[21][21] memory out) {
        for (uint256 i; i < 21; ++i) {
            for (uint256 j; j < 21; ++j) {
                out[i][j] = s().districtConnections[i][j];
            }
        }
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

    function getConstants() external pure returns (ConstantsDS memory) {
        return constants();
    }

    /* ------------- Internal ------------- */

    function _afterDistrictTransfer(
        Gang attackers,
        Gang defenders,
        uint256 id
    ) internal virtual;

    /* ------------- Owner ------------- */

    function setDistrictsInitialOwnership(Gang[21] calldata gangs) external onlyOwner {
        for (uint256 i; i < 21; ++i) s().districts[i].occupants = gangs[i];
    }

    function addDistrictConnections(uint256[] calldata districtsA, uint256[] calldata districtsB) external onlyOwner {
        for (uint256 i; i < districtsA.length; ++i) {
            assert(districtsA[i] < districtsB[i]);
            s().districtConnections[districtsA[i]][districtsB[i]] = true;
        }
    }

    function removeDistrictConnections(uint256[] calldata districtsA, uint256[] calldata districtsB)
        external
        onlyOwner
    {
        for (uint256 i; i < districtsA.length; ++i) {
            assert(districtsA[i] < districtsB[i]);
            s().districtConnections[districtsA[i]][districtsB[i]] = false;
        }
    }
}

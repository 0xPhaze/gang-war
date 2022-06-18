// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeV} from "UDS/proxy/UUPSUpgradeV.sol";
import {OwnableUDS} from "UDS/OwnableUDS.sol";
import {ERC721UDS} from "UDS/ERC721UDS.sol";

// import {GangWarBase} from "./GangWarBase.sol";
// import {GMCMarket} from "./GMCMarket.sol";
// import {ds, settings, District, Gangster} from
import "./GangWarStorage.sol";
import "./GangWarRewards.sol";
import "./GangWarBase.sol";
// import {GangWarGameLogic} from "./GangWarGameLogic.sol";
import "./GangWarGameLogic.sol";

import "forge-std/console.sol";

/* ============= Error ============= */

contract GangWar is UUPSUpgradeV(1), OwnableUDS, GangWarStorage, GangWarGameLogic, GangWarLoot {
    constructor(
        address coordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit
    ) VRFConsumerV2(coordinator, keyHash, subscriptionId, requestConfirmations, callbackGasLimit) {}

    function init(ERC721UDS gmc_) external initializer {
        __Ownable_init();
        __GangWarBase_init(gmc_);
        __GangWarGameLogic_init();
        __GangWarLoot_init();
    }

    /* ------------- Internal ------------- */

    /* ------------- Owner ------------- */

    function setDistrictsInitialOwnership(uint256[] calldata districtIds, GANG[] calldata gangs) external onlyOwner {
        for (uint256 i; i < districtIds.length; ++i) {
            ds().districts[districtIds[i]].occupants = gangs[i];
        }
    }

    function addDistrictConnections(uint256[] calldata districtsA, uint256[] calldata districtsB) external onlyOwner {
        for (uint256 i; i < districtsA.length; ++i) {
            assert(districtsA[i] < districtsB[i]);
            ds().districtConnections[districtsA[i]][districtsB[i]] = true;
        }
    }

    function removeDistrictConnections(uint256[] calldata districtsA, uint256[] calldata districtsB)
        external
        onlyOwner
    {
        for (uint256 i; i < districtsA.length; ++i) {
            assert(districtsA[i] < districtsB[i]);
            ds().districtConnections[districtsA[i]][districtsB[i]] = false;
        }
    }

    /* ------------- Internal ------------- */

    function _afterDistrictTransfer(
        GANG attackers,
        GANG defenders,
        uint256 id
    ) internal override {}

    function _authorizeUpgrade() internal override onlyOwner {}
}

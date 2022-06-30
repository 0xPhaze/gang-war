// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeV} from "UDS/proxy/UUPSUpgradeV.sol";
import {OwnableUDS} from "UDS/OwnableUDS.sol";
import {ERC721UDS} from "UDS/ERC721UDS.sol";

// import {GangWarBase} from "./GangWarBase.sol";
// import {GMCMarket} from "./GMCMarket.sol";
// import {s, settings, District, Gangster} from
import "./GangWarStorage.sol";
// import "./GangWarBase.sol";

import "forge-std/console.sol";

/* ============= Error ============= */

// error BaronMustDeclareInitialAttack();

// keccak256("diamond.storage.gang.war.loot") == 0x076685b2aa01832c55a9b2559f78ba96625db8abd5a9610a05c48d76a9ae1fd5;
bytes32 constant DIAMOND_STORAGE_GANG_WAR_LOOT = 0x076685b2aa01832c55a9b2559f78ba96625db8abd5a9610a05c48d76a9ae1fd5;

struct YieldDS {
    uint256 totalSupply;
    mapping(address => uint256) userRewardPerTokenPaid;
}

function yieldDS() pure returns (YieldDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_GANG_WAR
    }
}

abstract contract GangWarRewards {
    /* ------------- Internal ------------- */

    function updateGangRewards(
        Gang attackers,
        Gang defenders,
        uint256 districtId
    ) internal {
        uint256 yield = s().districts[districtId].yield;

        s().gangYield[attackers] += yield;
        s().gangYield[defenders] -= yield;
    }

    /* ------------- View ------------- */

    function getGangYields()
        external
        view
        returns (
            uint256 yieldYakuza,
            uint256 yieldCartel,
            uint256 yieldCyberpunk
        )
    {
        yieldYakuza = s().gangYield[Gang.YAKUZA];
        yieldCartel = s().gangYield[Gang.CARTEL];
        yieldCyberpunk = s().gangYield[Gang.CYBERP];
    }
}

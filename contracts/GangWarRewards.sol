// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeV} from "UDS/proxy/UUPSUpgradeV.sol";
import {OwnableUDS} from "UDS/OwnableUDS.sol";
import {ERC721UDS} from "UDS/ERC721UDS.sol";

// import {GangWarBase} from "./GangWarBase.sol";
// import {GMCMarket} from "./GMCMarket.sol";
// import {ds, settings, District, Gangster} from
import "./GangWarStorage.sol";
// import "./GangWarBase.sol";

import "forge-std/console.sol";

/* ============= Error ============= */

// error BaronMustDeclareInitialAttack();

abstract contract GangWarLoot {
    /* ------------- Internal ------------- */

    function __GangWarLoot_init() internal {
        uint256 yield;
        for (uint256 id; id < 21; ++id) {
            GANG occupants = ds().districts[id].occupants;
            yield = ds().districts[id].yield;
            ds().gangYield[occupants] += yield;

            assert(occupants != GANG.NONE);
            assert(yield > 0);
        }
    }

    function updateGangRewards(
        GANG attackers,
        GANG defenders,
        uint256 districtId
    ) internal {
        uint256 yield = ds().districts[districtId].yield;

        ds().gangYield[attackers] += yield;
        ds().gangYield[defenders] -= yield;
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
        yieldYakuza = ds().gangYield[GANG.YAKUZA];
        yieldCartel = ds().gangYield[GANG.CARTEL];
        yieldCyberpunk = ds().gangYield[GANG.CYBERP];
    }
}

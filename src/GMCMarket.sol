// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeV} from "UDS/proxy/UUPSUpgradeV.sol";
import {OwnableUDS} from "UDS/OwnableUDS.sol";
import {ERC721UDS} from "UDS/ERC721UDS.sol";

// import {GangWarBase} from "./GangWarBase.sol";
import {ds as gangWarDS} from "./GangWarStorage.sol";

/* ============= Storage ============= */

// keccak256("diamond.storage.gang.market") == 0x9350130b46a3a95c1d15eccf95069b652f55a1610fded59bd348259d7c017faf;
bytes32 constant DIAMOND_STORAGE_Gang_MARKET = 0x9350130b46a3a95c1d15eccf95069b652f55a1610fded59bd348259d7c017faf;

struct GangMarketDS {
    mapping(uint256 => address) renter;
}

function ds() pure returns (GangMarketDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_Gang_MARKET
    }
}

/* ============= Error ============= */

error NotAuthorized();

// abstract contract GMCMarket is GangWarBase {
//     function ownerOrRenterOf(uint256 id) public view override returns (address) {
//         address user = ds().renter[id];
//         return user == address(0) ? gangWarDS().gmc.ownerOf(id) : user;
//     }
// }

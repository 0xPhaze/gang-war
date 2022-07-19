// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";

import {s as gangWarDS} from "./GangWarBase.sol";

// ------------- Storage

// keccak256("diamond.storage.gang.market") == 0x9350130b46a3a95c1d15eccf95069b652f55a1610fded59bd348259d7c017faf;
bytes32 constant DIAMOND_STORAGE_GANG_MARKET = 0x9350130b46a3a95c1d15eccf95069b652f55a1610fded59bd348259d7c017faf;

struct GangMarketDS {
    // mapping(uint256 => address) renter;
    mapping(uint256 => uint256) listedShare;
}

function s() pure returns (GangMarketDS storage diamondStorage) {
    assembly {
        diamondStorage.slot := DIAMOND_STORAGE_GANG_MARKET
    }
}

// ------------- Error

error NotAuthorized();
error InvalidOwnerShare();

abstract contract GMCMarket {
    // function ownerOrRenterOf(uint256 id) public view override returns (address) {
    //     address user = ds().renter[id];
    //     return user == address(0) ? gangWarDS().gmc.ownerOf(id) : user;
    // }

    function list(uint256[] calldata ids, uint256 ownerShare) external {
        if (ownerShare > 70) revert InvalidOwnerShare();

        for (uint256 i; i < ids.length; i++) {
            // address owner = gangWarDS().gmc.trueOwnerOf(ids[i]);
            s().listedShare[ids[i]] = ownerShare;
        }
    }
}

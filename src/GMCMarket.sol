// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {IERC721} from "./interfaces/IERC721.sol";

import {s as gangWarDS} from "./GangWarBase.sol";

uint256 constant RENTAL_ACCEPTANCE_MINIMUM_TIME_DELAY = 1 days;

// ------------- storage

// keccak256("diamond.storage.gang.market") == 0x9350130b46a3a95c1d15eccf95069b652f55a1610fded59bd348259d7c017faf;
bytes32 constant DIAMOND_STORAGE_GANG_MARKET = 0x9350130b46a3a95c1d15eccf95069b652f55a1610fded59bd348259d7c017faf;

struct Offer {
    address renter;
    uint8 renterShare;
    bool expiresOnAcceptance;
}

struct GangMarketDS {
    mapping(uint256 => Offer) activeOffers;
    mapping(address => uint256) lastRentalAcceptance;
}

function s() pure returns (GangMarketDS storage diamondStorage) {
    assembly { diamondStorage.slot := DIAMOND_STORAGE_GANG_MARKET } // prettier-ignore
}

// ------------- error

error PrivateOffer();
error ActiveRental();
error NotAuthorized();
error InvalidRenterShare();
error OfferAlreadyAccepted();
error MinimumTimeDelayNotReached();

abstract contract GMCMarket {
    /* ------------- view ------------- */

    function isOwnerOrRenter(address user, uint256 id) public view returns (bool) {
        return IERC721(gangWarDS().gmc).ownerOf(id) == user || s().activeOffers[id].renter == user;
    }

    function getActiveOffer(uint256 id) public view returns (Offer memory) {
        return s().activeOffers[id];
    }

    /* ------------- external ------------- */

    function listOffer(uint256[] calldata ids, Offer[] calldata offers) external {
        for (uint256 i; i < ids.length; i++) {
            uint56 share = offers[i].renterShare;
            address owner = IERC721(gangWarDS().gmc).ownerOf(ids[i]);

            if (owner != msg.sender) revert NotAuthorized();
            if (share < 30 || 100 < share) revert InvalidRenterShare();

            Offer storage activeRental = s().activeOffers[ids[i]];
            address currentRenter = activeRental.renter;

            if (currentRenter != address(0)) {
                // can't change renter once rental is active
                if (offers[i].renter != currentRenter) revert ActiveRental();
                // can't change share once rental is active
                if (offers[i].renterShare != activeRental.renterShare) revert ActiveRental();
            }

            s().activeOffers[ids[i]] = offers[i];
        }
    }

    function acceptOffer(uint256 id) external {
        Offer storage offer = s().activeOffers[id];

        if (block.timestamp - s().lastRentalAcceptance[msg.sender] > RENTAL_ACCEPTANCE_MINIMUM_TIME_DELAY) {
            revert MinimumTimeDelayNotReached();
        }
        if (offer.renter != address(0)) revert OfferAlreadyAccepted();

        offer.renter = msg.sender;

        s().lastRentalAcceptance[msg.sender] = block.timestamp;
    }

    function endRent(uint256 id) external {
        if (!isOwnerOrRenter(msg.sender, id)) revert NotAuthorized();

        Offer storage offer = s().activeOffers[id];

        if (offer.expiresOnAcceptance) delete s().activeOffers[id];
        else offer.renter = address(0);
    }

    /* ------------- hooks ------------- */

    function _afterStartRent(
        address owner,
        address renter,
        uint256 id,
        uint256 renterShares
    ) internal virtual {}

    function _afterEndRent(
        address owner,
        address renter,
        uint256 id,
        uint256 renterShares
    ) internal virtual {}
}

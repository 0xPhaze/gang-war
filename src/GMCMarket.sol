// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {IERC721} from "./interfaces/IERC721.sol";

import {s as gangWarDS} from "./GangWarBase.sol";

// ------------- storage

// keccak256("diamond.storage.gang.market") == 0x9350130b46a3a95c1d15eccf95069b652f55a1610fded59bd348259d7c017faf;
bytes32 constant DIAMOND_STORAGE_GANG_MARKET = 0x9350130b46a3a95c1d15eccf95069b652f55a1610fded59bd348259d7c017faf;

struct Offer {
    address renter;
    uint8 renterShare;
    bool expiresOnAcceptance;
}

struct GangMarketDS {
    mapping(uint256 => Offer) activeRentals;
    mapping(uint256 => Offer) activeOffers;
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

abstract contract GMCMarket {
    /* ------------- view ------------- */

    function isOwnerOrRenter(address user, uint256 id) public view returns (bool) {
        return IERC721(gangWarDS().gmc).ownerOf(id) == user || s().activeRentals[id].renter == user;
    }

    function getActiveOffer(uint256 id) external view returns (Offer memory) {
        return s().activeOffers[id];
    }

    function getActiveRental(uint256 id) public view returns (Offer memory) {
        return s().activeRentals[id];
    }

    /* ------------- external ------------- */

    function listOffer(uint256[] calldata ids, Offer[] calldata offers) external {
        for (uint256 i; i < ids.length; i++) {
            uint56 share = offers[i].renterShare;
            address owner = IERC721(gangWarDS().gmc).ownerOf(ids[i]);

            if (owner != msg.sender) revert NotAuthorized();
            if (share < 30 || 100 < share) revert InvalidRenterShare();

            Offer storage activeRental = s().activeRentals[ids[i]];

            if (activeRental.renter != address(0)) revert ActiveRental();

            s().activeOffers[ids[i]] = offers[i];
        }
    }

    function delistOffer(uint256[] calldata ids) external {
        for (uint256 i; i < ids.length; i++) {
            address owner = IERC721(gangWarDS().gmc).ownerOf(ids[i]);

            if (owner != msg.sender) revert NotAuthorized();

            delete s().activeOffers[ids[i]];
        }
    }

    function acceptOffer(uint256 id) external {
        Offer storage offer = s().activeOffers[id];

        address forUser = offer.renter;

        // make sure this isn't a private offer or is meant for the caller
        if (forUser != address(0) && forUser != msg.sender) revert PrivateOffer();

        Offer storage activeRental = s().activeRentals[id];

        // make sure the offer hasn't been accepted yet
        if (activeRental.renter != address(0)) revert OfferAlreadyAccepted();

        uint8 share = offer.renterShare;

        activeRental.renter = msg.sender;
        activeRental.renterShare = share;

        // _afterStartRent()

        if (offer.expiresOnAcceptance) delete s().activeOffers[id];
    }

    function endRent(uint256 id) external {
        if (!isOwnerOrRenter(msg.sender, id)) revert NotAuthorized();

        delete s().activeRentals[id];
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

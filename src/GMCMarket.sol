// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {LibEnumerableSet} from "UDS/lib/LibEnumerableSet.sol";

uint256 constant RENTAL_ACCEPTANCE_MINIMUM_TIME_DELAY = 1 hours;

// ------------- storage

bytes32 constant DIAMOND_STORAGE_GMC_MARKET = keccak256("diamond.storage.gmc.market.v2");

struct Offer {
    address renter;
    uint8 renterShare;
    bool expiresOnAcceptance;
}

struct GangMarketDS {
    mapping(uint256 => Offer) offers;
    mapping(address => uint256) lastRentalAcceptance;
    // `listedIds` is stuck in a mapping at [0],
    // in order to avoid nested structs.
    mapping(uint256 => LibEnumerableSet.Uint256Set) listedIds;
    mapping(address => LibEnumerableSet.Uint256Set) rentedIds;
}

function s() pure returns (GangMarketDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_GMC_MARKET;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

// ------------- error

error InvalidOffer();
error ActiveRental();
error AlreadyListed();
error NotAuthorized();
error InvalidRenterShare();
error OfferAlreadyAccepted();
error MinimumTimeDelayNotReached();

/// @title Gangsta Mice City Market
/// @author phaze (https://github.com/0xPhaze)
abstract contract GMCMarket {
    using LibEnumerableSet for LibEnumerableSet.Uint256Set;

    GangMarketDS private __storageLayout;

    /* ------------- virtual ------------- */

    function ownerOf(uint256 id) public view virtual returns (address);

    function isAuthorized(address user, uint256 id) public view virtual returns (bool);

    /* ------------- view ------------- */

    function renterOf(uint256 id) public view virtual returns (address) {
        return s().offers[id].renter;
    }

    function getListedOfferByIndex(uint256 index) public view returns (uint256, Offer memory) {
        uint256 id = s().listedIds[0].at(index);
        return (id, s().offers[id]);
    }

    function getListedOffersIds() public view returns (uint256[] memory) {
        return s().listedIds[0].values();
    }

    function numListedOffers() public view returns (uint256) {
        return s().listedIds[0].length();
    }

    function getActiveOffer(uint256 id) public view returns (Offer memory) {
        return s().offers[id];
    }

    function getRentedIds(address user) public view returns (uint256[] memory) {
        return s().rentedIds[user].values();
    }

    function isListed(uint256 id) public view returns (bool) {
        return s().listedIds[0].includes(id);
    }

    function getTimeNextRentAvailable(address user) external view returns (uint256) {
        return s().lastRentalAcceptance[user] + RENTAL_ACCEPTANCE_MINIMUM_TIME_DELAY;
    }

    /* ------------- external ------------- */

    function listOffer(uint256[] calldata ids, Offer[] calldata offers) external {
        for (uint256 i; i < ids.length; i++) {
            uint256 id = ids[i];

            Offer calldata offer = offers[i];
            uint256 renterShare = offer.renterShare;
            // address currentRenter = offer.renter;

            address owner = ownerOf(id);

            if (id > 10_000) revert NotAuthorized();
            if (owner != msg.sender) revert NotAuthorized();
            if (offer.renter == msg.sender) revert InvalidOffer();
            // if (currentRenter != address(0)) revert ActiveRental();
            if (renterShare < 30 || 100 < renterShare) revert InvalidRenterShare();

            // note: this prevents ids being "rented" out
            // multiple times, because they need to be delisted
            // and _cleanUp needs to run first; could also check
            // active rentals and clean up
            bool added = s().listedIds[0].add(id);

            if (!added) revert AlreadyListed();

            // direct offer to renter
            if (offer.renter != address(0)) {
                s().rentedIds[offer.renter].add(id);

                _afterStartRent(owner, offer.renter, id, renterShare);
            }

            // three steps to "accepting an offer":
            // - set `address offer.renter`
            // - add id to `rentedIds[offer.renter]` enumeration
            // - call `_afterStartRent` to transfer shares
            s().offers[id] = offers[i];
        }
    }

    function acceptOffer(uint256 id) external {
        Offer storage offer = s().offers[id];

        if (!isListed(id)) revert InvalidOffer();
        if (offer.renterShare == 0) revert InvalidOffer();
        if (offer.renter != address(0)) revert OfferAlreadyAccepted();
        if (block.timestamp - s().lastRentalAcceptance[msg.sender] < RENTAL_ACCEPTANCE_MINIMUM_TIME_DELAY) {
            revert MinimumTimeDelayNotReached();
        }

        offer.renter = msg.sender;

        s().rentedIds[msg.sender].add(id);
        s().lastRentalAcceptance[msg.sender] = block.timestamp;

        _afterStartRent(ownerOf(id), msg.sender, id, offer.renterShare);
    }

    function deleteOffer(uint256[] calldata ids) external {
        for (uint256 i; i < ids.length; i++) {
            if (ownerOf(ids[i]) != msg.sender) revert NotAuthorized();

            _removeListingAndCleanUp(msg.sender, ids[i]);
        }
    }

    function endRent(uint256[] calldata ids) external {
        for (uint256 i; i < ids.length; ++i) {
            uint256 id = ids[i];

            if (!isAuthorized(msg.sender, id)) revert NotAuthorized();

            Offer storage offer = s().offers[id];

            uint256 renterShare = offer.renterShare;
            bool expires = offer.expiresOnAcceptance;

            // offer has not been accepted / is invalid
            if (offer.renter == address(0)) revert InvalidOffer();

            _removeListingAndCleanUp(ownerOf(id), id);

            // note: make this more robust
            if (!expires) {
                offer.renterShare = uint8(renterShare);
            }
        }
    }

    function _removeListingAndCleanUp(address owner, uint256 id) internal {
        if (s().listedIds[0].remove(id)) {
            Offer storage offer = s().offers[id];

            address renter = offer.renter;
            uint256 renterShare = offer.renterShare;

            if (renter != address(0)) {
                s().rentedIds[renter].remove(id);

                _afterEndRent(owner, renter, id, renterShare);
            }
        }

        delete s().offers[id];
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

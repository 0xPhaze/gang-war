// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {LibEnumerableSet, Uint256Set} from "UDS/lib/LibEnumerableSet.sol";

uint256 constant RENTAL_ACCEPTANCE_MINIMUM_TIME_DELAY = 1 days;

// ------------- storage

bytes32 constant DIAMOND_STORAGE_GMC_MARKET = keccak256("diamond.storage.gmc.market");

struct Offer {
    address renter;
    uint8 renterShare;
    bool expiresOnAcceptance;
}

struct GangMarketDS {
    // listedOffers is stuck in a mapping at [0],
    // because nested structs are dangerous!
    mapping(uint256 => Uint256Set) listedOffers;
    mapping(uint256 => Offer) activeOffers;
    mapping(address => uint256) lastRentalAcceptance;
}

function s() pure returns (GangMarketDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_GMC_MARKET;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

// ------------- error

error InvalidOffer();
error AlreadyListed();
error NotAuthorized();
error InvalidRenterShare();
error OfferAlreadyAccepted();
error MinimumTimeDelayNotReached();

abstract contract GMCMarket {
    using LibEnumerableSet for Uint256Set;

    GangMarketDS private __storageLayout;

    /* ------------- virtual ------------- */

    function ownerOf(uint256 id) public view virtual returns (address);

    function isAuthorized(address user, uint256 id) public view virtual returns (bool);

    /* ------------- view ------------- */

    function renterOf(uint256 id) public view virtual returns (address) {
        return s().activeOffers[id].renter;
    }

    function getListedOfferByIndex(uint256 index) public view returns (uint256, Offer memory) {
        uint256 id = s().listedOffers[0].at(index);
        return (id, s().activeOffers[id]);
    }

    function getListedOffersIds() public view returns (uint256[] memory) {
        return s().listedOffers[0].values();
    }

    function numListedOffers() public view returns (uint256) {
        return s().listedOffers[0].length();
    }

    function getActiveOffer(uint256 id) public view returns (Offer memory) {
        return s().activeOffers[id];
    }

    /* ------------- external ------------- */

    function listOffer(uint256[] calldata ids, Offer[] calldata offers) external {
        for (uint256 i; i < ids.length; i++) {
            uint256 id = ids[i];

            Offer calldata offer = offers[i];
            uint256 renterShare = offer.renterShare;

            address owner = ownerOf(id);

            if (owner != msg.sender) revert NotAuthorized();
            if (offer.renter == msg.sender) revert InvalidOffer();
            if (renterShare < 30 || 100 < renterShare) revert InvalidRenterShare();

            bool added = s().listedOffers[0].add(id);
            if (!added) revert AlreadyListed();

            // Offer storage activeRental = s().activeOffers[id];
            // address currentRenter = activeRental.renter;
            // if (currentRenter != address(0)) revert ActiveRental();

            s().activeOffers[id] = offers[i];

            // direct offer to renter
            if (offer.renter != address(0)) {
                _afterStartRent(owner, offer.renter, id, renterShare);
            }

            s().listedOffers[0].add(id);
        }
    }

    function deleteOffer(uint256[] calldata ids) external {
        for (uint256 i; i < ids.length; i++) {
            if (ownerOf(ids[i]) != msg.sender) revert NotAuthorized();

            _endRentAndDeleteOffer(ids[i]);
        }
    }

    function acceptOffer(uint256 id) external {
        Offer storage offer = s().activeOffers[id];

        if (block.timestamp - s().lastRentalAcceptance[msg.sender] < RENTAL_ACCEPTANCE_MINIMUM_TIME_DELAY) {
            revert MinimumTimeDelayNotReached();
        }

        if (offer.renter != address(0)) revert OfferAlreadyAccepted();

        offer.renter = msg.sender;

        s().lastRentalAcceptance[msg.sender] = block.timestamp;

        _afterStartRent(ownerOf(id), msg.sender, id, offer.renterShare);
    }

    function endRent(uint256[] calldata ids) external {
        for (uint256 i; i < ids.length; ++i) {
            uint256 id = ids[i];

            if (!isAuthorized(msg.sender, id)) revert NotAuthorized();

            Offer storage offer = s().activeOffers[id];

            address renter = offer.renter;
            uint256 renterShare = offer.renterShare;

            // offer has not been accepted / is invalid
            if (offer.renter == address(0)) revert InvalidOffer();

            if (offer.expiresOnAcceptance) {
                _endRentAndDeleteOffer(id);
            } else {
                delete offer.renter;

                _afterEndRent(ownerOf(id), renter, id, renterShare);
            }
        }
    }

    // function rewardBadges(uint256 id) external onlyRole() {
    // }

    /* ------------- internal ------------- */

    function _endRentAndDeleteOffer(uint256 id) internal {
        Offer storage offer = s().activeOffers[id];

        address renter = offer.renter;

        if (renter != address(0)) {
            _afterEndRent(ownerOf(id), renter, id, offer.renterShare);
        }

        delete s().activeOffers[id];

        s().listedOffers[0].remove(id);
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

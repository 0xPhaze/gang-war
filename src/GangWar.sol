// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {OwnableUDS as Ownable} from "UDS/auth/OwnableUDS.sol";

import {IERC721} from "./interfaces/IERC721.sol";

// import {GangWarBase} from "./GangWarBase.sol";
import {GMCMarket, Offer} from "./GMCMarket.sol";
import {GangWarBase, s} from "./GangWarBase.sol";
// import {GangWarGameLogic} from "./GangWarGameLogic.sol";
import "./GangWarGameLogic.sol";

// ------------- error

error NotAuthorized();
error InvalidItemId();

contract GangWar is UUPSUpgrade, Ownable, GangWarBase, GangWarGameLogic, GMCMarket {
    constructor(
        address coordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit
    ) VRFConsumerV2(coordinator, keyHash, subscriptionId, requestConfirmations, callbackGasLimit) {}

    function init(
        address gmc,
        address[3] memory gangTokens,
        address badges,
        uint256 connections,
        Gang[21] calldata occupants,
        uint256[21] calldata yields
    ) external initializer {
        __Ownable_init();

        s().gmc = gmc;
        s().badges = badges;
        s().districtConnections = connections;

        // initialize gang tokens
        _setGangTokens(gangTokens);

        reset(occupants, yields);
    }

    function reset(Gang[21] calldata occupants, uint256[21] calldata yields) public onlyOwner {
        uint256[3] memory initialGangYields;

        District storage district;

        for (uint256 i; i < 21; ++i) {
            district = s().districts[i];

            // initialize rounds
            district.roundId = 1;

            // initialize occupants and yield token
            district.token = occupants[i];
            district.occupants = occupants[i];

            // initialize district yield amount
            district.yield = yields[i];

            initialGangYields[uint256(occupants[i])] += yields[i];
        }

        // initialize yields for gangs
        _setYield(0, 0, initialGangYields[0]);
        _setYield(1, 1, initialGangYields[1]);
        _setYield(2, 2, initialGangYields[2]);
    }

    function purchaseBaronItem(uint256 baronId, uint256 itemId) external {
        _verifyAuthorized(msg.sender, baronId);

        if (!isBaron(baronId)) revert TokenMustBeBaron();

        uint256 price = s().baronItemCost[itemId];
        if (price == 0) revert InvalidItemId();

        Gang gang = gangOf(baronId);

        // we're using 3:2 exchange rate
        price /= 2;

        _spendGangVaultBalance(uint256(gang), price, price, price, true);

        s().baronItems[gang][itemId] += 1;
    }

    function useBaronItem(
        uint256 baronId,
        uint256 itemId,
        uint256 districtId
    ) external {
        _verifyAuthorized(msg.sender, baronId);

        if (!isBaron(baronId)) revert TokenMustBeBaron();
        if (itemId == ITEM_SEWER) revert InvalidItemId();

        Gang gang = gangOf(baronId);

        _useBaronItem(gang, itemId, districtId);
    }

    /* ------------- protected ------------- */

    function enterGangWar(address owner, uint256 tokenId) public {
        require(msg.sender == gmc());

        Gang gang = gangOf(tokenId);

        _addShares(owner, uint256(gang), 100);
    }

    function exitGangWar(address owner, uint256 tokenId) public {
        require(msg.sender == gmc());

        Gang gang = gangOf(tokenId);

        _removeShares(owner, uint256(gang), 100);
    }

    /* ------------- internal ------------- */

    // function multiCall(bytes[] calldata data) external {
    //     for (uint256 i; i < data.length; ++i) {
    //         (bool success, ) = address(this).delegatecall(data[i]);

    //         if (!success) revert();
    //     }
    // }

    /* ------------- hooks ------------- */

    function _collectBadges(uint256 gangsterId) internal override {
        Gangster storage gangster = s().gangsters[gangsterId];

        uint256 roundId = gangster.roundId;

        if (roundId != 0) {
            uint256 districtId = gangster.location;

            uint256 outcome = gangWarOutcome(districtId, roundId);

            if (outcome != 0) {
                uint256 badgesEarned = gangWarWon(districtId, roundId) ? BADGES_EARNED_VICTORY : BADGES_EARNED_DEFEAT;

                address owner = IERC721(gmc()).ownerOf(gangsterId);

                Offer memory rental = getActiveOffer(gangsterId);

                address renter = rental.renter;

                address badges = s().badges;
                uint256 renterAmount;

                if (renter != address(0)) {
                    renterAmount = (badgesEarned * 100) / rental.renterShare;

                    IERC721(badges).mint(renter, renterAmount);
                }

                IERC721(badges).mint(owner, badgesEarned - renterAmount);

                gangster.roundId = 0;
            }
        }
    }

    function _afterStartRent(
        address owner,
        address renter,
        uint256 tokenId,
        uint256 rentershares
    ) internal override {
        Gang gang = gangOf(tokenId);

        _removeShares(owner, uint256(gang), uint40(rentershares));
        _addShares(renter, uint256(gang), uint40(rentershares));
    }

    function _afterEndRent(
        address owner,
        address renter,
        uint256 tokenId,
        uint256 rentershares
    ) internal override {
        Gang gang = gangOf(tokenId);

        _removeShares(renter, uint256(gang), uint40(rentershares));
        _addShares(owner, uint256(gang), uint40(rentershares));
    }

    function _verifyAuthorized(address owner, uint256 tokenId) internal view override {
        if (!isOwnerOrRenter(owner, tokenId)) revert NotAuthorized();
    }

    function _authorizeUpgrade() internal override onlyOwner {}
}

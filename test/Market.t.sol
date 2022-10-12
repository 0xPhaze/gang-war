// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "futils/futils.sol";
import {TestGangWar} from "./Base.t.sol";
import "/GMCMarket.sol";

contract TestGangWarMarket is TestGangWar {
    using futils for *;

    /* ------------- helper ------------- */

    mapping(address => uint256[3]) storedShares;

    function vaultSharesDiff(address user) private returns (int256[3] memory diff) {
        uint256[3] memory stored = storedShares[user];
        uint256[3] memory shares = vault.getUserShares(user);

        storedShares[user] = shares;

        diff[0] = int256(shares[0]) - int256(stored[0]);
        diff[1] = int256(shares[1]) - int256(stored[1]);
        diff[2] = int256(shares[2]) - int256(stored[2]);
    }

    /* ------------- listOffer ------------- */

    function test_initial() public {}

    function test_listOffer() public {
        vaultSharesDiff(alice);
        vaultSharesDiff(bob);

        Offer[] memory offers = new Offer[](3);
        offers[0].renterShare = 40;

        offers[1].renter = bob;
        offers[1].renterShare = 80;

        offers[2].renterShare = 70;

        vm.prank(alice);
        gmc.listOffer([1, 3, 2].toMemory(), offers);

        assertEq(gmc.getActiveOffer(1).renter, address(0));
        assertEq(gmc.getActiveOffer(1).renterShare, 40);
        assertEq(gmc.getActiveOffer(2).renter, address(0));
        assertEq(gmc.getActiveOffer(2).renterShare, 70);
        assertEq(gmc.getActiveOffer(3).renter, bob);
        assertEq(gmc.getActiveOffer(3).renterShare, 80);

        int256[3] memory sharesDiffAlice = vaultSharesDiff(alice);
        assertEq(sharesDiffAlice[0], 0);
        assertEq(sharesDiffAlice[1], 0);
        assertEq(sharesDiffAlice[2], -80); // direct offer

        int256[3] memory sharesDiffBob = vaultSharesDiff(bob);
        assertEq(sharesDiffBob[0], 0);
        assertEq(sharesDiffBob[1], 0);
        assertEq(sharesDiffBob[2], 80);

        assertTrue(gmc.getListedOffersIds().includes(1));
        assertTrue(gmc.getListedOffersIds().includes(2));
        assertTrue(gmc.getListedOffersIds().includes(3));
    }

    function test_listOffer_revert_NotAuthorized() public {
        Offer[] memory offers = new Offer[](1);

        vm.expectRevert(NotAuthorized.selector);
        gmc.listOffer([1].toMemory(), offers);
    }

    function test_listOffer_revert_InvalidOffer() public {
        Offer[] memory offers = new Offer[](1);
        offers[0].renter = alice;

        vm.prank(alice);
        vm.expectRevert(InvalidOffer.selector);

        gmc.listOffer([1].toMemory(), offers);
    }

    function test_listOffer_revert_InvalidRenterShare() public {
        Offer[] memory offers = new Offer[](1);
        offers[0].renterShare = 29;

        vm.prank(alice);
        vm.expectRevert(InvalidRenterShare.selector);

        gmc.listOffer([1].toMemory(), offers);

        offers[0].renterShare = 101;

        vm.prank(alice);
        vm.expectRevert(InvalidRenterShare.selector);

        gmc.listOffer([1].toMemory(), offers);
    }

    function test_listOffer_revert_AlreadyListed() public {
        test_listOffer();

        Offer[] memory offers = new Offer[](1);
        offers[0].renter = address(0);
        offers[0].renterShare = 40;

        vm.prank(alice);
        vm.expectRevert(AlreadyListed.selector);

        gmc.listOffer([1].toMemory(), offers);
    }

    function test_listOffer_revert_AlreadyListed_accepted() public {
        test_acceptOffer();

        Offer[] memory offers = new Offer[](1);
        offers[0].renter = address(0);
        offers[0].renterShare = 40;

        vm.prank(alice);
        vm.expectRevert(AlreadyListed.selector);

        gmc.listOffer([1].toMemory(), offers);
    }

    function test_listOffer_revert_AlreadyListed_duplicate() public {
        Offer[] memory offers = new Offer[](2);
        offers[0].renterShare = 40;
        offers[1].renterShare = 40;

        vm.prank(alice);
        vm.expectRevert(AlreadyListed.selector);

        gmc.listOffer([1, 1].toMemory(), offers);
    }

    /* ------------- acceptOffer ------------- */

    function test_acceptOffer() public {
        test_listOffer();

        gmc.acceptOffer(1);

        assertEq(gmc.getActiveOffer(1).renter, self);
        assertEq(gmc.getActiveOffer(1).renterShare, 40);
        assertEq(gmc.getRentedIds(self), [1].toMemory());

        int256[3] memory sharesDiff;

        sharesDiff = vaultSharesDiff(self);
        assertEq(sharesDiff[0], 40);
        assertEq(sharesDiff[1], 0);
        assertEq(sharesDiff[2], 0);

        sharesDiff = vaultSharesDiff(alice);
        assertEq(sharesDiff[0], -40);
        assertEq(sharesDiff[1], 0);
        assertEq(sharesDiff[2], 0);
    }

    function test_acceptOffer_revert_InvalidOffer() public {
        vm.expectRevert(InvalidOffer.selector);

        gmc.acceptOffer(10);

        // test_acceptOffer();
    }

    function test_acceptOffer_revert_MinimumTimeDelayNotReached() public {
        test_endRent();

        vm.expectRevert(MinimumTimeDelayNotReached.selector);
        gmc.acceptOffer(2);
    }

    /* ------------- endRent ------------- */

    function test_endRent() public {
        test_acceptOffer();

        gmc.endRent([1].toMemory());

        assertEq(gmc.getActiveOffer(1).renter, address(0));
        assertEq(gmc.getActiveOffer(1).renterShare, 40);
        assertEq(gmc.getRentedIds(self), new uint256[](0));

        int256[3] memory sharesDiff;

        sharesDiff = vaultSharesDiff(self);
        assertEq(sharesDiff[0], -40);
        assertEq(sharesDiff[1], 0);
        assertEq(sharesDiff[2], 0);

        sharesDiff = vaultSharesDiff(alice);
        assertEq(sharesDiff[0], 40);
        assertEq(sharesDiff[1], 0);
        assertEq(sharesDiff[2], 0);
    }

    function test_endRent_byOwner() public {
        test_acceptOffer();

        vm.prank(alice);
        gmc.endRent([1].toMemory());

        assertEq(gmc.getActiveOffer(1).renter, address(0));
        assertEq(gmc.getActiveOffer(1).renterShare, 40);
        assertEq(gmc.getRentedIds(self), new uint256[](0));

        int256[3] memory sharesDiff;

        sharesDiff = vaultSharesDiff(self);
        assertEq(sharesDiff[0], -40);
        assertEq(sharesDiff[1], 0);
        assertEq(sharesDiff[2], 0);

        sharesDiff = vaultSharesDiff(alice);
        assertEq(sharesDiff[0], 40);
        assertEq(sharesDiff[1], 0);
        assertEq(sharesDiff[2], 0);
    }

    function test_endRent_revert_NotAuthorized() public {
        test_acceptOffer();

        vm.prank(bob);
        vm.expectRevert(NotAuthorized.selector);

        gmc.endRent([1].toMemory());
    }

    /* ------------- deleteOffer ------------- */

    function test_deleteOffer() public {
        test_listOffer();

        vm.prank(alice);
        gmc.deleteOffer([1].toMemory());

        assertEq(gmc.getActiveOffer(1).renter, address(0));
        assertEq(gmc.getActiveOffer(1).renterShare, 0);
        assertEq(gmc.getRentedIds(self), new uint256[](0));

        int256[3] memory sharesDiff = vaultSharesDiff(alice);
        assertEq(sharesDiff[0], 0);
        assertEq(sharesDiff[1], 0);
        assertEq(sharesDiff[2], 0);
    }

    function test_deleteOffer_activeRental() public {
        test_acceptOffer();

        vm.prank(alice);
        gmc.deleteOffer([1].toMemory());

        assertEq(gmc.getActiveOffer(1).renter, address(0));
        assertEq(gmc.getActiveOffer(1).renterShare, 0);
        assertEq(gmc.getRentedIds(self), new uint256[](0));

        int256[3] memory sharesDiff;

        sharesDiff = vaultSharesDiff(self);
        assertEq(sharesDiff[0], -40);
        assertEq(sharesDiff[1], 0);
        assertEq(sharesDiff[2], 0);

        sharesDiff = vaultSharesDiff(alice);
        assertEq(sharesDiff[0], 40);
        assertEq(sharesDiff[1], 0);
        assertEq(sharesDiff[2], 0);
    }

    /* ------------- journey ------------- */

    // function test_userJourney() public {
    //     test_acceptOffer();

    //     // console.log(bob);
    //     // console.log(self);
    //     console.log(gmc.renterOf(1));
    //     console.log(gmc.getRentedIds(self)[0]);

    //     vm.prank(alice);
    //     gmc.deleteOffer([1].toMemory());

    //     console.log(gmc.renterOf(1));

    //     // test_listOffer();

    //     // Offer[] memory offers = new Offer[](1);
    //     // offers[0].renterShare = 40;

    //     // vm.prank(alice);
    //     // gmc.listOffer([1].toMemory(), offers);

    //     // offers[1].renter = bob;
    //     // offers[1].renterShare = 80;

    //     vm.prank(bob);
    //     gmc.acceptOffer(1);

    //     // console.log(bob);
    //     console.log(gmc.renterOf(1));
    //     console.log(gmc.getRentedIds(bob)[1]);
    //     // console.log(gmc.getRentedIds(self)[0]);

    //     // console.log(gmc.renterOf(1));
    //     // console.log(gmc.getRentedIds(self)[0]);
    // }

    /* ------------- burn ------------- */

    function test_burn() public {
        test_listOffer();

        vaultSharesDiff(alice);

        gmc.resyncId(address(0), 1);

        assertEq(gmc.getActiveOffer(1).renter, address(0));
        assertEq(gmc.getActiveOffer(1).renterShare, 0);
        assertEq(gmc.getRentedIds(self), new uint256[](0));

        int256[3] memory sharesDiff = vaultSharesDiff(alice);
        assertEq(sharesDiff[0], -100);
        assertEq(sharesDiff[1], 0);
        assertEq(sharesDiff[2], 0);
    }

    function test_burn_deleteOffer() public {
        test_acceptOffer();

        vaultSharesDiff(alice);
        vaultSharesDiff(self);

        gmc.resyncId(address(0), 1);

        assertEq(gmc.getActiveOffer(1).renter, address(0));
        assertEq(gmc.getActiveOffer(1).renterShare, 0);
        assertEq(gmc.getRentedIds(self), new uint256[](0));

        int256[3] memory sharesDiff;

        sharesDiff = vaultSharesDiff(self);
        assertEq(sharesDiff[0], -40);
        assertEq(sharesDiff[1], 0);
        assertEq(sharesDiff[2], 0);

        sharesDiff = vaultSharesDiff(alice);
        assertEq(sharesDiff[0], -60);
        assertEq(sharesDiff[1], 0);
        assertEq(sharesDiff[2], 0);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "futils/futils.sol";
import {TestGangWar} from "./GangWarBase.t.sol";
import "/GMCMarket.sol";

contract TestGangWarMarket is TestGangWar {
    using futils for *;

    /* ------------- upkeep ------------- */

    function test_listOffer() public {
        Offer[] memory offers = new Offer[](2);
        offers[0].renterShare = 40;
        offers[1].renterShare = 80;
        offers[1].renter = bob;

        vm.prank(alice);

        game.listOffer([1, 3].toMemory(), offers);

        assertEq(game.getActiveOffer(1).renter, address(0));
        assertEq(game.getActiveOffer(3).renter, bob);
        assertEq(game.getActiveOffer(1).renterShare, 40);
        assertEq(game.getActiveOffer(3).renterShare, 80);
    }

    function test_listOffer_fail_NotAuthorized() public {
        Offer[] memory offers = new Offer[](1);

        vm.expectRevert(NotAuthorized.selector);
        game.listOffer([1].toMemory(), offers);
    }

    function test_listOffer_fail_InvalidRenterShare() public {
        Offer[] memory offers = new Offer[](1);
        offers[0].renterShare = 29;

        vm.prank(alice);
        vm.expectRevert(InvalidRenterShare.selector);

        game.listOffer([1].toMemory(), offers);

        offers[0].renterShare = 101;

        vm.prank(alice);
        vm.expectRevert(InvalidRenterShare.selector);

        game.listOffer([1].toMemory(), offers);
    }

    // function test_listOffer_fail_ActiveRental() public {
    //     Offer[] memory offers = new Offer[](2);
    //     offers[0].renterShare = 40;

    //     game.listOffer([1, 3].toMemory(), offers);

    //     game.accceptOffer(1);

    //     vm.prank(alice);
    //     vm.expectRevert(ActiveRental.selector);

    //     assertEq(game.getActiveOffer(1).renter, address(0));
    //     assertEq(game.getActiveOffer(3).renter, bob);
    //     assertEq(game.getActiveOffer(1).renterShare, 40);
    //     assertEq(game.getActiveOffer(3).renterShare, 80);
    // }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "futils/futils.sol";
import "./GangWarBase.t.sol";

contract TestGangWarItems is TestGangWar {
    using futils for *;

    /* ------------- purchaseGangWarItem() ------------- */

    function test_purchaseGangWarItem_TokenMustBeBaron() public {
        vm.prank(alice);
        vm.expectRevert(TokenMustBeBaron.selector);

        game.purchaseGangWarItem(GANGSTER_YAKUZA_1, 0);
    }

    function test_purchaseGangWarItem_InvalidItem() public {
        vm.prank(bob);
        vm.expectRevert(InvalidItemId.selector);

        game.purchaseGangWarItem(BARON_YAKUZA_1, 100);
    }

    function test_purchaseGangWarItem_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);

        game.purchaseGangWarItem(BARON_YAKUZA_1, 100);
    }

    function test_purchaseGangWarItem_ArithmeticError() public {
        game.setItemCost(ITEM_BLITZ, 100e18);

        skip(100);

        vm.prank(bob);
        vm.expectRevert(stdError.arithmeticError);

        game.purchaseGangWarItem(BARON_YAKUZA_1, ITEM_BLITZ);
    }

    function test_purchaseGangWarItem() public {
        game.setItemCost(ITEM_BLITZ, 100e18);

        game.setYield(uint256(Gang.YAKUZA), 0, 100e10);
        game.setYield(uint256(Gang.YAKUZA), 1, 100e10);
        game.setYield(uint256(Gang.YAKUZA), 2, 100e10);

        skip(100);

        vm.prank(address(0));
        uint256[3] memory balancesBefore = game.getGangVaultBalance(0);

        vm.prank(bob);
        game.purchaseGangWarItem(BARON_YAKUZA_1, ITEM_BLITZ);

        vm.prank(address(0));
        uint256[3] memory balancesAfter = game.getGangVaultBalance(0);

        assertEq(balancesBefore[0] - balancesAfter[0], 100e18);
        assertEq(balancesBefore[1] - balancesAfter[1], 100e18);
        assertEq(balancesBefore[2] - balancesAfter[2], 100e18);
    }
}

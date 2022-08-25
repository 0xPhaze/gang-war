// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "futils/futils.sol";
import "./Base.t.sol";

contract TestBaronItems is TestGangWar {
    using futils for *;

    /* ------------- purchaseBaronItem() ------------- */

    function test_purchaseBaronItem_TokenMustBeBaron() public {
        vm.prank(alice);
        vm.expectRevert(TokenMustBeBaron.selector);

        game.purchaseBaronItem(GANGSTER_YAKUZA_1, 0);
    }

    function test_purchaseBaronItem_InvalidItem() public {
        vm.prank(bob);
        vm.expectRevert(InvalidItemId.selector);

        game.purchaseBaronItem(BARON_YAKUZA_1, 100_000);
    }

    function test_purchaseBaronItem_NotAuthorized() public {
        vm.expectRevert(NotAuthorized.selector);

        game.purchaseBaronItem(BARON_YAKUZA_1, ITEM_BLITZ);
    }

    function test_purchaseBaronItem_ArithmeticError() public {
        game.setBaronItemCost(ITEM_BLITZ, 100e18);

        skip(100);

        vm.prank(bob);
        vm.expectRevert(stdError.arithmeticError);

        game.purchaseBaronItem(BARON_YAKUZA_1, ITEM_BLITZ);
    }

    function test_purchaseBaronItem() public {
        // need yield on all gang tokens
        game.setYield(uint256(Gang.YAKUZA), 0, 100e10);
        game.setYield(uint256(Gang.YAKUZA), 1, 100e10);
        game.setYield(uint256(Gang.YAKUZA), 2, 100e10);

        skip(100 days);

        uint256[3] memory balancesBefore;
        uint256[3] memory balancesAfter;

        uint256[] memory itemCosts = [
            uint256(3_000_000e18), // ITEM_SEWER
            3_000_000e18, // ITEM_BLITZ
            2_250_000e18, // ITEM_BARRICADES
            2_250_000e18, // ITEM_SMOKE
            1_500_000e18 // ITEM_911
        ].toMemory();

        for (uint256 i; i < NUM_BARON_ITEMS; i++) {
            vm.prank(address(0));
            balancesBefore = game.getGangVaultBalance(0);

            vm.prank(bob);
            game.purchaseBaronItem(BARON_YAKUZA_1, i);

            vm.prank(address(0));
            balancesAfter = game.getGangVaultBalance(0);

            assertEq(balancesBefore[0] - balancesAfter[0], itemCosts[i] / 2);
            assertEq(balancesBefore[1] - balancesAfter[1], itemCosts[i] / 2);
            assertEq(balancesBefore[2] - balancesAfter[2], itemCosts[i] / 2);
        }
    }

    function test_useBaronItem() public {
        game.setYield(uint256(Gang.YAKUZA), 0, 100e10);
        game.setYield(uint256(Gang.YAKUZA), 1, 100e10);
        game.setYield(uint256(Gang.YAKUZA), 2, 100e10);

        skip(100 days);

        vm.startPrank(bob);
        for (uint256 i; i < NUM_BARON_ITEMS * 2; i++) {
            game.purchaseBaronItem(BARON_YAKUZA_1, i % NUM_BARON_ITEMS);
        }

        uint256[] memory itemBalances = game.getBaronItemBalances(Gang.YAKUZA);
        for (uint256 i; i < itemBalances.length; i++) {
            assertEq(itemBalances[i], 2);
        }

        for (uint256 i; i < NUM_BARON_ITEMS; i++) {
            if (i != ITEM_SEWER) {
                game.useBaronItem(BARON_YAKUZA_1, i, DISTRICT_CARTEL_1);

                assertEq((game.getDistrict(DISTRICT_CARTEL_1).activeItems & (1 << i)) >> i, 1);
            }
        }

        // use sewer item in an attack
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CYBERP_1, BARON_YAKUZA_1, true);
        assertEq((game.getDistrict(DISTRICT_CYBERP_1).activeItems & (1 << ITEM_SEWER)) >> ITEM_SEWER, 1);

        itemBalances = game.getBaronItemBalances(Gang.YAKUZA);

        for (uint256 i; i < itemBalances.length; i++) {
            assertEq(itemBalances[i], 1);
        }
    }

    function test_useBaronItem_fail_ArithmeticError() public {
        for (uint256 i; i < NUM_BARON_ITEMS; i++) {
            if (i != ITEM_SEWER) {
                vm.prank(bob);
                vm.expectRevert(stdError.arithmeticError);

                game.useBaronItem(BARON_YAKUZA_1, i, DISTRICT_CARTEL_1);
            }
        }
    }
}

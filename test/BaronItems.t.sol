// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "futils/futils.sol";
import "./Base.t.sol";

contract TestBaronItems is TestGangWar {
    using futils for *;

    mapping(Gang => uint256[]) storedBalances;

    function itemBalancesDiff(Gang gang) private returns (int256[] memory diff) {
        uint256[] memory stored = storedBalances[gang];
        uint256[] memory balances = game.getBaronItemBalances(uint256(gang));

        storedBalances[gang] = balances;

        diff = new int256[](NUM_BARON_ITEMS);
        if (stored.length == 0) stored = new uint256[](NUM_BARON_ITEMS);

        for (uint256 i; i < NUM_BARON_ITEMS; ++i) {
            diff[i] = int256(balances[i]) - int256(stored[i]);
        }
    }

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

    function test_purchaseBaronItem(uint256 id) private {
        uint256[] memory itemCosts = [
            uint256(3_000_000e18), // ITEM_SEWER
            3_000_000e18, // ITEM_BLITZ
            2_250_000e18, // ITEM_BARRICADES
            2_250_000e18, // ITEM_SMOKE
            1_500_000e18 // ITEM_911
        ].toMemory();

        uint256[3] memory balancesBefore = vault.getGangVaultBalance(0);

        vm.prank(bob);
        game.purchaseBaronItem(BARON_YAKUZA_1, id);

        // skip(1 days);

        vm.prank(bob);
        game.purchaseBaronItem(BARON_CARTEL_1, id);

        uint256[3] memory balancesAfter = vault.getGangVaultBalance(0);

        assertEq(balancesBefore[0] - balancesAfter[0], itemCosts[id] / 2);
        assertEq(balancesBefore[1] - balancesAfter[1], itemCosts[id] / 2);
        assertEq(balancesBefore[2] - balancesAfter[2], itemCosts[id] / 2);
    }

    function test_purchaseBaronItems() public {
        // need yield on all gang tokens
        vault.setYield(uint256(Gang.YAKUZA), [uint256(1e8), uint256(1e8), uint256(1e8)]);
        vault.setYield(uint256(Gang.CARTEL), [uint256(1e8), uint256(1e8), uint256(1e8)]);

        skip(100 days);

        for (uint256 i; i < NUM_BARON_ITEMS; i++) {
            test_purchaseBaronItem(i);
        }

        int256[] memory diffYakuza = itemBalancesDiff(Gang.YAKUZA);
        int256[] memory diffCartel = itemBalancesDiff(Gang.CARTEL);

        for (uint256 i; i < NUM_BARON_ITEMS; i++) {
            assertEq(diffYakuza[i], 1);
            assertEq(diffCartel[i], 1);
        }
    }

    // function test_useBaronItemSewer() public {
    //     test_purchaseBaronItems();

    //     // use sewer item in an attack
    //     vm.prank(bob);
    //     game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CYBERP_1, BARON_YAKUZA_1, true);

    //     assertEq((game.getDistrict(DISTRICT_CYBERP_1).activeItems & (1 << ITEM_SEWER)) >> ITEM_SEWER, 1);
    //     assertEq(itemBalancesDiff(Gang.YAKUZA)[ITEM_SEWER], -1);
    // }

    // function test_useBaronItemSewer_noUsage() public {
    //     test_purchaseBaronItems();

    //     vm.startPrank(bob);
    //     game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

    //     game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_2, true);

    //     int256[] memory diff = itemBalancesDiff(Gang.YAKUZA);

    //     for (uint256 i; i < NUM_BARON_ITEMS; i++) {
    //         assertEq(diff[i], 0);
    //     }
    // }

    // function test_useBaronItemBlitz() public {
    //     test_purchaseBaronItems();

    //     vm.startPrank(bob);
    //     game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

    //     int256 stateCountdown = game.getDistrict(DISTRICT_CARTEL_1).stateCountdown;

    //     game.useBaronItem(BARON_YAKUZA_1, ITEM_BLITZ, DISTRICT_CARTEL_1);

    //     assertEq(
    //         game.getDistrict(DISTRICT_CARTEL_1).stateCountdown,
    //         (stateCountdown * int256(100 - ITEM_BLITZ_TIME_REDUCTION)) / 100
    //     );
    //     assertEq((game.getDistrict(DISTRICT_CARTEL_1).activeItems & (1 << ITEM_BLITZ)) >> ITEM_BLITZ, 1);
    //     assertEq(itemBalancesDiff(Gang.YAKUZA)[ITEM_BLITZ], -1);
    // }

    // function test_useBaronItemSmoke() public {
    //     test_purchaseBaronItems();

    //     vm.startPrank(bob);

    //     vm.expectRevert(InvalidItemUsage.selector);
    //     game.useBaronItem(BARON_YAKUZA_1, ITEM_SMOKE, DISTRICT_CARTEL_1);

    //     game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

    //     game.useBaronItem(BARON_YAKUZA_1, ITEM_SMOKE, DISTRICT_CARTEL_1);

    //     // // @note need attack increase validation
    //     // assertEq((game.getDistrict(DISTRICT_CARTEL_1).activeItems & (1 << ITEM_SMOKE)) >> ITEM_SMOKE, 1);
    //     // assertEq(itemBalancesDiff(Gang.YAKUZA)[ITEM_SMOKE], -1);
    // }

    // function test_useBaronItemBarricades() public {
    //     test_purchaseBaronItems();

    //     vm.startPrank(bob);

    //     // no attack declared
    //     vm.expectRevert(InvalidItemUsage.selector);
    //     game.useBaronItem(BARON_CARTEL_1, ITEM_BARRICADES, DISTRICT_CARTEL_1);

    //     // using for attacking gang
    //     vm.expectRevert(InvalidItemUsage.selector);
    //     game.useBaronItem(BARON_YAKUZA_1, ITEM_BARRICADES, DISTRICT_CARTEL_1);

    //     // first attack district
    //     game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

    //     game.useBaronItem(BARON_CARTEL_1, ITEM_BARRICADES, DISTRICT_CARTEL_1);

    //     // // @note need defense increase validation
    //     // assertEq((game.getDistrict(DISTRICT_CARTEL_1).activeItems & (1 << ITEM_BARRICADES)) >> ITEM_BARRICADES, 1);
    //     // assertEq(itemBalancesDiff(Gang.CARTEL)[ITEM_BARRICADES], -1);
    // }

    // function test_useBaronItem911() public {
    //     test_purchaseBaronItems();

    //     vm.startPrank(bob);

    //     game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

    //     game.useBaronItem(BARON_YAKUZA_1, ITEM_911, DISTRICT_CARTEL_1);

    //     assertEq(itemBalancesDiff(Gang.YAKUZA)[ITEM_911], -1);

    //     MockVRFCoordinator(coordinator).fulfillLatestRequest();

    //     uint256 lockedDistrict = 999;
    //     for (uint256 i; i < 21; i++) {
    //         if (game.getDistrict(i).state == DISTRICT_STATE.LOCKUP) {
    //             lockedDistrict = i;
    //         }
    //     }

    //     assertTrue(lockedDistrict != 999);

    //     // @note need rest
    // }

    // function test_useBaronItem_revert_ArithmeticError() public {
    //     vm.startPrank(bob);
    //     game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

    //     // gang hasn't purchased any items yet
    //     vm.expectRevert(stdError.arithmeticError);

    //     game.useBaronItem(BARON_CARTEL_1, ITEM_BARRICADES, DISTRICT_CARTEL_1);
    // }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "futils/futils.sol";
import {TestGangWar} from "./Base.t.sol";
import "/GMCMarket.sol";

contract TestMiceExchange is TestGangWar {
    using futils for *;

    uint256 initialBalance = 100_000e18;

    function setUp() public override {
        super.setUp();

        tokens[0].mint(alice, initialBalance);
        tokens[1].mint(alice, initialBalance);
        tokens[2].mint(alice, initialBalance);
        badges.mint(alice, initialBalance);

        address(mice).balanceDiff(alice);
        address(badges).balanceDiff(alice);
        address(tokens[0]).balanceDiff(alice);
        address(tokens[1]).balanceDiff(alice);
        address(tokens[2]).balanceDiff(alice);
    }

    /* ------------- exchange ------------- */

    function test_exchange(uint256 choice, uint256 amount) public {
        choice = bound(choice, 0, 2);
        amount = bound(amount, 0, 1e40);

        vm.prank(alice);

        if (amount > initialBalance) {
            vm.expectRevert(stdError.arithmeticError);

            mice.exchange(choice, amount);
        } else {
            mice.exchange(choice, amount);

            assertEq(address(mice).balanceDiff(alice), int256(amount) / 3);
            assertEq(address(tokens[(choice + 0) % 3]).balanceDiff(alice), -int256(amount));
            assertEq(address(tokens[(choice + 1) % 3]).balanceDiff(alice), 0);
            assertEq(address(tokens[(choice + 2) % 3]).balanceDiff(alice), 0);
        }
    }

    function test_exchange2(uint256 choice, uint256 amount) public {
        choice = bound(choice, 0, 2);
        amount = bound(amount, 0, 1e40);

        vm.prank(alice);

        if (amount > initialBalance) {
            vm.expectRevert(stdError.arithmeticError);

            mice.exchange2(choice, amount);
        } else {
            mice.exchange2(choice, amount);

            assertEq(address(mice).balanceDiff(alice), int256(amount));
            assertEq(address(tokens[(choice + 0) % 3]).balanceDiff(alice), 0);
            assertEq(address(tokens[(choice + 1) % 3]).balanceDiff(alice), -int256(amount));
            assertEq(address(tokens[(choice + 2) % 3]).balanceDiff(alice), -int256(amount));
        }
    }

    function test_exchange3(uint256 choice, uint256 amount) public {
        choice = bound(choice, 0, 2);
        amount = bound(amount, 0, 1e40);

        vm.prank(alice);

        if (amount > initialBalance) {
            vm.expectRevert(stdError.arithmeticError);

            mice.exchange3(amount);
        } else {
            mice.exchange3(amount);

            assertEq(address(mice).balanceDiff(alice), int256(amount * 2));
            assertEq(address(tokens[(choice + 0) % 3]).balanceDiff(alice), -int256(amount));
            assertEq(address(tokens[(choice + 1) % 3]).balanceDiff(alice), -int256(amount));
            assertEq(address(tokens[(choice + 2) % 3]).balanceDiff(alice), -int256(amount));
        }
    }

    function test_exchangeBadges(uint256 amount) public {
        amount = bound(amount, 0, 1e40);

        vm.prank(alice);

        if (amount > initialBalance) {
            vm.expectRevert(stdError.arithmeticError);

            mice.exchangeBadges(amount);
        } else {
            mice.exchangeBadges(amount);

            assertEq(address(mice).balanceDiff(alice), int256(amount * 25));
            assertEq(address(badges).balanceDiff(alice), -int256(amount));
        }
    }
}

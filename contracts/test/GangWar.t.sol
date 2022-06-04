// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "solmate/test/utils/mocks/MockERC721.sol";

import "../lib/ArrayUtils.sol";

import "../GangWar.sol";

error NonexistentToken();

contract TestGangWar is Test {
    using ArrayUtils for *;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    GangWar game;
    MockERC721 gmc;

    function setUp() public {
        game = new GangWar();
        gmc = new MockERC721("GMC", "GMC");
    }

    /* ------------- Disabled() ------------- */

    function test_s() public {
        gmc.mint(alice, 1);

        game.joinGangAttack(1, 2, [1].toMemory());
    }
}

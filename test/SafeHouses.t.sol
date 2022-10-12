// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestGangWar} from "./Base.t.sol";

import "futils/futils.sol";
import "forge-std/Test.sol";

contract TestSafeHouses is TestGangWar {
    using futils for *;

    function test_setUp() public {
        for (uint256 i; i < 21; i++) {
            assertEq(safeHouses.districtToGang(1 + i), uint8(game.getDistrict(i).token));
        }
    }

    /* ------------- claim ------------- */

    function test_claim(uint256 choice, uint256 amount) public {}
}

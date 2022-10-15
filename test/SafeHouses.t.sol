// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestGangWar} from "./Base.t.sol";

import "futils/futils.sol";
import "forge-std/Test.sol";

contract TestSafeHouses is TestGangWar {
    using futils for *;

    // function test_setUp() public {
    //     for (uint256 i; i < 21; i++) {
    //         assertEq(safeHouses.districtToGang(1 + i), uint8(game.getDistrict(i).token));
    //     }
    // }

    /* ------------- claim ------------- */

    function test_claim() public {
        // goudaRoot.mint(self, 100e18);
        // goudaRoot.approve(address(goudaTunnel), type(uint256).max);
        // address(goudaRoot).balanceDiff(self);
        // goudaTunnel.lock(self, 50e18);
        // assertEq(address(goudaRoot).balanceDiff(self), -50e18);
        // assertEq(address(gouda).balanceDiff(self), 50e18);
        // console.log(address(troupe));
        for (uint256 i; i < 10; i++) {
            troupe.mint(self, i);
        }

        uint256[][] memory ids = new uint256[][](2);
        ids[0] = 0.range(5);
        ids[1] = 5.range(10);

        troupe.setApprovalForAll(address(safeHouseClaim), true);

        safeHouseClaim.claim(ids);

        assertEq(safeHouses.ownerOf(1), self);
        assertEq(safeHouses.ownerOf(2), self);
    }
}

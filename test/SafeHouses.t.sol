// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestGangWar} from "./Base.t.sol";

import "../src/tokens/SafeHouses.sol";
import "./mocks/MockVRFCoordinator.sol";

import "futils/futils.sol";
import "forge-std/Test.sol";

contract TestSafeHouses is TestGangWar {
    using futils for *;

    function setUp() public override {
        super.setUp();

        bytes32 AUTHORITY = keccak256("AUTHORITY");
        mice.grantRole(AUTHORITY, self);

        mice.approve(address(safeHouses), type(uint256).max);
        badges.approve(address(safeHouses), type(uint256).max);
    }

    // function test_setUp() public {
    //     for (uint256 i; i < 21; i++) {
    //         assertEq(safeHouses.districtToGang(1 + i), uint8(game.getDistrict(i).token));
    //     }
    // }
    /* ------------- mint ------------- */

    function test_mint() public {
        uint256 supply = safeHouses.totalSupply();

        mice.mint(self, safeHouses.MINT_MICE_COST());
        badges.mint(self, safeHouses.MINT_BADGES_COST());

        safeHouses.mint(1);

        assertEq(mice.balanceOf(self), 0);
        assertEq(safeHouses.ownerOf(supply + 1), self);
        assertEq(safeHouses.totalSupply(), supply + 1);
    }

    function test_mint(uint256 quantity) public {
        quantity = bound(quantity, 1, 10);

        mice.mint(self, quantity * safeHouses.MINT_MICE_COST());
        badges.mint(self, quantity * safeHouses.MINT_BADGES_COST());

        uint256 supply = safeHouses.totalSupply();

        safeHouses.mint(quantity);

        assertEq(mice.balanceOf(self), 0);
        assertEq(safeHouses.totalSupply(), supply + quantity);
        for (uint256 i; i < quantity; i++) {
            assertEq(safeHouses.ownerOf(supply + i + 1), self);
            assertEq(safeHouses.getSafeHouseData(supply + i + 1).level, 1);
            assertEq(safeHouses.getSafeHouseData(supply + i + 1).lastClaim, block.timestamp);
            assertEq(safeHouses.getSafeHouseData(supply + i + 1).districtId, 0);
        }
    }

    function test_mint_revert_arithmetic() public {
        vm.expectRevert(stdError.arithmeticError);
        safeHouses.mint(1);
    }

    function test_mint_zero() public {
        uint256 supply = safeHouses.totalSupply();

        vm.expectRevert(InvalidQuantity.selector);
        safeHouses.mint(0);

        assertEq(supply, 0);
    }

    /* ------------- reveal ------------- */

    function test_reveal() public {
        uint256 supply = safeHouses.totalSupply();

        test_mint(5);

        MockVRFCoordinator(coordinator).fulfillLatestRequests();

        for (uint256 i; i < 5; i++) {
            assertGt(safeHouses.getSafeHouseData(supply + i + 1).districtId, 0);
        }
    }

    /* ------------- claimReward ------------- */

    function test_claimReward() public {
        test_reveal();

        address token = safeHouses.tokenAddress(safeHouses.districtToGang(safeHouses.getDistrictId(1)));

        address(gouda).balanceDiff(self);
        address(token).balanceDiff(self);

        skip(2 days);

        safeHouses.claimReward([1, 1].toMemory());
        assertEq(address(token).balanceDiff(self), 2 * int256(safeHouses.tokenDailyRate(1)));
        assertEq(address(gouda).balanceDiff(self), 2 * int256(safeHouses.goudaDailyRate(1)));
    }

    function test_claimReward_multiple() public {
        test_reveal();

        address token1 = safeHouses.tokenAddress(safeHouses.districtToGang(safeHouses.getDistrictId(1)));
        address token2 = safeHouses.tokenAddress(safeHouses.districtToGang(safeHouses.getDistrictId(2)));

        address(gouda).balanceDiff(self);
        address(token1).balanceDiff(self);
        address(token2).balanceDiff(self);

        skip(2 days);

        safeHouses.claimReward([1, 2].toMemory());

        assertEq(address(token1).balanceDiff(self), 2 * int256(safeHouses.tokenDailyRate(1)));
        assertEq(address(token2).balanceDiff(self), 2 * int256(safeHouses.tokenDailyRate(1)));
        assertEq(address(gouda).balanceDiff(self), 4 * int256(safeHouses.goudaDailyRate(1)));
    }

    /* ------------- levelUp ------------- */

    function test_levelUp() public {
        test_reveal();

        mice.mint(self, 2 * safeHouses.LEVEL_2_MICE_COST());
        badges.mint(self, 2 * safeHouses.LEVEL_2_BADGES_COST());

        safeHouses.levelUp([1, 4].toMemory());

        assertEq(safeHouses.ownerOf(1), self);
        assertEq(safeHouses.ownerOf(4), self);
        assertEq(safeHouses.getSafeHouseData(1).level, 2);
        assertEq(safeHouses.getSafeHouseData(4).level, 2);

        assertEq(mice.balanceOf(self), 0);
        assertEq(badges.balanceOf(self), 0);
    }

    function test_levelUp2() public {
        test_reveal();

        mice.mint(self, 2 * (safeHouses.LEVEL_2_MICE_COST() + safeHouses.LEVEL_3_MICE_COST()));
        badges.mint(self, 2 * (safeHouses.LEVEL_2_BADGES_COST() + safeHouses.LEVEL_3_BADGES_COST()));

        safeHouses.levelUp([1, 4, 4, 1].toMemory());

        assertEq(safeHouses.ownerOf(1), self);
        assertEq(safeHouses.ownerOf(4), self);
        assertEq(safeHouses.getSafeHouseData(1).level, 3);
        assertEq(safeHouses.getSafeHouseData(4).level, 3);

        assertEq(mice.balanceOf(self), 0);
        assertEq(badges.balanceOf(self), 0);
    }

    function test_levelUp_revert() public {
        test_reveal();

        mice.mint(self, 2 * (safeHouses.LEVEL_2_MICE_COST() + safeHouses.LEVEL_3_MICE_COST()));
        badges.mint(self, 2 * (safeHouses.LEVEL_2_BADGES_COST() + safeHouses.LEVEL_3_BADGES_COST()));

        vm.expectRevert(ExceedsLimit.selector);

        safeHouses.levelUp([4, 4, 4].toMemory());
    }

    /* ------------- levelUp_claim ------------- */

    function test_levelUp_claim() public {
        test_levelUp();

        address token1 = safeHouses.tokenAddress(safeHouses.districtToGang(safeHouses.getDistrictId(1)));
        address token2 = safeHouses.tokenAddress(safeHouses.districtToGang(safeHouses.getDistrictId(4)));

        token1.balanceDiff(self);
        token2.balanceDiff(self);

        skip(2 days);

        safeHouses.claimReward([1, 4, 4].toMemory());

        assertEq(token1.balanceDiff(self), 2 * int256(safeHouses.tokenDailyRate(2)));
        assertEq(token2.balanceDiff(self), 2 * int256(safeHouses.tokenDailyRate(2)));
        assertEq(address(gouda).balanceDiff(self), 4 * int256(safeHouses.goudaDailyRate(2)));
    }

    function test_levelUp2_claim() public {
        test_levelUp2();

        address token1 = safeHouses.tokenAddress(safeHouses.districtToGang(safeHouses.getDistrictId(1)));
        address token2 = safeHouses.tokenAddress(safeHouses.districtToGang(safeHouses.getDistrictId(4)));

        token1.balanceDiff(self);
        token2.balanceDiff(self);

        skip(2 days);

        safeHouses.claimReward([1, 4].toMemory());

        assertEq(token1.balanceDiff(self), 2 * int256(safeHouses.tokenDailyRate(3)));
        assertEq(token2.balanceDiff(self), 2 * int256(safeHouses.tokenDailyRate(3)));
        assertEq(address(gouda).balanceDiff(self), 4 * int256(safeHouses.goudaDailyRate(3)));
    }

    /* ------------- claim ------------- */

    function test_claim_troupe() public {
        for (uint256 i; i < 10; i++) {
            troupe.mint(self, i);
        }

        uint256[][] memory ids = new uint256[][](2);
        ids[0] = 0.range(5);
        ids[1] = 5.range(10);

        troupe.setApprovalForAll(address(safeHouseClaim), true);

        safeHouseClaim.claim(ids);

        assertEq(troupe.ownerOf(1), safeHouseClaim.burnAddress());
        assertEq(safeHouses.ownerOf(1), self);
        assertEq(safeHouses.ownerOf(2), self);
    }

    function test_claim_genesis() public {
        for (uint256 i; i < 10; i++) {
            genesis.mint(self, i);
        }

        safeHouseClaim.claimGenesis([1, 3, 4].toMemory());

        assertEq(safeHouses.ownerOf(1), self);
        assertEq(safeHouses.ownerOf(2), self);
        assertEq(safeHouses.ownerOf(3), self);
    }
}

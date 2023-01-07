// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestGangWar} from "./Base.t.sol";

import "../src/tokens/Vehicles.sol";
import "./mocks/MockVRFCoordinator.sol";

import "futils/futils.sol";
import "forge-std/Test.sol";

contract TestVehicles is TestGangWar {
    using futils for *;

    function setUp() public override {
        super.setUp();

        mice.grantRole(keccak256("AUTHORITY"), self);

        mice.approve(address(safeHouses), type(uint256).max);
        badges.approve(address(safeHouses), type(uint256).max);

        safeHouses.airdrop([self].toMemory(), 5);
    }

    function test_setUp() public {
        assertEq(safeHouses.ownerOf(1), self);
        assertEq(safeHouses.ownerOf(2), self);
        assertEq(safeHouses.ownerOf(3), self);
        assertEq(safeHouses.ownerOf(4), self);
        assertEq(safeHouses.ownerOf(5), self);
    }

    /* ------------- mint ------------- */

    function test_mint() public {
        vehicles.mint(1.range(2));
        vehicles.mint(2.range(4));
        vehicles.mint(4.range(6));

        assertEq(vehicles.ownerOf(1), self);
        assertEq(vehicles.ownerOf(2), self);
        assertEq(vehicles.ownerOf(3), self);
        assertEq(vehicles.ownerOf(4), self);
        assertEq(vehicles.ownerOf(5), self);

        assertEq(vehicles.getLevel(1), 1);
        assertEq(vehicles.getLevel(2), 1);
        assertEq(vehicles.getLevel(3), 1);
        assertEq(vehicles.getLevel(4), 1);
        assertEq(vehicles.getLevel(5), 1);

        assertEq(vehicles.getMultiplier(1), 3);
        assertEq(vehicles.getMultiplier(2), 3);
        assertEq(vehicles.getMultiplier(3), 3);
        assertEq(vehicles.getMultiplier(4), 3);
        assertEq(vehicles.getMultiplier(5), 3);

        assertEq(vehicles.getVehicleData(1).districtId, 0);
        assertEq(vehicles.getVehicleData(2).districtId, 0);
        assertEq(vehicles.getVehicleData(3).districtId, 0);
        assertEq(vehicles.getVehicleData(4).districtId, 0);
        assertEq(vehicles.getVehicleData(5).districtId, 0);

        assertEq(vehicles.totalSupply(), 5);
    }

    function test_mint_revert_InvalidQuantity() public {
        vm.expectRevert(InvalidQuantity.selector);
        vehicles.mint(new uint256[](0));
    }

    function test_mint_revert_AlreadyClaimed() public {
        vm.expectRevert(AlreadyClaimed.selector);
        vehicles.mint([1, 1].toMemory());

        vehicles.mint([1].toMemory());

        vm.expectRevert(AlreadyClaimed.selector);
        vehicles.mint([1].toMemory());
    }

    function test_mint_revert_ExceedsLimit() public {
        vehicles.airdrop(self.repeat(vehicles.MAX_SUPPLY_BIKES()), 1);

        vm.expectRevert(ExceedsLimit.selector);
        vehicles.airdrop(self.repeat(1), 1);

        vehicles.airdrop(self.repeat(vehicles.MAX_SUPPLY_VANS()), 2);

        vm.expectRevert(ExceedsLimit.selector);
        vehicles.airdrop(self.repeat(1), 2);

        vehicles.airdrop(self.repeat(vehicles.MAX_SUPPLY_HELICOPTERS()), 3);

        vm.expectRevert(ExceedsLimit.selector);
        vehicles.airdrop(self.repeat(1), 3);
    }

    function test_mint_vans() public {
        mice.mint(self, 1e40);
        badges.mint(self, 1e40);

        safeHouses.mint(5);

        MockVRFCoordinator(coordinator).fulfillLatestRequests();

        safeHouses.levelUp(2.range(6));
        safeHouses.levelUp(4.range(6));

        vehicles.mint(1.range(6));

        MockVRFCoordinator(coordinator).fulfillLatestRequests();

        assertEq(vehicles.getLevel(1), 1);
        assertEq(vehicles.getLevel(2), 2);
        assertEq(vehicles.getLevel(3), 2);
        assertEq(vehicles.getLevel(4), 3);
        assertEq(vehicles.getLevel(5), 3);

        assertEq(vehicles.getMultiplier(1), 3);
        assertEq(vehicles.getMultiplier(2), 7);
        assertEq(vehicles.getMultiplier(3), 7);
        assertEq(vehicles.getMultiplier(4), 14);
        assertEq(vehicles.getMultiplier(5), 14);

        assertGt(vehicles.getVehicleData(1).districtId, 0);
        assertGt(vehicles.getVehicleData(2).districtId, 0);
        assertGt(vehicles.getVehicleData(3).districtId, 0);
        assertGt(vehicles.getVehicleData(4).districtId, 0);
        assertGt(vehicles.getVehicleData(5).districtId, 0);
    }

    function test_mint_revert_NotAuthorized() public {
        mice.mint(self, 1e40);
        badges.mint(self, 1e40);

        safeHouses.mint(5);

        MockVRFCoordinator(coordinator).fulfillLatestRequests();

        vm.prank(alice);
        vm.expectRevert(NotAuthorized.selector);

        vehicles.mint([1].toMemory());
    }

    /* ------------- equip ------------- */

    function test_equip() public {
        test_mint_vans();

        gmc.resyncId(self, 101);
        gmc.resyncId(self, 102);
        gmc.resyncId(self, 103);
        gmc.resyncId(self, 104);
        gmc.resyncId(self, 105);
        gmc.resyncId(self, 106);

        vehicles.equipGangster([3].toMemory(), [102].toMemory());

        assertEq(vehicles.vehicleToGangsterId(3), 102);
        assertEq(vehicles.gangsterToVehicleId(102), 3);

        assertEq(vehicles.getMultiplier(3), 7);
        assertEq(vehicles.getGangsterMultiplier(102), 7);

        vehicles.equipGangster([3, 1].toMemory(), [102, 102].toMemory());

        assertEq(vehicles.vehicleToGangsterId(1), 102);
        assertEq(vehicles.vehicleToGangsterId(3), 0);
        assertEq(vehicles.gangsterToVehicleId(102), 1);

        assertEq(vehicles.getMultiplier(1), 3);
        assertEq(vehicles.getMultiplier(3), 7);
        assertEq(vehicles.getGangsterMultiplier(102), 3);

        vehicles.equipGangster([4, 1, 3, 2, 5, 4].toMemory(), [103, 0, 102, 105, 103, 106].toMemory());

        assertEq(vehicles.vehicleToGangsterId(1), 0);
        assertEq(vehicles.vehicleToGangsterId(3), 102);
        assertEq(vehicles.gangsterToVehicleId(102), 3);
        assertEq(vehicles.vehicleToGangsterId(4), 106);
        assertEq(vehicles.gangsterToVehicleId(106), 4);
        assertEq(vehicles.vehicleToGangsterId(2), 105);
        assertEq(vehicles.gangsterToVehicleId(105), 2);
        assertEq(vehicles.vehicleToGangsterId(5), 103);
        assertEq(vehicles.gangsterToVehicleId(103), 5);
    }

    function test_equip_revert_NotAuthorized() public {
        test_equip();

        vm.prank(alice);
        vm.expectRevert(NotAuthorized.selector);

        vehicles.equipGangster([3].toMemory(), [102].toMemory());

        vm.prank(alice);
        vm.expectRevert(NotAuthorized.selector);

        vehicles.equipGangster([3].toMemory(), [3].toMemory());

        vehicles.transferFrom(self, alice, 3);

        // Alice is allowed to unequip
        vm.prank(alice);
        vehicles.equipGangster([3].toMemory(), [0].toMemory());

        vm.prank(alice);
        vm.expectRevert(NotAuthorized.selector);

        vehicles.equipGangster([3].toMemory(), [102].toMemory());

        vm.prank(alice);
        vehicles.equipGangster([3].toMemory(), [3].toMemory());
    }

    function test_gangsterMultiplier() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        vm.prank(alice);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());

        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_2, false);

        vm.prank(alice);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, [GANGSTER_YAKUZA_2].toMemory());

        // District memory district = game.getDistrict(DISTRICT_CARTEL_1);

        // assertEq(district.roundId, 1);
        // assertEq(district.attackers, Gang.YAKUZA);
        // assertEq(district.occupants, Gang.CARTEL);
        // assertEq(district.attackForces, 1);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestGangWar, District, Gangster, Gang} from "./Base.t.sol";

// import {Vehicles} from "../src/tokens/Vehicles.sol";
import {Vehicles} from "../src/tokens/Vehicles.sol";
import "../src/tokens/Vehicles.sol";
import {MockVRFCoordinator} from "./mocks/MockVRFCoordinator.sol";

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
        // vehicles.airdrop(self.repeat(vehicles.MAX_SUPPLY_BIKES()), 1.range(vehicles.MAX_SUPPLY_BIKES()), 1);

        // vm.expectRevert(ExceedsLimit.selector);
        // vehicles.airdrop(self.repeat(1), [vehicles.MAX_SUPPLY_VANS()].toMemory(), 1);

        // vehicles.airdrop(self.repeat(vehicles.MAX_SUPPLY_VANS()), 1.range(vehicles.MAX_SUPPLY_VANS()), 2);

        // vm.expectRevert(ExceedsLimit.selector);
        // vehicles.airdrop(self.repeat(1), [vehicles.MAX_SUPPLY_VANS()].toMemory(), 2);

        // vehicles.airdrop(self.repeat(vehicles.MAX_SUPPLY_HELICOPTERS()), 1.range(vehicles.MAX_SUPPLY_HELICOPTERS()), 3);

        // vm.expectRevert(ExceedsLimit.selector);
        // vehicles.airdrop(self.repeat(1), [vehicles.MAX_SUPPLY_VANS()].toMemory(), 3);
    }

    function test_mint_vans() public {
        mice.mint(self, 1e40);
        badges.mint(self, 1e40);

        safeHouses.mint(5);

        MockVRFCoordinator(coordinator).fulfillLatestRequests();

        safeHouses.levelUp(2.range(6));
        safeHouses.levelUp(4.range(6));

        vehicles.mint(1.range(6));

        assertEq(vehicles.getVehicleData(1).districtId, 0);
        assertEq(vehicles.getVehicleData(2).districtId, 0);
        assertEq(vehicles.getVehicleData(3).districtId, 0);
        assertEq(vehicles.getVehicleData(4).districtId, 0);
        assertEq(vehicles.getVehicleData(5).districtId, 0);

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

        vehicles.equipGangster([3].toMemory(), [101].toMemory());

        assertEq(vehicles.vehicleToGangsterId(3), 101);
        assertEq(vehicles.gangsterToVehicleId(101), 3);

        assertEq(vehicles.getMultiplier(3), 7);
        assertEq(vehicles.getGangsterMultiplier(101), 7);

        vehicles.equipGangster([3].toMemory(), [0].toMemory());
        vehicles.equipGangster([1].toMemory(), [103].toMemory());

        assertEq(vehicles.vehicleToGangsterId(1), 103);
        assertEq(vehicles.vehicleToGangsterId(3), 0);
        assertEq(vehicles.gangsterToVehicleId(103), 1);

        assertEq(vehicles.getMultiplier(1), 3);
        assertEq(vehicles.getMultiplier(3), 7);
        assertEq(vehicles.getGangsterMultiplier(101), 1);
        assertEq(vehicles.getGangsterMultiplier(103), 3);

        vehicles.equipGangster([1, 3, 2, 5].toMemory(), [103, 101, 106, 103].toMemory());

        assertEq(vehicles.vehicleToGangsterId(1), 0);
        assertEq(vehicles.vehicleToGangsterId(3), 101);
        assertEq(vehicles.gangsterToVehicleId(101), 3);
        assertEq(vehicles.gangsterToVehicleId(106), 2);
        assertEq(vehicles.vehicleToGangsterId(2), 106);
        assertEq(vehicles.vehicleToGangsterId(5), 103);
        assertEq(vehicles.gangsterToVehicleId(103), 5);
    }

    function test_equip_revert_NotAuthorized() public {
        test_equip();

        // Alice can't unequip
        vm.prank(alice);
        vm.expectRevert(NotAuthorized.selector);

        vehicles.equipGangster([3].toMemory(), [101].toMemory());

        // Transfer vehicle 3 to alice
        vehicles.transferFrom(self, alice, 3);

        // Alice can equip her own Gangster
        vm.prank(alice);
        vehicles.equipGangster([3].toMemory(), [2].toMemory());

        // Transfer vehicle 3 back
        vm.prank(alice);
        vehicles.transferFrom(alice, self, 3);

        // Allowed to unequip, since I'm the owner of the vehicle
        vehicles.equipGangster([3].toMemory(), [0].toMemory());

        // Repeat
        vehicles.transferFrom(self, alice, 3);

        vm.prank(alice);
        vehicles.equipGangster([3].toMemory(), [2].toMemory());

        // Take over ownership of alice's Gangster
        gmc.resyncId(self, 2);

        // Able to unequip now, due to ownership of Gangster
        vehicles.equipGangster([3].toMemory(), [0].toMemory());

        vm.prank(alice);
        vm.expectRevert(NotAuthorized.selector);

        vehicles.equipGangster([3].toMemory(), [107].toMemory());

        vm.prank(alice);
        vehicles.equipGangster([3].toMemory(), [5].toMemory());
    }

    function test_gangsterMultiplier() public {
        mice.grantRole(keccak256("AUTHORITY"), alice);
        badges.grantRole(keccak256("AUTHORITY"), alice);
        safeHouses.airdrop([alice].toMemory(), 12);

        vm.startPrank(alice);

        mice.mint(alice, 1e40);
        badges.mint(alice, 1e40);

        mice.approve(address(safeHouses), type(uint256).max);
        badges.approve(address(safeHouses), type(uint256).max);

        // level some up to get van + copter
        safeHouses.levelUp([8, 11, 11].toMemory());

        // mint vehicles
        vehicles.mint(6.range(12));

        // get district assignments
        MockVRFCoordinator(coordinator).fulfillLatestRequests();

        vm.stopPrank();

        // start attack by baron
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        vm.startPrank(alice);

        // equip vehicle and attack
        vehicles.equipGangster([2].toMemory(), [GANGSTER_YAKUZA_1].toMemory());
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());

        assertEq(game.getDistrict(DISTRICT_CARTEL_1).attackForces, 3);

        // equip bike and attack
        vehicles.equipGangster([3].toMemory(), [GANGSTER_YAKUZA_2].toMemory());
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_2].toMemory());

        assertEq(game.getDistrict(DISTRICT_CARTEL_1).attackForces, 10);

        vehicles.transferFrom(alice, eve, 6);

        vm.stopPrank();

        // equip copter and attack
        vm.startPrank(eve);
        vehicles.equipGangster([6].toMemory(), [GANGSTER_YAKUZA_3].toMemory());
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_3].toMemory());

        assertEq(game.getDistrict(DISTRICT_CARTEL_1).attackForces, 24);

        vm.expectRevert(NotAuthorizedDuringGangWar.selector);
        vehicles.equipGangster([6].toMemory(), [0].toMemory());

        uint256 numBikes = getVehicleCountForDistrict(DISTRICT_CARTEL_1, 1, uint8(Gang.YAKUZA));
        assertEq(numBikes, 1);
    }

    function getVehicleCountForDistrict(uint256 districtId, uint256 lvl, uint256 gang)
        internal
        view
        returns (uint256)
    {
        uint256[3][3] memory encodedCount = vehicles.numVehiclesByDistrictId();

        return (encodedCount[lvl][gang] >> districtId * 12) & 0xfff;
    }

    /// Test equip baron
}

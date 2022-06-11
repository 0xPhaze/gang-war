// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "solmate/test/utils/mocks/MockERC721.sol";

import "../lib/ArrayUtils.sol";
import {ERC721UDS} from "UDS/ERC721UDS.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967VersionedUDS.sol";

import "../GangWar.sol";

contract TestGangWar is Test {
    using ArrayUtils for *;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address chris = address(0xc215);
    address tester = address(this);

    GangWar impl;
    GangWar game;
    MockERC721 gmc;

    function setUp() public {
        gmc = new MockERC721("GMC", "GMC");
        impl = new GangWar();

        bytes memory initCall = abi.encodeWithSelector(game.init.selector, ERC721UDS(address(gmc)));
        game = GangWar(address(new ERC1967Proxy(address(impl), initCall)));

        uint256[] memory districtsA = [1, 2, 3, 1, 4, 7].toMemory();
        uint256[] memory districtsB = [2, 3, 4, 4, 5, 8].toMemory();
        game.addDistrictConnections(districtsA, districtsB);

        uint256[] memory gDistrictIds = [1, 2, 3, 4, 5, 6].toMemory();
        uint256[] memory gangsUint256 = [1, 2, 3, 1, 2, 3].toMemory();
        GANG[] memory gangs;
        assembly { gangs := gangsUint256 } // prettier-ignore
        game.setDistrictsInitialOwnership(gDistrictIds, gangs);

        gmc.mint(bob, 1001); // Yakuza Baron
        gmc.mint(bob, 1002); // Cartel Baron
        gmc.mint(bob, 1003); // Cyberp Baron
        gmc.mint(bob, 1004); // Yakuza Baron

        gmc.mint(alice, 1); // Yakuza Gangster
        gmc.mint(alice, 2); // Cartel Gangster
        gmc.mint(alice, 3); // Cyberp Gangster
        gmc.mint(alice, 4); // Yakuza Gangster

        vm.warp(100000);
    }

    function assertEq(GANG a, GANG b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(PLAYER_STATE a, PLAYER_STATE b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(uint256[] memory a, uint256[] memory b) internal {
        assertEq(a.length, b.length);
        for (uint256 i; i < a.length; ++i) assertEq(a[i], b[i]);
    }

    function test_setUp() public {
        assertTrue(game.getDistrictConnections(1, 2));
        assertTrue(game.getDistrictConnections(2, 3));
        assertTrue(game.getDistrictConnections(3, 4));
        assertTrue(game.getDistrictConnections(4, 5));
        assertTrue(game.getDistrictConnections(7, 8));

        for (uint256 i; i < 6; i++) {
            District memory district = game.getDistrict(i + 1);

            assertEq(district.occupants, GANG((i % 3) + 1));
            assertEq(district.roundId, 1);
            assertEq(district.attackDeclarationTime, 0);
            assertEq(district.baronAttackId, 0);
            assertEq(district.baronDefenseId, 0);
            assertEq(district.lastUpkeepTime, 0);
            assertEq(district.lockupTime, 0);
        }

        assertEq(game.gangOf(1), GANG.YAKUZA);
        assertEq(game.gangOf(1001), GANG.YAKUZA);

        assertEq(game.getGangster(1).state, PLAYER_STATE.IDLE);
        assertEq(game.getGangster(1001).state, PLAYER_STATE.IDLE);

        assertEq(game.getConstants().TIME_GANG_WAR, 100);
        assertEq(game.getConstants().TIME_LOCKUP, 100);
        assertEq(game.getConstants().TIME_RECOVERY, 100);
        assertEq(game.getConstants().TIME_REINFORCEMENTS, 100);

        assertTrue(game.getConstants().DEFENSE_FAVOR_LIM > 0);
        assertTrue(game.getConstants().BARON_DEFENSE_FORCE > 0);
        assertTrue(game.getConstants().ATTACK_FAVOR > 0);
        assertTrue(game.getConstants().DEFENSE_FAVOR > 0);

        (uint256 yieldYakuza, uint256 yieldCartel, uint256 yieldCyberpunk) = game.getGangYields();

        assertTrue(yieldYakuza > 0);
        assertEq(yieldYakuza, yieldCartel);
        assertEq(yieldYakuza, yieldCyberpunk);
    }

    /* ------------- baronDeclareAttack() ------------- */

    function test_baronDeclareAttack() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        District memory district = game.getDistrict(2);

        assertEq(district.attackers, GANG.YAKUZA);
        assertEq(district.attackDeclarationTime, block.timestamp);
        assertEq(district.baronAttackId, 1001);

        GangsterView memory baron = game.getGangster(1001);

        assertEq(baron.state, PLAYER_STATE.ATTACK);
        assertEq(baron.location, 2);
        assertEq(baron.roundId, game.getDistrict(2).roundId);
        assertEq(uint256(baron.stateCountdown), game.getConstants().TIME_REINFORCEMENTS);

        // skip after reinforcement time
        skip(game.getConstants().TIME_REINFORCEMENTS);

        baron = game.getGangster(1001);

        assertEq(baron.state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(baron.stateCountdown, 100);
    }

    /// attack the same district twice
    function test_baronDeclareAttack_fail_BaronAttackAlreadyDeclared() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.expectRevert(BaronAttackAlreadyDeclared.selector);

        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);
    }

    /// baron already in an attack
    function test_baronDeclareAttack_fail_BaronInactionable() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.expectRevert(BaronInactionable.selector);

        vm.prank(bob);
        game.baronDeclareAttack(4, 5, 1001);
    }

    /* ------------- joinGangAttack() ------------- */

    function test_joinGangAttack() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.prank(alice);
        game.joinGangAttack(1, 2, [1].toMemory());

        GangsterView memory gangster = game.getGangster(1);

        assertEq(gangster.location, 2);
        assertEq(gangster.state, PLAYER_STATE.ATTACK);
        assertEq(gangster.roundId, game.getDistrict(2).roundId);
        assertEq(uint256(gangster.stateCountdown), game.getConstants().TIME_REINFORCEMENTS);
    }

    /// Baron must lead an attack
    function test_joinGangAttack_fail_BaronMustDeclareInitialAttack() public {
        vm.expectRevert(BaronMustDeclareInitialAttack.selector);

        vm.prank(alice);
        game.joinGangAttack(1, 2, [1].toMemory());
    }

    /// Call for NFT not owned by caller
    function test_joinGangAttack_fail_CallerNotOwner() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.expectRevert(CallerNotOwner.selector);

        vm.prank(bob);
        game.joinGangAttack(1, 2, [1].toMemory());
    }

    /// Invalid connecting district
    function test_joinGangAttack_fail_InvalidConnectingDistrict() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.expectRevert(InvalidConnectingDistrict.selector);

        vm.prank(alice);
        game.joinGangAttack(4, 2, [1].toMemory());
    }

    /// Invalid connecting district
    function test_joinGangAttack_fail_InvalidConnectingDistrict2() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.expectRevert(InvalidConnectingDistrict.selector);

        vm.prank(alice);
        game.joinGangAttack(2, 2, [1].toMemory());
    }

    /// Mixed Gang ids
    function test_joinGangAttack_fail_IdsMustBeOfSameGang() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.expectRevert(IdsMustBeOfSameGang.selector);

        vm.prank(alice);
        game.joinGangAttack(1, 2, [1, 2].toMemory());
    }

    /// Attack as baron
    function test_joinGangAttack_fail_TokenMustBeGangster() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.expectRevert(TokenMustBeGangster.selector);

        vm.prank(bob);
        game.joinGangAttack(1, 2, [1001].toMemory());
    }

    /// Can't attack own district
    function test_joinGangAttack_fail_CannotAttackDistrictOwnedByGang() public {
        vm.expectRevert(CannotAttackDistrictOwnedByGang.selector);

        vm.prank(bob);
        game.baronDeclareAttack(1, 4, 1001);
    }

    /// Locked in attack/defense
    function test_joinGangAttack_fail_GangsterInactionable() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.prank(alice);
        game.joinGangAttack(1, 2, [1].toMemory());

        vm.prank(alice);
        game.joinGangDefense(2, [2].toMemory());

        skip(game.getConstants().TIME_REINFORCEMENTS);

        vm.prank(bob);
        game.baronDeclareAttack(4, 5, 1004);

        vm.expectRevert(GangsterInactionable.selector);

        vm.prank(alice);
        game.joinGangAttack(4, 5, [1].toMemory());

        vm.expectRevert(GangsterInactionable.selector);

        vm.prank(alice);
        game.joinGangDefense(5, [2].toMemory());
    }

    /* ------------- checkUpkeep() ------------- */

    function test_checkUpkeep() public {
        bool upkeepNeeded;

        (upkeepNeeded, ) = game.checkUpkeep("");
        assertFalse(upkeepNeeded);

        skip(50000);

        (upkeepNeeded, ) = game.checkUpkeep("");
        assertFalse(upkeepNeeded);

        // first district that will need upkeep
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        (upkeepNeeded, ) = game.checkUpkeep("");
        assertFalse(upkeepNeeded);

        skip(50000);

        uint256[] memory ids;
        bytes memory data;

        (upkeepNeeded, data) = game.checkUpkeep("");
        assertTrue(upkeepNeeded);

        ids = abi.decode(data, (uint256[]));
        assertEq(ids, [2].toMemory());

        // add an additional attack that needs upkeep
        vm.prank(bob);
        game.baronDeclareAttack(4, 5, 1004);

        skip(50000);

        (upkeepNeeded, data) = game.checkUpkeep("");
        assertTrue(upkeepNeeded);

        ids = abi.decode(data, (uint256[]));
        assertEq(ids, [2, 5].toMemory());
    }

    /* ------------- performUpkeep() ------------- */

    function test_performUpkeep() public {
        bool upkeepNeeded;
        bytes memory data;

        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.prank(bob);
        game.baronDeclareAttack(4, 5, 1004);

        skip(50000);

        (upkeepNeeded, data) = game.checkUpkeep("");

        game.performUpkeep(data);

        assertEq(game.getDistrict(2).roundId, 2);
        assertEq(game.getDistrict(5).roundId, 2);
        assertEq(game.getDistrict(2).lastUpkeepTime, block.timestamp);
        assertEq(game.getDistrict(5).lastUpkeepTime, block.timestamp);

        assertTrue(game.getGangWarOutcome(2, 1) > 0);
        assertTrue(game.getGangWarOutcome(5, 1) > 0);
    }

    function test_performUpkeep_fail_() public {
        game.performUpkeep(abi.encode([1].toMemory()));
    }
}

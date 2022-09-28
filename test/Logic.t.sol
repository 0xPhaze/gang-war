// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "futils/futils.sol";
import "./Base.t.sol";

contract TestGangWarGameLogic is TestGangWar {
    using futils for *;

    function test_setUp() public virtual {
        for (uint256 i; i < 21; i++) {
            for (uint256 j; j < 21; j++) {
                (uint256 a, uint256 b) = (i < j) ? (i, j) : (j, i);
                assertEq(connections[a][b], LibPackedMap.isConnecting(connectionsPacked, i, j));
            }
        }

        for (uint256 i; i < 21; i++) {
            District memory district = game.getDistrict(i);

            // assertEq(district.occupants, Gang((i + 2) % 3));
            assertEq(district.roundId, 1);
            assertEq(district.attackDeclarationTime, 0);
            assertEq(district.baronAttackId, 0);
            assertEq(district.baronDefenseId, 0);
            assertEq(district.lastUpkeepTime, 0);
            assertEq(district.lockupTime, 0);

            assertEq(district.state, DISTRICT_STATE.IDLE);
            assertEq(district.stateCountdown, 0);
        }

        uint256[3][3] memory yield = vault.getYield();

        assertTrue(yield[0][0] > 0);
        assertEq(yield[0][0], yield[1][1]);
        assertEq(yield[0][0], yield[2][2]);

        assertEq(gmc.gangOf(1), Gang.YAKUZA);
        assertEq(gmc.gangOf(2), Gang.CARTEL);
        assertEq(gmc.gangOf(3), Gang.CYBERP);
        assertEq(gmc.gangOf(4), Gang.YAKUZA);
        assertEq(gmc.gangOf(5), Gang.CARTEL);
        assertEq(gmc.gangOf(6), Gang.CYBERP);

        assertEq(gmc.gangOf(10_001), Gang.YAKUZA);
        assertEq(gmc.gangOf(10_002), Gang.CARTEL);
        assertEq(gmc.gangOf(10_003), Gang.CYBERP);
    }

    /* ------------- districtState() & gangsterState() ------------- */

    /// district cycles along with baron + gangster states
    function test_districtState() public {
        assertEq(game.getDistrict(DISTRICT_CARTEL_2).state, DISTRICT_STATE.IDLE);
        assertEq(game.getDistrict(DISTRICT_CARTEL_2).stateCountdown, 0);

        assertEq(game.getGangster(GANGSTER_YAKUZA_1).state, PLAYER_STATE.IDLE);
        assertEq(game.getGangster(GANGSTER_YAKUZA_1).stateCountdown, 0);

        assertEq(game.getGangster(GANGSTER_CARTEL_1).state, PLAYER_STATE.IDLE);
        assertEq(game.getGangster(GANGSTER_CARTEL_1).stateCountdown, 0);

        assertEq(game.getGangster(BARON_YAKUZA_1).state, PLAYER_STATE.IDLE);
        assertEq(game.getGangster(BARON_YAKUZA_1).stateCountdown, 0);

        // REINFORCEMENT
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        vm.prank(alice);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());

        assertEq(game.getDistrict(DISTRICT_CARTEL_1).state, DISTRICT_STATE.REINFORCEMENT);
        assertEq(game.getDistrict(DISTRICT_CARTEL_1).stateCountdown, int256(TIME_REINFORCEMENTS));

        assertEq(game.getGangster(BARON_YAKUZA_1).state, PLAYER_STATE.ATTACK);
        assertEq(game.getGangster(BARON_YAKUZA_1).stateCountdown, int256(TIME_REINFORCEMENTS));
        assertEq(game.getGangster(GANGSTER_YAKUZA_1).state, PLAYER_STATE.ATTACK);
        assertEq(game.getGangster(GANGSTER_YAKUZA_1).stateCountdown, int256(TIME_REINFORCEMENTS));

        // GANG_WAR
        skip(TIME_REINFORCEMENTS);

        assertEq(game.getDistrict(DISTRICT_CARTEL_1).state, DISTRICT_STATE.GANG_WAR);
        assertEq(game.getGangster(BARON_YAKUZA_1).state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(game.getGangster(GANGSTER_YAKUZA_1).state, PLAYER_STATE.ATTACK_LOCKED);

        assertEq(game.getDistrict(DISTRICT_CARTEL_1).stateCountdown, int256(TIME_GANG_WAR));
        assertEq(game.getGangster(GANGSTER_YAKUZA_1).stateCountdown, int256(TIME_GANG_WAR));
        assertEq(game.getGangster(BARON_YAKUZA_1).stateCountdown, int256(TIME_GANG_WAR));

        // POST_GANG_WAR
        skip(TIME_GANG_WAR);

        assertEq(game.getDistrict(DISTRICT_CARTEL_1).state, DISTRICT_STATE.POST_GANG_WAR);
        assertEq(game.getGangster(BARON_YAKUZA_1).state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(game.getGangster(GANGSTER_YAKUZA_1).state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(game.getGangster(0).state, PLAYER_STATE.IDLE);

        assertEq(game.getDistrict(DISTRICT_CARTEL_1).stateCountdown, 0);
        assertEq(game.getGangster(GANGSTER_YAKUZA_1).stateCountdown, 0);
        assertEq(game.getGangster(BARON_YAKUZA_1).stateCountdown, 0);

        // skipping time won't change phase
        skip(10000000000);

        assertEq(game.getDistrict(DISTRICT_CARTEL_1).state, DISTRICT_STATE.POST_GANG_WAR);
        assertEq(game.getGangster(BARON_YAKUZA_1).state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(game.getGangster(GANGSTER_YAKUZA_1).state, PLAYER_STATE.ATTACK_LOCKED);

        // TRUCE - perform upkeep
        (, bytes memory data) = game.checkUpkeep("");
        game.performUpkeep(data);

        MockVRFCoordinator(coordinator).fulfillLatestRequest();

        assertEq(game.getDistrict(DISTRICT_CARTEL_1).state, DISTRICT_STATE.TRUCE);
        // assertEq(game.getGangster(GANGSTER_YAKUZA_1).state, PLAYER_STATE.ATTACK_LOCKED);
        // assertEq(game.getGangster(BARON_YAKUZA_1).state, PLAYER_STATE.IDLE); // xxx this could be injured

        // IDLE
        skip(TIME_TRUCE);

        assertEq(game.getDistrict(DISTRICT_CARTEL_1).state, DISTRICT_STATE.IDLE);
        assertEq(game.getGangster(BARON_YAKUZA_1).state, PLAYER_STATE.IDLE);
    }

    /* ------------- baronDeclareAttack() ------------- */

    function test_baronDeclareAttack() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        District memory district = game.getDistrict(DISTRICT_CARTEL_1);

        assertEq(district.attackers, Gang.YAKUZA);
        assertEq(district.attackDeclarationTime, block.timestamp);
        assertEq(district.baronAttackId, BARON_YAKUZA_1);

        Gangster memory baron = game.getGangster(BARON_YAKUZA_1);

        assertEq(baron.state, PLAYER_STATE.ATTACK);
        assertEq(baron.location, DISTRICT_CARTEL_1);
        assertEq(baron.roundId, game.getDistrict(DISTRICT_CARTEL_1).roundId);
        assertEq(uint256(baron.stateCountdown), TIME_REINFORCEMENTS);

        // skip after reinforcement time
        skip(TIME_REINFORCEMENTS);

        baron = game.getGangster(BARON_YAKUZA_1);

        assertEq(baron.state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(uint256(baron.stateCountdown), TIME_GANG_WAR);
    }

    /// declare attack during locked district state
    function test_baronDeclareAttack_revert_DistrictInvalidState() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        skip(TIME_REINFORCEMENTS);

        vm.prank(bob);
        vm.expectRevert(DistrictInvalidState.selector);

        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_2, false);

        skip(TIME_GANG_WAR);

        vm.prank(bob);
        vm.expectRevert(DistrictInvalidState.selector);

        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_2, false);
        game.performUpkeep(abi.encode(1 << DISTRICT_CARTEL_1));

        MockVRFCoordinator(coordinator).fulfillLatestRequest(99);

        vm.prank(bob);
        vm.expectRevert(CannotAttackDistrictOwnedByGang.selector);

        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_2, false);
    }

    /// verify baron state after attacking 2nd district

    /// verify baron can attack 2nd district

    /// baron already in an attack
    function test_baronDeclareAttack_revert_BaronInactionable() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        vm.expectRevert(BaronInactionable.selector);

        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_1, false);
    }

    /// Can't attack own district
    function test_joinGangAttack_revert_CannotAttackDistrictOwnedByGang() public {
        vm.expectRevert(CannotAttackDistrictOwnedByGang.selector);

        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_YAKUZA_2, BARON_YAKUZA_1, false);
    }

    /* ------------- joinGangAttack() ------------- */

    function test_joinGangAttack() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        vm.prank(alice);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());

        Gangster memory gangster = game.getGangster(GANGSTER_YAKUZA_1);

        assertEq(gangster.roundId, 1);
        assertEq(gangster.location, DISTRICT_CARTEL_1);
        assertEq(gangster.state, PLAYER_STATE.ATTACK);
        assertEq(gangster.stateCountdown, int256(TIME_REINFORCEMENTS));

        District memory district = game.getDistrict(DISTRICT_CARTEL_1);

        assertEq(district.roundId, 1);
        assertEq(district.attackers, Gang.YAKUZA);
        assertEq(district.occupants, Gang.CARTEL);
        assertEq(district.attackForces, 1);
    }

    /// Two simultaneous attacks
    function test_joinGangAttack2() public {
        test_joinGangAttack();

        // -------- perform second attack
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_2, false);

        vm.prank(alice);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, [GANGSTER_YAKUZA_2].toMemory());

        Gangster memory gangster = game.getGangster(GANGSTER_YAKUZA_2);

        assertEq(gangster.roundId, 1);
        assertEq(gangster.location, DISTRICT_CARTEL_2);
        assertEq(gangster.state, PLAYER_STATE.ATTACK);
        assertEq(gangster.stateCountdown, int256(TIME_REINFORCEMENTS));

        Gangster memory baron = game.getGangster(BARON_YAKUZA_2);

        assertEq(baron.roundId, 1);
        assertEq(baron.location, DISTRICT_CARTEL_2);
        assertEq(baron.state, PLAYER_STATE.ATTACK);
        assertEq(baron.stateCountdown, int256(TIME_REINFORCEMENTS));

        District memory district = game.getDistrict(DISTRICT_CARTEL_2);

        assertEq(district.roundId, 1);
        assertEq(district.attackers, Gang.YAKUZA);
        assertEq(district.occupants, Gang.CARTEL);
        assertEq(district.attackForces, 1);
    }

    /// Join in another attack in different district after first attack
    function test_joinGangAttack3() public {
        test_joinGangAttack();

        skip(TIME_REINFORCEMENTS + TIME_GANG_WAR);

        // -------- perform upkeep
        (, bytes memory data) = game.checkUpkeep("");
        game.performUpkeep(data);

        // -------- request outcome
        MockVRFCoordinator(coordinator).fulfillLatestRequest();

        skip(TIME_TRUCE);

        // -------- perform second attack
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_1, false);

        vm.prank(alice);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, [GANGSTER_YAKUZA_1].toMemory());

        Gangster memory gangster = game.getGangster(GANGSTER_YAKUZA_1);

        assertEq(gangster.roundId, 1);
        assertEq(gangster.location, DISTRICT_CARTEL_2);
        assertEq(gangster.state, PLAYER_STATE.ATTACK);
        assertEq(gangster.stateCountdown, int256(TIME_REINFORCEMENTS));
    }

    /// Pull back of gang attack
    function test_joinGangAttack_fakeout() public {
        test_joinGangAttack();

        skip(TIME_REINFORCEMENTS - 1);

        // -------- perform second attack
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_2, false);

        // -------- perform fakeout
        vm.prank(alice);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, [GANGSTER_YAKUZA_1].toMemory());

        Gangster memory gangster = game.getGangster(GANGSTER_YAKUZA_1);

        assertEq(gangster.roundId, 1);
        assertEq(gangster.location, DISTRICT_CARTEL_2);
        assertEq(gangster.state, PLAYER_STATE.ATTACK);
        assertEq(gangster.stateCountdown, int256(TIME_REINFORCEMENTS));

        assertEq(game.getDistrict(DISTRICT_CARTEL_1).attackForces, 0);
        assertEq(game.getDistrict(DISTRICT_CARTEL_2).attackForces, 1);
    }

    /// Exit from gang war
    function test_exitGangAttack() public {
        test_joinGangAttack();

        skip(TIME_REINFORCEMENTS - 1);

        // -------- perform fakeout
        vm.prank(alice);
        game.exitGangWar([GANGSTER_YAKUZA_1].toMemory());

        Gangster memory gangster = game.getGangster(GANGSTER_YAKUZA_1);

        assertEq(gangster.roundId, 0);
        assertEq(gangster.location, 0);
        assertEq(gangster.state, PLAYER_STATE.IDLE);
        assertEq(gangster.stateCountdown, 0);

        assertEq(game.getDistrict(DISTRICT_CARTEL_1).attackForces, 0);
    }

    /// Add testfail

    /// join attack during attack locked district state
    function test_joinGangAttack_revert_DistrictInvalidState() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        skip(TIME_REINFORCEMENTS);

        vm.prank(alice);
        vm.expectRevert(DistrictInvalidState.selector);

        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());

        skip(TIME_GANG_WAR);

        vm.prank(alice);
        vm.expectRevert(DistrictInvalidState.selector);

        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());

        game.performUpkeep(abi.encode(1 << DISTRICT_CARTEL_1));

        MockVRFCoordinator(coordinator).fulfillLatestRequest();

        skip(TIME_TRUCE);

        // round id has advanced, no attack
        vm.prank(alice);
        vm.expectRevert(BaronMustDeclareInitialAttack.selector);

        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());
    }

    /// Baron must lead an attack
    function test_joinGangAttack_revert_BaronMustDeclareInitialAttack() public {
        vm.expectRevert(BaronMustDeclareInitialAttack.selector);

        vm.prank(alice);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());
    }

    /// Call for NFT not owned by caller
    function test_joinGangAttack_revert_CallerNotOwner() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        vm.expectRevert(NotAuthorized.selector);

        vm.prank(bob);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());
    }

    /// Invalid connecting district
    function test_joinGangAttack_revert_InvalidConnectingDistrict() public {
        vm.prank(bob);
        vm.expectRevert(InvalidConnectingDistrict.selector);

        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CYBERP_1, BARON_YAKUZA_1, false);
    }

    /// Mixed Gang ids
    function test_joinGangAttack_revert_IdsMustBeOfSameGang() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        vm.expectRevert(IdsMustBeOfSameGang.selector);

        vm.prank(alice);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1, GANGSTER_CARTEL_1].toMemory());
    }

    /// Attack as baron
    function test_joinGangAttack_revert_TokenMustBeGangster() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        vm.expectRevert(TokenMustBeGangster.selector);

        vm.prank(bob);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [BARON_YAKUZA_2].toMemory());
    }

    /// Locked in attack/defense
    function test_joinGangAttack_revert_BaronInactionable() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        skip(TIME_REINFORCEMENTS);

        vm.expectRevert(BaronInactionable.selector);

        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_1, false);
    }

    /// Locked in attack/defense
    function test_joinGangAttack_revert_GangsterInactionable() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        vm.prank(alice);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());

        skip(TIME_REINFORCEMENTS);

        Gangster memory gangster = game.getGangster(GANGSTER_YAKUZA_1);

        assertEq(gangster.location, DISTRICT_CARTEL_1);
        assertEq(gangster.state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(gangster.roundId, game.getDistrict(0).roundId);
        assertEq(gangster.stateCountdown, int256(TIME_GANG_WAR));

        // try attacking while locked
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_2, false);

        vm.expectRevert(GangsterInactionable.selector);

        vm.prank(alice);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, [GANGSTER_YAKUZA_1].toMemory());

        // // try defending while locked
        // vm.prank(bob);
        // game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_2, false);
        // vm.expectRevert(GangsterInactionable.selector);

        // vm.prank(alice);
        // game.joinGangDefense(DISTRICT_CARTEL_2, [GANGSTER_CARTEL_1].toMemory());
    }

    /* ------------- joinGangDefense() ------------- */

    function test_joinGangDefense() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        vm.prank(alice);
        game.joinGangDefense(DISTRICT_CARTEL_1, [GANGSTER_CARTEL_1].toMemory());

        Gangster memory gangster = game.getGangster(GANGSTER_CARTEL_1);

        assertEq(gangster.location, DISTRICT_CARTEL_1);
        assertEq(gangster.state, PLAYER_STATE.DEFEND);
        assertEq(gangster.roundId, game.getDistrict(0).roundId);
        assertEq(gangster.stateCountdown, int256(TIME_REINFORCEMENTS));
    }

    /// @notice repeat for defense

    /* ------------- checkUpkeep() ------------- */

    function test_checkUpkeep() public {
        bool upkeepNeeded;
        bytes memory data;

        (upkeepNeeded, ) = game.checkUpkeep("");
        assertFalse(upkeepNeeded);

        skip(100 days);

        (upkeepNeeded, ) = game.checkUpkeep("");
        assertFalse(upkeepNeeded);

        // first district that will need upkeep
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        (upkeepNeeded, ) = game.checkUpkeep("");
        assertFalse(upkeepNeeded);

        // upkeep is needed after time passage
        skip(TIME_REINFORCEMENTS);

        (upkeepNeeded, ) = game.checkUpkeep("");
        assertFalse(upkeepNeeded);

        // upkeep is needed after gang war
        skip(TIME_GANG_WAR);

        (upkeepNeeded, data) = game.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    function test_performUpkeep() public {
        bool upkeepNeeded;
        bytes memory data;
        bytes32[] memory writes;

        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        skip(TIME_REINFORCEMENTS + TIME_GANG_WAR);

        (upkeepNeeded, data) = game.checkUpkeep("");

        assertTrue(upkeepNeeded);
        assertEq(abi.decode(data, (uint256)), 1 << DISTRICT_CARTEL_1);

        // performing upkeep does not do anything (all true except for district cartel 1)
        vm.record();

        // vm.expectRevert(InvalidUpkeep.selector);
        game.performUpkeep(abi.encode(~uint256(1 << DISTRICT_CARTEL_1)));

        (, writes) = vm.accesses(address(game));

        assertEq(writes.length, 0);

        // add an additional attack that needs upkeep
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_2, false);

        skip(TIME_REINFORCEMENTS + TIME_GANG_WAR);

        (, data) = game.checkUpkeep("");
        assertEq(abi.decode(data, (uint256)), (1 << DISTRICT_CARTEL_1) | (1 << DISTRICT_CARTEL_2));

        // perform upkeep on 2
        game.performUpkeep(abi.encode(1 << DISTRICT_CARTEL_1));

        (, data) = game.checkUpkeep("");
        assertEq(abi.decode(data, (uint256)), (1 << DISTRICT_CARTEL_2));

        // performing upkeep twice does not do anything
        vm.record();

        game.performUpkeep(abi.encode(1 << DISTRICT_CARTEL_1));

        (, writes) = vm.accesses(address(game));
        assertEq(writes.length, 0);

        // upkeep 5
        game.performUpkeep(abi.encode(1 << DISTRICT_CARTEL_2));

        // checkUpkeep should be false after perform
        (upkeepNeeded, data) = game.checkUpkeep("");
        assertFalse(upkeepNeeded);
        assertEq(abi.decode(data, (uint256)), 0);

        // waiting for 1 minute without confirming VRF call should reset request status
        skip(5 minutes + 1);

        (upkeepNeeded, data) = game.checkUpkeep("");
        assertTrue(upkeepNeeded);
        assertEq(abi.decode(data, (uint256)), (1 << DISTRICT_CARTEL_1) | (1 << DISTRICT_CARTEL_2));
    }

    /* ------------- fullfillRandomWords() ------------- */

    function test_fullfillRandomWords() public {
        bool upkeepNeeded;
        bytes memory data;

        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_2, false);

        skip(TIME_REINFORCEMENTS + TIME_GANG_WAR);

        (upkeepNeeded, data) = game.checkUpkeep("");

        game.performUpkeep(data);

        // assertions
        District memory district1;
        District memory district2;

        district1 = game.getDistrict(DISTRICT_CARTEL_1);
        district2 = game.getDistrict(DISTRICT_CARTEL_2);

        assertEq(district1.state, DISTRICT_STATE.POST_GANG_WAR);
        assertEq(district2.state, DISTRICT_STATE.POST_GANG_WAR);
        assertEq(district1.roundId, 1); // starts at 1
        assertEq(district2.roundId, 1);
        assertEq(district1.lastUpkeepTime, block.timestamp);
        assertEq(district2.lastUpkeepTime, block.timestamp);
        assertEq(district1.lastOutcomeTime, 0);
        assertEq(district2.lastOutcomeTime, 0);
        assertEq(game.gangWarOutcome(DISTRICT_CARTEL_1, 1), 0);
        assertEq(game.gangWarOutcome(DISTRICT_CARTEL_2, 1), 0);

        // upkeepNeeded should be false now
        (upkeepNeeded, data) = game.checkUpkeep("");
        uint256[] memory ids = abi.decode(data, (uint256[]));

        assertFalse(upkeepNeeded);
        assertEq(ids.length, 0);

        MockVRFCoordinator(coordinator).fulfillLatestRequest();

        district1 = game.getDistrict(DISTRICT_CARTEL_1);
        district2 = game.getDistrict(DISTRICT_CARTEL_2);

        assertEq(district1.state, DISTRICT_STATE.TRUCE);
        assertEq(district2.state, DISTRICT_STATE.TRUCE);
        assertEq(district1.roundId, 2);
        assertEq(district2.roundId, 2);
        assertEq(district1.lastOutcomeTime, block.timestamp);
        assertEq(district2.lastOutcomeTime, block.timestamp);
        assertTrue(game.gangWarOutcome(DISTRICT_CARTEL_1, 1) > 0);
        assertTrue(game.gangWarOutcome(DISTRICT_CARTEL_2, 1) > 0);

        // check district state

        // upkeep should remain false, even after 1 additional minute
        skip(1 minutes + 1);
        (upkeepNeeded, data) = game.checkUpkeep("");
        ids = abi.decode(data, (uint256[]));

        assertFalse(upkeepNeeded);
        assertEq(ids.length, 0);
    }

    /* ------------- injury() ------------- */

    // TODO fix
    // function test_injury() public {
    //     test_joinGangAttack();

    //     skip(TIME_REINFORCEMENTS + TIME_GANG_WAR);

    //     (, bytes memory data) = game.checkUpkeep("");

    //     game.performUpkeep(data);

    //     MockVRFCoordinator(coordinator).fulfillLatestRequest();

    //     District memory district = game.getDistrict(DISTRICT_CARTEL_1);

    //     assertEq(district.roundId, 2);
    //     assertEq(district.state, DISTRICT_STATE.TRUCE);
    //     assertEq(district.lastOutcomeTime, block.timestamp);

    //     game.setGangWarOutcome(DISTRICT_CARTEL_1, district.roundId, 1333);
    //     game.setDefenseForces(DISTRICT_CARTEL_1, district.roundId, 1e18);

    //     assertEq(game.getGangster(GANGSTER_YAKUZA_1).state, PLAYER_STATE.INJURED);
    //     assertEq(game.getGangster(GANGSTER_YAKUZA_1).stateCountdown, int256(TIME_RECOVERY));
    // }

    // function test_recovery() public {
    //     test_injury();

    //     game.setBriberyFee(address(gouda), 100);

    //     address(gouda).balanceDiff(bob);

    //     vm.startPrank(bob);

    //     game.bribery([GANGSTER_YAKUZA_1].toMemory(), address(gouda));

    //     assertEq(address(gouda).balanceDiff(bob), -100);
    //     assertApproxEqAbs(game.getGangster(GANGSTER_YAKUZA_1).stateCountdown, int256(TIME_RECOVERY) / 2, 1);

    //     game.bribery([GANGSTER_YAKUZA_1].toMemory(), address(gouda));

    //     assertEq(address(gouda).balanceDiff(bob), -100);
    //     assertApproxEqAbs(game.getGangster(GANGSTER_YAKUZA_1).stateCountdown, int256(TIME_RECOVERY) / 4, 1);

    //     game.bribery([GANGSTER_YAKUZA_1].toMemory(), address(gouda));

    //     assertEq(address(gouda).balanceDiff(bob), -100);
    //     assertApproxEqAbs(game.getGangster(GANGSTER_YAKUZA_1).stateCountdown, int256(TIME_RECOVERY) / 8, 1);
    // }

    // function test_recovery_InvalidToken() public {
    //     test_injury();

    //     vm.expectRevert(InvalidToken.selector);

    //     game.bribery([GANGSTER_YAKUZA_1].toMemory(), address(0x1337));

    //     assertEq(game.getGangster(GANGSTER_YAKUZA_1).stateCountdown, int256(TIME_RECOVERY));
    // }

    /* ------------- lockup() ------------- */

    // test lockup when gangvault balance is less than fine
    function test_lockup() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        vm.prank(alice);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());

        skip(TIME_REINFORCEMENTS + TIME_GANG_WAR);

        uint256[3] memory balancesBefore = vault.getGangVaultBalance(uint8(Gang.CARTEL));

        (, bytes memory data) = game.checkUpkeep("");

        game.performUpkeep(data);

        // random % 21 corresponds to locked up district
        MockVRFCoordinator(coordinator).fulfillLatestRequest(DISTRICT_CARTEL_1);

        uint256[3] memory balancesAfter = vault.getGangVaultBalance(uint8(Gang.CARTEL));

        District memory district = game.getDistrict(DISTRICT_CARTEL_1);

        assertEq(district.roundId, 2);
        assertEq(district.state, DISTRICT_STATE.LOCKUP);
        assertEq(district.lastOutcomeTime, block.timestamp);

        assertEq(balancesAfter[0], 0);
        assertTrue(balancesBefore[1] - balancesAfter[1] > 0);
        assertEq(balancesAfter[2], 0);
    }

    // test lockup when gangvault balance is enough and both teams are locked
    function test_lockup_fullFine() public {
        vault.setYield(uint8(Gang.YAKUZA), [uint256(0), 1e10, 0]); // make sure they have balances so can get fined

        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        vm.prank(alice);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());

        skip(100 days);

        uint256[3] memory balancesBeforeCartel = vault.getGangVaultBalance(uint8(Gang.CARTEL));

        uint256[3] memory balancesBeforeYakuza = vault.getGangVaultBalance(uint8(Gang.YAKUZA));

        (, bytes memory data) = game.checkUpkeep("");

        game.performUpkeep(data);

        // random % 21 corresponds to locked up district
        MockVRFCoordinator(coordinator).fulfillLatestRequest(DISTRICT_CARTEL_1);

        uint256[3] memory balancesAfterCartel = vault.getGangVaultBalance(uint8(Gang.CARTEL));

        uint256[3] memory balancesAfterYakuza = vault.getGangVaultBalance(uint8(Gang.YAKUZA));

        District memory district = game.getDistrict(DISTRICT_CARTEL_1);

        assertEq(district.roundId, 2);
        assertEq(district.state, DISTRICT_STATE.LOCKUP);
        assertEq(district.lastOutcomeTime, block.timestamp);

        assertEq(balancesBeforeCartel[1] - balancesAfterCartel[1], LOCKUP_FINE);
        assertEq(balancesBeforeYakuza[1] - balancesAfterYakuza[1], LOCKUP_FINE);
    }

    function test_bribery() public {
        test_lockup();

        game.setBriberyFee(address(gouda), 100);

        address(gouda).balanceDiff(bob);

        skip(66);

        vm.startPrank(bob);

        game.bribery([GANGSTER_YAKUZA_1].toMemory(), address(gouda));

        int256 timeLeft = (int256(TIME_LOCKUP) - 66) / 2;

        assertEq(address(gouda).balanceDiff(bob), -100);
        assertApproxEqAbs(game.getGangster(GANGSTER_YAKUZA_1).stateCountdown, timeLeft, 1);

        game.bribery([GANGSTER_YAKUZA_1].toMemory(), address(gouda));

        timeLeft /= 2;

        assertEq(address(gouda).balanceDiff(bob), -100);
        assertApproxEqAbs(game.getGangster(GANGSTER_YAKUZA_1).stateCountdown, timeLeft, 1);

        skip(40);

        timeLeft -= 40;
        timeLeft /= 2;

        game.bribery([GANGSTER_YAKUZA_1].toMemory(), address(gouda));

        assertEq(address(gouda).balanceDiff(bob), -100);
        assertApproxEqAbs(game.getGangster(GANGSTER_YAKUZA_1).stateCountdown, timeLeft, 1);
    }

    function test_bribery_revert_TokenMustBeGangster() public {
        test_lockup();

        vm.prank(bob);
        vm.expectRevert(TokenMustBeGangster.selector);

        game.bribery([BARON_YAKUZA_1].toMemory(), address(gouda));
    }

    /* ------------- badgesReward ------------- */

    // test badges reward
    function test_badges() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        vm.prank(alice);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());

        vm.prank(eve);
        game.joinGangDefense(DISTRICT_CARTEL_1, [GANGSTER_CARTEL_3].toMemory());

        skip(TIME_REINFORCEMENTS + TIME_GANG_WAR);

        (, bytes memory data) = game.checkUpkeep("");
        game.performUpkeep(data);

        // no lockup
        MockVRFCoordinator(coordinator).fulfillLatestRequest(99);

        vm.prank(alice);
        game.collectBadges([GANGSTER_YAKUZA_1].toMemory());

        vm.prank(alice);
        game.collectBadges([GANGSTER_YAKUZA_1].toMemory());

        vm.prank(eve);
        game.collectBadges([GANGSTER_CARTEL_3].toMemory());

        vm.prank(eve);
        game.collectBadges([GANGSTER_CARTEL_3].toMemory());

        if (game.gangAttackSuccess(DISTRICT_CARTEL_1, 1)) {
            assertEq(address(badges).balanceDiff(eve), int256(BADGES_EARNED_DEFEAT));
            assertEq(address(badges).balanceDiff(alice), int256(BADGES_EARNED_VICTORY));
        } else {
            assertEq(address(badges).balanceDiff(eve), int256(BADGES_EARNED_VICTORY));
            assertEq(address(badges).balanceDiff(alice), int256(BADGES_EARNED_DEFEAT));
        }
    }

    // test badges reward while renting
    function test_badgesRenting() public {
        vm.prank(bob);
        game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);

        Offer[] memory offers = new Offer[](3);
        offers[0].renter = bob;
        offers[0].renterShare = 60;

        vm.prank(alice);
        gmc.listOffer([GANGSTER_YAKUZA_1].toMemory(), offers);

        // bob joins with alice's rented gangster
        vm.prank(bob);
        game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());

        vm.prank(eve);
        game.joinGangDefense(DISTRICT_CARTEL_1, [GANGSTER_CARTEL_3].toMemory());

        skip(TIME_REINFORCEMENTS + TIME_GANG_WAR);

        (, bytes memory data) = game.checkUpkeep("");
        game.performUpkeep(data);

        // no lockup
        MockVRFCoordinator(coordinator).fulfillLatestRequest(99);

        vm.prank(bob);
        game.collectBadges([GANGSTER_YAKUZA_1].toMemory());

        // alice is not authorized as active player
        vm.prank(alice);
        vm.expectRevert(NotAuthorized.selector);
        game.collectBadges([GANGSTER_YAKUZA_1].toMemory());

        vm.prank(eve);
        game.collectBadges([GANGSTER_CARTEL_3].toMemory());

        if (game.gangAttackSuccess(DISTRICT_CARTEL_1, 1)) {
            assertEq(address(badges).balanceDiff(eve), int256(BADGES_EARNED_DEFEAT));
            assertEq(address(badges).balanceDiff(bob), (int256(BADGES_EARNED_VICTORY) * 60) / 100);
            assertEq(address(badges).balanceDiff(alice), (int256(BADGES_EARNED_VICTORY) * 40) / 100);
        } else {
            assertEq(address(badges).balanceDiff(eve), int256(BADGES_EARNED_VICTORY));
            assertEq(address(badges).balanceDiff(bob), (int256(BADGES_EARNED_DEFEAT) * 60) / 100);
            assertEq(address(badges).balanceDiff(alice), (int256(BADGES_EARNED_DEFEAT) * 40) / 100);
        }
    }

    // @notice test with all roundId mismatch combinations

    // function test_upkeepGas() public {
    //     for (uint256 i; i < 21; i++) {
    //         try gmc.mint(bob, 10_000 + i) {} catch {}
    //     }

    //     for (uint256 i; i < 10; i++) {
    //         vm.prank(bob);
    //         game.baronDeclareAttack(i, i, 10_000 + i, false);
    //     }

    //     skip(1000 days);

    //     assertEq(game.getDistrict(DISTRICT_CARTEL_1).state, DISTRICT_STATE.POST_GANG_WAR);

    //     (, bytes memory data) = game.checkUpkeep("");

    //     game.performUpkeep(data);

    //     uint256[] memory randomWords = new uint256[](1);
    //     randomWords[0] = 1234;

    //     uint256 id = coordinator.requestIdCounter();

    //     vm.prank(address(coordinator));

    //     uint256 gas = gasleft();

    //     address(game).call(
    //         abi.encodeWithSelector(bytes4(keccak256("rawFulfillRandomWords(uint256,uint256[])")), id, randomWords)
    //     );

    //     gas = gas - gasleft();

    //     console.log("gas", gas);

    //     skip(10000000000);

    //     assertEq(game.getDistrict(DISTRICT_CARTEL_1).state, DISTRICT_STATE.IDLE);

    //     for (uint256 i; i < 10; i++) {
    //         vm.prank(bob);
    //         game.baronDeclareAttack(i, i, 10_000 + i, false);
    //     }

    //     skip(1000 days);

    //     (, data) = game.checkUpkeep("");

    //     game.performUpkeep(data);

    //     vm.prank(address(coordinator));

    //     gas = gasleft();

    //     address(game).call(
    //         abi.encodeWithSelector(bytes4(keccak256("rawFulfillRandomWords(uint256,uint256[])")), 2, randomWords)
    //     );

    //     gas = gas - gasleft();

    //     console.log("gas", gas);

    //     skip(1000 days);

    //     assertEq(game.getDistrict(DISTRICT_CARTEL_1).state, DISTRICT_STATE.IDLE);

    //     // assertEq(game.getDistrict(DISTRICT_CARTEL_1).state, DISTRICT_STATE.IDLE);
    // }
}

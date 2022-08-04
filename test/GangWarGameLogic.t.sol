// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "/lib/ArrayUtils.sol";
import "./GangWarBase.t.sol";

contract TestGangWarGameLogic is TestGangWar {
    using ArrayUtils for *;

    /* ------------- districtState() & gangsterState() ------------- */

    /// district cycles along with baron + gangster states
    function test_districtState() public {
        assertEq(game.getDistrictView(1).state, DISTRICT_STATE.IDLE);
        assertEq(game.getDistrictView(1).stateCountdown, 0);
        assertEq(game.getGangsterView(1).state, PLAYER_STATE.IDLE);
        assertEq(game.getGangsterView(1).stateCountdown, 0);
        assertEq(game.getGangsterView(2).state, PLAYER_STATE.IDLE);
        assertEq(game.getGangsterView(2).stateCountdown, 0);
        assertEq(game.getGangsterView(1001).state, PLAYER_STATE.IDLE);
        assertEq(game.getGangsterView(1001).stateCountdown, 0);

        // REINFORCEMENT
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.prank(alice);
        game.joinGangAttack(1, 2, [1].toMemory());

        assertEq(game.getDistrictView(2).state, DISTRICT_STATE.REINFORCEMENT);
        assertEq(game.getGangsterView(1).state, PLAYER_STATE.ATTACK);
        assertEq(game.getGangsterView(1001).state, PLAYER_STATE.ATTACK);
        assertEq(game.getGangsterView(2).state, PLAYER_STATE.IDLE);

        assertEq(game.getDistrictView(2).stateCountdown, int256(TIME_REINFORCEMENTS));
        assertEq(game.getGangsterView(1).stateCountdown, int256(TIME_REINFORCEMENTS));
        assertEq(game.getGangsterView(1001).stateCountdown, int256(TIME_REINFORCEMENTS));
        assertEq(game.getGangsterView(2).stateCountdown, 0);

        // GANG_WAR
        skip(TIME_REINFORCEMENTS);

        assertEq(game.getDistrictView(2).state, DISTRICT_STATE.GANG_WAR);
        assertEq(game.getGangsterView(1001).state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(game.getGangsterView(1).state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(game.getGangsterView(2).state, PLAYER_STATE.IDLE);

        assertEq(game.getDistrictView(2).stateCountdown, int256(TIME_GANG_WAR));
        assertEq(game.getGangsterView(1).stateCountdown, int256(TIME_GANG_WAR));
        assertEq(game.getGangsterView(1001).stateCountdown, int256(TIME_GANG_WAR));
        assertEq(game.getGangsterView(2).stateCountdown, 0);

        // POST_GANG_WAR
        skip(TIME_GANG_WAR);

        assertEq(game.getDistrictView(2).state, DISTRICT_STATE.POST_GANG_WAR);
        assertEq(game.getGangsterView(1001).state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(game.getGangsterView(1).state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(game.getGangsterView(2).state, PLAYER_STATE.IDLE);

        assertEq(game.getDistrictView(2).stateCountdown, 0);
        assertEq(game.getGangsterView(1).stateCountdown, 0);
        assertEq(game.getGangsterView(1001).stateCountdown, 0);
        assertEq(game.getGangsterView(2).stateCountdown, 0);

        // skipping time won't change phase
        skip(10000000000);

        assertEq(game.getDistrictView(2).state, DISTRICT_STATE.POST_GANG_WAR);
        assertEq(game.getGangsterView(1001).state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(game.getGangsterView(1).state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(game.getGangsterView(2).state, PLAYER_STATE.IDLE);

        // TRUCE - perform upkeep
        (, bytes memory data) = game.checkUpkeep("");
        game.performUpkeep(data);

        uint256 requestId = coordinator.requestIdCounter();
        vm.prank(address(coordinator));
        game.rawFulfillRandomWords(requestId, [1234].toMemory());

        assertEq(game.getDistrictView(2).state, DISTRICT_STATE.TRUCE);
        // assertEq(game.getGangsterView(1).state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(game.getGangsterView(2).state, PLAYER_STATE.IDLE);
        // assertEq(game.getGangsterView(1001).state, PLAYER_STATE.IDLE); // xxx this could be injured

        // IDLE
        skip(TIME_TRUCE);

        assertEq(game.getDistrictView(2).state, DISTRICT_STATE.IDLE);
        assertEq(game.getGangsterView(1001).state, PLAYER_STATE.IDLE);
    }

    /* ------------- baronDeclareAttack() ------------- */

    function test_baronDeclareAttack() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        District memory district = game.getDistrict(2);

        assertEq(district.attackers, Gang.YAKUZA);
        assertEq(district.attackDeclarationTime, block.timestamp);
        assertEq(district.baronAttackId, 1001);

        GangsterView memory baron = game.getGangsterView(1001);

        assertEq(baron.state, PLAYER_STATE.ATTACK);
        assertEq(baron.location, 2);
        assertEq(baron.roundId, game.getDistrict(2).roundId);
        assertEq(uint256(baron.stateCountdown), TIME_REINFORCEMENTS);

        // skip after reinforcement time
        skip(TIME_REINFORCEMENTS);

        baron = game.getGangsterView(1001);

        assertEq(baron.state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(uint256(baron.stateCountdown), TIME_GANG_WAR);
    }

    /// declare attack during locked district state
    function test_baronDeclareAttack_fail_DistrictInvalidState() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        skip(TIME_REINFORCEMENTS);

        vm.prank(bob);
        vm.expectRevert(DistrictInvalidState.selector);

        game.baronDeclareAttack(4, 2, 1004);

        skip(TIME_GANG_WAR);

        vm.prank(bob);
        vm.expectRevert(DistrictInvalidState.selector);

        game.baronDeclareAttack(4, 2, 1004);

        game.performUpkeep(abi.encode(1 << 2));

        uint256 requestId = coordinator.requestIdCounter();

        vm.prank(address(coordinator));
        game.rawFulfillRandomWords(requestId, [331].toMemory());

        vm.prank(bob);
        vm.expectRevert(DistrictInvalidState.selector);

        game.baronDeclareAttack(4, 2, 1004);

        skip(TIME_TRUCE);
    }

    /// verify baron state after attacking 2nd district

    /// verify baron can attack 2nd district

    /// baron already in an attack
    function test_baronDeclareAttack_fail_BaronInactionable() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.expectRevert(BaronInactionable.selector);

        vm.prank(bob);
        game.baronDeclareAttack(1, 5, 1001);
    }

    /// Can't attack own district
    function test_joinGangAttack_fail_CannotAttackDistrictOwnedByGang() public {
        vm.expectRevert(CannotAttackDistrictOwnedByGang.selector);

        vm.prank(bob);
        game.baronDeclareAttack(1, 4, 1001);
    }

    /* ------------- joinGangAttack() ------------- */

    function test_joinGangAttack() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.prank(alice);
        game.joinGangAttack(1, 2, [1].toMemory());

        GangsterView memory gangster = game.getGangsterView(1);

        assertEq(gangster.roundId, 1);
        assertEq(gangster.location, 2);
        assertEq(gangster.state, PLAYER_STATE.ATTACK);
        assertEq(gangster.stateCountdown, int256(TIME_REINFORCEMENTS));

        DistrictView memory district = game.getDistrictView(2);

        assertEq(district.roundId, 1);
        assertEq(district.attackers, Gang.YAKUZA);
        assertEq(district.occupants, Gang.CARTEL);

        // DistrictView memory district = game.getGangsterView(1);
    }

    /// Join in another attack in different district
    function test_joinGangAttack2() public {
        // -------- perform first attack
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.prank(alice);
        game.joinGangAttack(1, 2, [1].toMemory());

        skip(TIME_REINFORCEMENTS + TIME_GANG_WAR);

        // -------- perform upkeep
        (, bytes memory data) = game.checkUpkeep("");
        game.performUpkeep(data);

        // -------- request outcome
        uint256 requestId = coordinator.requestIdCounter();
        vm.prank(address(coordinator));
        game.rawFulfillRandomWords(requestId, [1234].toMemory());

        skip(TIME_TRUCE);

        // -------- perform second attack
        vm.prank(bob);
        game.baronDeclareAttack(4, 5, 1001);

        vm.prank(alice);
        game.joinGangAttack(4, 5, [1].toMemory());

        GangsterView memory gangster = game.getGangsterView(1);

        assertEq(gangster.roundId, 1);
        assertEq(gangster.location, 5);
        assertEq(gangster.state, PLAYER_STATE.ATTACK);
        assertEq(gangster.stateCountdown, int256(TIME_REINFORCEMENTS));
        assertEq(game.getDistrict(4).roundId, 1);
    }

    // assertEq(game.getDistrictView(2).attackForces, 1);
    // assertEq(game.getDistrictView(2).defenseForces, 0);
    /// Pull back of gang attack
    function test_joinGangAttack_fakeout() public {
        // -------- perform first attack
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        // vm.prank(bob);
        // game.baronDeclareAttack(4, 5, 1001);

        // vm.prank(alice);
        // game.joinGangAttack(1, 2, [1].toMemory());

        // skip(1 minutes);
        // skip(TIME_REINFORCEMENTS + TIME_GANG_WAR);

        // // -------- perform upkeep
        // (, bytes memory data) = game.checkUpkeep("");
        // game.performUpkeep(data);

        // // -------- request outcome
        // uint256 requestId = coordinator.requestIdCounter();
        // vm.prank(address(coordinator));
        // game.rawFulfillRandomWords(requestId, [1234].toMemory());

        // skip(TIME_TRUCE);

        // // -------- perform second attack
        // vm.prank(bob);
        // game.baronDeclareAttack(4, 5, 1001);

        // vm.prank(alice);
        // game.joinGangAttack(4, 5, [1].toMemory());

        // GangsterView memory gangster = game.getGangsterView(1);

        // assertEq(gangster.roundId, 1);
        // assertEq(gangster.location, 5);
        // assertEq(gangster.state, PLAYER_STATE.ATTACK);
        // assertEq(game.getDistrict(4).roundId, 1);
        // assertEq(gangster.stateCountdown, int256(TIME_REINFORCEMENTS));
    }

    /// join attack during locked district state
    function test_joinGangAttack_fail_DistrictInvalidState() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        skip(TIME_REINFORCEMENTS);

        vm.prank(alice);
        vm.expectRevert(DistrictInvalidState.selector);

        game.joinGangAttack(1, 2, [1].toMemory());

        skip(TIME_GANG_WAR);

        vm.prank(alice);
        vm.expectRevert(DistrictInvalidState.selector);

        game.joinGangAttack(1, 2, [1].toMemory());

        game.performUpkeep(abi.encode(1 << 2));

        uint256 requestId = coordinator.requestIdCounter();

        vm.prank(address(coordinator));
        game.rawFulfillRandomWords(requestId, [333].toMemory());

        skip(TIME_TRUCE);

        // round id has advanced, no attack
        vm.prank(alice);
        vm.expectRevert(BaronMustDeclareInitialAttack.selector);

        game.joinGangAttack(1, 2, [1].toMemory());
    }

    /// Baron must lead an attack

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

        vm.expectRevert(NotAuthorized.selector);

        vm.prank(bob);
        game.joinGangAttack(1, 2, [1].toMemory());
    }

    /// Invalid connecting district
    function test_joinGangAttack_fail_InvalidConnectingDistrict() public {
        vm.prank(bob);
        vm.expectRevert(InvalidConnectingDistrict.selector);

        game.baronDeclareAttack(1, 3, 1001);
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

    /// Locked in attack/defense
    function test_joinGangAttack_fail_BaronInactionable() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        skip(TIME_REINFORCEMENTS);

        vm.expectRevert(BaronInactionable.selector);

        vm.prank(bob);
        game.baronDeclareAttack(4, 5, 1001);
    }

    /// Locked in attack/defense
    function test_joinGangAttack_fail_GangsterInactionable() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.prank(alice);
        game.joinGangAttack(1, 2, [1].toMemory());

        skip(TIME_REINFORCEMENTS);

        GangsterView memory gangster = game.getGangsterView(1);

        assertEq(gangster.location, 2);
        assertEq(gangster.state, PLAYER_STATE.ATTACK_LOCKED);
        assertEq(gangster.roundId, game.getDistrict(2).roundId);
        assertEq(gangster.stateCountdown, int256(TIME_GANG_WAR));

        vm.prank(bob);
        game.baronDeclareAttack(4, 5, 1004);

        vm.expectRevert(GangsterInactionable.selector);

        // try attacking while locked
        vm.prank(alice);
        game.joinGangAttack(4, 5, [1].toMemory());

        // // try defending while locked
        // vm.expectRevert(GangsterInactionable.selector);

        // vm.prank(alice);
        // game.joinGangDefense(4, [1].toMemory());
    }

    /* ------------- joinGangDefense() ------------- */

    function test_joinGangDefense() public {
        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.prank(alice);
        game.joinGangDefense(2, [2].toMemory());

        GangsterView memory gangster = game.getGangsterView(2);

        assertEq(gangster.location, 2);
        assertEq(gangster.state, PLAYER_STATE.DEFEND);
        assertEq(gangster.roundId, game.getDistrict(2).roundId);
        assertEq(gangster.stateCountdown, int256(TIME_REINFORCEMENTS));
    }

    // @note repeat for defense

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
        game.baronDeclareAttack(1, 2, 1001);

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
        game.baronDeclareAttack(1, 2, 1001);

        skip(TIME_REINFORCEMENTS + TIME_GANG_WAR);

        (upkeepNeeded, data) = game.checkUpkeep("");

        assertTrue(upkeepNeeded);
        assertEq(abi.decode(data, (uint256)), 1 << 2);

        // performing upkeep does not do anything
        vm.record();

        game.performUpkeep(abi.encode(~uint256(1 << 2)));

        (, writes) = vm.accesses(address(game));

        assertEq(writes.length, 0);

        // add an additional attack that needs upkeep
        vm.prank(bob);
        game.baronDeclareAttack(4, 5, 1004);

        skip(TIME_REINFORCEMENTS + TIME_GANG_WAR);

        (, data) = game.checkUpkeep("");
        assertEq(abi.decode(data, (uint256)), (1 << 2) | (1 << 5));

        // perform upkeep on 2
        game.performUpkeep(abi.encode(1 << 2));

        (, data) = game.checkUpkeep("");
        assertEq(abi.decode(data, (uint256)), (1 << 5));

        // performing upkeep twice does not do anything
        vm.record();

        game.performUpkeep(abi.encode(1 << 2));

        (, writes) = vm.accesses(address(game));
        assertEq(writes.length, 0);

        // upkeep 5
        game.performUpkeep(abi.encode(1 << 5));

        // checkUpkeep should be false after perform
        (upkeepNeeded, data) = game.checkUpkeep("");
        assertFalse(upkeepNeeded);
        assertEq(abi.decode(data, (uint256)), 0);

        // waiting for 1 minute without confirming VRF call should reset request status
        skip(5 minutes + 1);

        (upkeepNeeded, data) = game.checkUpkeep("");
        assertTrue(upkeepNeeded);
        assertEq(abi.decode(data, (uint256)), (1 << 2) | (1 << 5));
    }

    /* ------------- fullfillRandomWords() ------------- */

    function test_fullfillRandomWords() public {
        bool upkeepNeeded;
        bytes memory data;

        vm.prank(bob);
        game.baronDeclareAttack(1, 2, 1001);

        vm.prank(bob);
        game.baronDeclareAttack(4, 5, 1004);

        skip(TIME_REINFORCEMENTS + TIME_GANG_WAR);

        (upkeepNeeded, data) = game.checkUpkeep("");

        game.performUpkeep(data);

        // assertions
        DistrictView memory district2;
        DistrictView memory district5;

        district2 = game.getDistrictView(2);
        district5 = game.getDistrictView(5);

        assertEq(district2.state, DISTRICT_STATE.POST_GANG_WAR);
        assertEq(district5.state, DISTRICT_STATE.POST_GANG_WAR);
        assertEq(district2.roundId, 1); // starts at 1
        assertEq(district5.roundId, 1);
        assertEq(district2.lastUpkeepTime, block.timestamp);
        assertEq(district5.lastUpkeepTime, block.timestamp);
        assertEq(district2.lastOutcomeTime, 0);
        assertEq(district5.lastOutcomeTime, 0);
        assertEq(game.getGangWarOutcome(2, 1), 0);
        assertEq(game.getGangWarOutcome(5, 1), 0);

        // upkeepNeeded should be false now
        (upkeepNeeded, data) = game.checkUpkeep("");
        // uint256[] memory ids = abi.decode(data, (uint256[]));

        assertFalse(upkeepNeeded);
        // assertEq(ids.length, 0);

        uint256 requestId = coordinator.requestIdCounter();

        vm.prank(address(coordinator));
        game.rawFulfillRandomWords(requestId, [1234].toMemory());

        district2 = game.getDistrictView(2);
        district5 = game.getDistrictView(5);

        assertEq(district2.state, DISTRICT_STATE.TRUCE);
        assertEq(district5.state, DISTRICT_STATE.TRUCE);
        assertEq(district2.roundId, 2);
        assertEq(district5.roundId, 2);
        assertEq(district2.lastOutcomeTime, block.timestamp);
        assertEq(district5.lastOutcomeTime, block.timestamp);
        assertTrue(game.getGangWarOutcome(2, 1) > 0);
        assertTrue(game.getGangWarOutcome(5, 1) > 0);

        // check district state

        // upkeep should remain false, even after 1 additional minute
        skip(1 minutes + 1);
        (upkeepNeeded, data) = game.checkUpkeep("");
        uint256[] memory ids = abi.decode(data, (uint256[]));

        assertFalse(upkeepNeeded);
        assertEq(ids.length, 0);
    }
}

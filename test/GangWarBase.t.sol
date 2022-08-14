// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// base
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import "/GangWar.sol";
import "/tokens/GangToken.sol";
import {Deploy} from "../script/Deploy.s.sol";

// utils
import "f-utils/fUtils.sol";
import "/lib/PackedMap.sol";
import "./utils.sol";

// mock
import {MockVRFCoordinator} from "./mocks/MockVRFCoordinator.sol";
import "solmate/test/utils/mocks/MockERC721.sol";

contract TestGangWar is Test, Deploy {
    using fUtils for *;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    // MockVRFCoordinator coordinator = new MockVRFCoordinator();
    // GangWar impl = new GangWar(address(coordinator), 0, 0, 0, 0);
    // GangWar game;
    // MockERC721 gmc;

    // bool[21][21] connections;

    uint256 constant GANGSTER_YAKUZA_1 = 1;
    uint256 constant GANGSTER_CARTEL_1 = 2;
    uint256 constant GANGSTER_CYBERP_1 = 3;
    uint256 constant GANGSTER_YAKUZA_2 = 4;
    uint256 constant GANGSTER_CARTEL_2 = 5;
    uint256 constant GANGSTER_CYBERP_2 = 6;

    uint256 constant BARON_YAKUZA_1 = 10_001;
    uint256 constant BARON_CARTEL_1 = 10_002;
    uint256 constant BARON_CYBERP_1 = 10_003;
    uint256 constant BARON_YAKUZA_2 = 10_004;
    uint256 constant BARON_CARTEL_2 = 10_005;
    uint256 constant BARON_CYBERP_2 = 10_006;

    uint256 constant DISTRICT_YAKUZA_1 = 2;
    uint256 constant DISTRICT_CARTEL_1 = 0;
    uint256 constant DISTRICT_CYBERP_1 = 7;
    uint256 constant DISTRICT_YAKUZA_2 = 3;
    uint256 constant DISTRICT_CARTEL_2 = 10;
    uint256 constant DISTRICT_CYBERP_2 = 4;

    function setUp() public {
        deployAndSetupGangWar();

        gmc.mint(alice, GANGSTER_YAKUZA_1);
        gmc.mint(alice, GANGSTER_CARTEL_1);
        gmc.mint(alice, GANGSTER_CYBERP_1);
        gmc.mint(alice, GANGSTER_YAKUZA_2);
        gmc.mint(alice, GANGSTER_CARTEL_2);
        gmc.mint(alice, GANGSTER_CYBERP_2);

        gmc.mint(bob, BARON_YAKUZA_1);
        gmc.mint(bob, BARON_CARTEL_1);
        gmc.mint(bob, BARON_CYBERP_1);
        gmc.mint(bob, BARON_YAKUZA_2);
        gmc.mint(bob, BARON_CARTEL_2);
        gmc.mint(bob, BARON_CYBERP_2);

        gouda.mint(bob, 100e18);
        vm.prank(bob);
        gouda.approve(address(game), type(uint256).max);

        vm.warp(100000);
        vm.roll(100000);
    }

    function assertEq(Gang a, Gang b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(PLAYER_STATE a, PLAYER_STATE b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(DISTRICT_STATE a, DISTRICT_STATE b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function test_setUp() public {
        uint256 packedConnections = game.getDistrictConnections();

        for (uint256 i; i < 21; i++) {
            for (uint256 j; j < 21; j++) {
                (uint256 a, uint256 b) = (i < j) ? (i, j) : (j, i);
                assertEq(connections[a + 1][b + 1], PackedMap.isConnecting(packedConnections, i, j));
            }
        }

        for (uint256 i; i < 21; i++) {
            DistrictView memory district = game.getDistrictView(i);

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

        uint256[3][3] memory yield = game.getYield();

        assertTrue(yield[0][0] > 0);
        assertEq(yield[0][0], yield[1][1]);
        assertEq(yield[0][0], yield[2][2]);

        assertEq(DIAMOND_STORAGE_GANG_WAR, keccak256("diamond.storage.gang.war"));
    }
}

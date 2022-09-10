// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// base
import "/GangWar.sol";
import {GangToken} from "/tokens/GangToken.sol";
import {SetupChild} from "../src/SetupChild.sol";
// import {GangWarSetup} from "../src/Setup.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

// utils
import "futils/futils.sol";
import "/lib/LibPackedMap.sol";

// mock
import {MockVRFCoordinator} from "./mocks/MockVRFCoordinator.sol";
import "solmate/test/utils/mocks/MockERC721.sol";

contract TestGangWar is Test, SetupChild {
    using futils for *;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address eve = makeAddr("eve");

    address tester = address(this);

    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_BYPASS = true;
    }

    function setUp() public virtual {
        setUpContracts();
        initContracts();

        vm.label(tester, "tester");

        badges.grantRole(AUTHORITY, tester);
        tokens[0].grantRole(AUTHORITY, tester);
        tokens[1].grantRole(AUTHORITY, tester);
        tokens[2].grantRole(AUTHORITY, tester);

        vault.grantRole(GANG_VAULT_CONTROLLER, address(this));

        gmc.mint(alice, GANGSTER_YAKUZA_1);
        gmc.mint(alice, GANGSTER_CARTEL_1);
        gmc.mint(alice, GANGSTER_CYBERP_1);
        gmc.mint(alice, GANGSTER_YAKUZA_2);
        gmc.mint(alice, GANGSTER_CARTEL_2);
        gmc.mint(alice, GANGSTER_CYBERP_2);
        gmc.mint(eve, GANGSTER_YAKUZA_3);
        gmc.mint(eve, GANGSTER_CARTEL_3);
        gmc.mint(eve, GANGSTER_CYBERP_3);

        gmc.mint(bob, BARON_YAKUZA_1);
        gmc.mint(bob, BARON_CARTEL_1);
        gmc.mint(bob, BARON_CYBERP_1);
        gmc.mint(bob, BARON_YAKUZA_2);
        gmc.mint(bob, BARON_CARTEL_2);
        gmc.mint(bob, BARON_CYBERP_2);

        gouda.grantRole(AUTHORITY, address(this));

        gouda.mint(bob, 100e18);

        vm.prank(bob);
        gouda.approve(address(game), type(uint256).max);
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

    function test_setUp() public virtual {
        uint256 packedConnections = game.getDistrictConnections();

        for (uint256 i; i < 21; i++) {
            for (uint256 j; j < 21; j++) {
                (uint256 a, uint256 b) = (i < j) ? (i, j) : (j, i);
                assertEq(connections[a][b], LibPackedMap.isConnecting(packedConnections, i, j));
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

        assertEq(DIAMOND_STORAGE_GANG_WAR, keccak256("diamond.storage.gang.war"));
    }
}

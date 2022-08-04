// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import {MockVRFCoordinatorV2} from "./mocks/MockVRFCoordinator.sol";

import "/lib/ArrayUtils.sol";
import "/lib/PackedMap.sol";
import "/GangWar.sol";
import {Deploy} from "../script/Deploy.s.sol";

import "./utils.sol";

contract TestGangWar is Test, Deploy {
    using ArrayUtils for *;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    MockVRFCoordinatorV2 coordinator = new MockVRFCoordinatorV2();
    GangWar impl = new GangWar(address(coordinator), 0, 0, 0, 0);
    GangWar game;
    MockERC721 gmc;

    // bool[21][21] connections;

    function setUp() public {
        gmc = new MockERC721("GMC", "GMC");

        // Gang[21] memory occupants;
        // for (uint256 i; i < 21; i++) occupants[i] = Gang((i + 2) % 3);

        // uint256[21] memory yields;
        // for (uint256 i; i < 21; i++) yields[i] = 100 + (i / 3) * 100;

        address[3] memory tokens;
        tokens[0] = address(new MockERC20("Token", "", 18));
        tokens[1] = address(new MockERC20("Token", "", 18));
        tokens[2] = address(new MockERC20("Token", "", 18));

        address badges = address(new MockERC20("Badges", "", 18));

        (uint256 connections, uint256[21] memory occupants, uint256[21] memory yields) = initData();
        // bytes memory initCall = abi.encodeCall(game.init, (address(gmc), tokens, badges, occupants, yields));

        bytes memory initCallData = abi.encodeWithSelector(
            GangWar.init.selector,
            gmc,
            tokens,
            badges,
            connections,
            occupants,
            yields
        );

        game = GangWar(address(new ERC1967Proxy(address(impl), initCallData)));

        // game.setDistrictConnections(PackedMap.encode(connections));

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

    function assertEq(Gang a, Gang b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(PLAYER_STATE a, PLAYER_STATE b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(DISTRICT_STATE a, DISTRICT_STATE b) internal {
        assertEq(uint8(a), uint8(b));
    }

    // function test_setUp() public {
    //     uint256 packedConnections = game.getDistrictConnections();

    //     for (uint256 i; i < 21; i++) {
    //         for (uint256 j; j < 21; j++) {
    //             (uint256 a, uint256 b) = (i < j) ? (i, j) : (j, i);
    //             assertEq(connections[a][b], PackedMap.isConnecting(packedConnections, i, j));
    //         }
    //     }

    //     for (uint256 i; i < 21; i++) {
    //         District memory district = game.getDistrict(i);

    //         assertEq(district.occupants, Gang((i + 2) % 3));
    //         assertEq(district.roundId, 1);
    //         assertEq(district.attackDeclarationTime, 0);
    //         assertEq(district.baronAttackId, 0);
    //         assertEq(district.baronDefenseId, 0);
    //         assertEq(district.lastUpkeepTime, 0);
    //         assertEq(district.lockupTime, 0);
    //     }

    //     assertEq(game.gangOf(1), Gang.YAKUZA);
    //     assertEq(game.gangOf(1001), Gang.YAKUZA);

    //     assertEq(game.getGangsterView(1).state, PLAYER_STATE.IDLE);
    //     assertEq(game.getGangsterView(1001).state, PLAYER_STATE.IDLE);

    //     uint256[3][3] memory yield = game.getYield();

    //     assertTrue(yield[0][0] > 0);
    //     assertEq(yield[0][0], yield[1][1]);
    //     assertEq(yield[0][0], yield[2][2]);
    // }
}

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

contract TestGangWar is Test {
    using ArrayUtils for *;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address tester = address(this);

    MockVRFCoordinatorV2 coordinator = new MockVRFCoordinatorV2();
    GangWar impl = new GangWar(address(coordinator), 0, 0, 0, 0);
    GangWar game;
    MockERC721 gmc;

    bool[21][21] connections;

    function setUp() public {
        gmc = new MockERC721("GMC", "GMC");

        Gang[21] memory initialDistrictOwners;
        for (uint256 i; i < 21; i++) initialDistrictOwners[i] = Gang((i + 2) % 3);

        uint256[21] memory yields;
        for (uint256 i; i < 21; i++) yields[i] = 100 + (i / 3) * 100;

        address[3] memory gangTokens;
        gangTokens[0] = address(new MockERC20("Token", "", 18));
        gangTokens[1] = address(new MockERC20("Token", "", 18));
        gangTokens[2] = address(new MockERC20("Token", "", 18));

        address badges = address(new MockERC20("Badges", "", 18));

        bytes memory initCall = abi.encodeCall(
            game.init,
            (address(gmc), gangTokens, badges, initialDistrictOwners, yields)
        );
        game = GangWar(address(new ERC1967Proxy(address(impl), initCall)));

        connections[0][1] = true;
        connections[1][2] = true;
        connections[2][3] = true;
        connections[3][4] = true;
        connections[0][3] = true;
        connections[1][4] = true;
        connections[1][5] = true;
        connections[1][6] = true;
        connections[3][4] = true;
        connections[4][5] = true;
        connections[6][7] = true;
        connections[7][8] = true;

        game.setDistrictConnections(PackedMap.encode(connections));

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
}

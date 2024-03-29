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
    address self = address(this);
    address bob = makeAddr("bob");
    address eve = makeAddr("eve");

    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_BYPASS = true;
    }

    function setUp() public virtual {
        setUpContracts();

        vm.label(self, "self");

        uint40 seasonStart = uint40(block.timestamp);
        uint40 seasonEnd = uint40(block.timestamp + 4 weeks);

        badges.grantRole(AUTHORITY, self);
        tokens[0].grantRole(AUTHORITY, self);
        tokens[1].grantRole(AUTHORITY, self);
        tokens[2].grantRole(AUTHORITY, self);

        vault.grantRole(GANG_VAULT_CONTROLLER, address(this));

        game.setSeason(seasonStart, seasonEnd, true);

        gmc.resyncId(alice, GANGSTER_YAKUZA_1);
        gmc.resyncId(alice, GANGSTER_CARTEL_1);
        gmc.resyncId(alice, GANGSTER_CYBERP_1);
        gmc.resyncId(alice, GANGSTER_YAKUZA_2);
        gmc.resyncId(alice, GANGSTER_CARTEL_2);
        gmc.resyncId(alice, GANGSTER_CYBERP_2);
        gmc.resyncId(eve, GANGSTER_YAKUZA_3);
        gmc.resyncId(eve, GANGSTER_CARTEL_3);
        gmc.resyncId(eve, GANGSTER_CYBERP_3);

        gmc.resyncId(bob, BARON_YAKUZA_1);
        gmc.resyncId(bob, BARON_CARTEL_1);
        gmc.resyncId(bob, BARON_CYBERP_1);
        gmc.resyncId(bob, BARON_YAKUZA_2);
        gmc.resyncId(bob, BARON_CARTEL_2);
        gmc.resyncId(bob, BARON_CYBERP_2);

        gouda.grantRole(AUTHORITY, address(this));

        gouda.mint(bob, 100e18);

        vm.prank(bob);
        gouda.approve(address(game), type(uint256).max);

        // need to set gangs explicitly
        // doesn't work for demo contract
        try gmc.setGangsInChunks(0, 0) {
            uint256 chunkData;
            uint256 id;
            for (uint256 c; c < 70; ++c) {
                for (uint256 i; i < 128; ++i) {
                    id = (c << 7) + i + 1;
                    uint256 gang = 1 + ((id + 2) % 3);
                    chunkData |= gang << (i << 1);
                }

                gmc.setGangsInChunks(c, chunkData);

                if (id > 6666) break;
            }
        } catch {}
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

// contract TestGangWarRoot is Test, SetupRoot {
//     using futils for *;

//     address alice = makeAddr("alice");
//     address self = address(this);
//     address bob = makeAddr("bob");
//     address eve = makeAddr("eve");

//     function setUpUpgradeScripts() internal override {
//         UPGRADE_SCRIPTS_BYPASS = true;
//     }

//     function setUp() public virtual {
//         setUpContracts();

//         vm.label(self, "self");
//     }
// }

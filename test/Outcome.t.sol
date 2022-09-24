// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/utils/LibString.sol";

import "futils/futils.sol";
import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "/GangWar.sol";

contract TestGangWarOutcome is Test {
    using futils for *;
    using LibString for uint256;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address chris = address(0xc215);
    address tester = address(this);

    // GangWar impl = new GangWar();
    // GangWar game;

    function setUp() public {
        // bytes memory initCall = abi.encodeWithSelector(game.init.selector, ERC721UDS(address(0)));
        // game = GangWar(address(new ERC1967Proxy(address(impl), initCall)));
    }

    function assertEq(Gang a, Gang b) internal {
        assertEq(uint8(a), uint8(b));
    }

    function assertEq(PLAYER_STATE a, PLAYER_STATE b) internal {
        assertEq(uint8(a), uint8(b));
    }

    /* ------------- gangWarWonProbFFI() ------------- */

    // function test_gangWarWonProbFFI(
    //     uint256 attackForce,
    //     uint256 defenseForce,
    //     bool baronDefense
    // ) internal {
    //     vm.assume(attackForce < 10_000);
    //     vm.assume(defenseForce < 10_000);

    //     string[] memory inputs = new string[](8);
    //     inputs[0] = "python3";
    //     inputs[1] = "src/test/external/gang_war_outcome.py";
    //     inputs[2] = "--attack_force";
    //     inputs[3] = attackForce.toString();
    //     inputs[4] = "--defense_force";
    //     inputs[5] = defenseForce.toString();
    //     inputs[6] = "--baron_defense";
    //     inputs[7] = baronDefense ? uint256(1).toString() : uint256(0).toString();

    //     bytes memory result = vm.ffi(inputs);
    //     uint256 res = abi.decode(result, (uint256));

    //     uint256 p = gangWarWonProbFn(attackForce, defenseForce, baronDefense);
    //     assertEq((p * 1e12) >> 128, (res * 1e12) >> 128);
    // }

    // TODO args=[150, 229, false]]
    function test_gangWarWonProbProperties(
        uint256 attackForce,
        uint256 defenseForce,
        bool baronDefense
    ) public {
        attackForce = bound(attackForce, 0, 10_000);
        defenseForce = bound(defenseForce, 0, 10_000);

        uint256 p = gangWarWonProbFn(attackForce, defenseForce, baronDefense);

        // in valid range [0, 128]
        assertTrue(p < 1 << 128);

        if (attackForce > DEFENSE_FAVOR_LIM) {
            if (defenseForce < attackForce) {
                // should be in favor of attackers (> 50%)
                assertTrue(p > 1 << 127);
            }
        } else {
            // not exactly the cutoff...
            if (attackForce + 100 < defenseForce) {
                // should be in favor of defenders (< 50%)
                assertTrue(p < 1 << 127);
            }
        }
    }

    // function test_gangWarWonProbProperties() public {
    //     uint256 attackForce = 5;
    //     uint256 defenseForce = 5;
    //     bool baronDefense = false;

    //     uint256 p = gangWarWonProbFn(attackForce, defenseForce, baronDefense);

    //     console.log((p * 10000) >> 128);
    // }

    function test_isInjuredProperties(
        uint256 attackForce,
        uint256 defenseForce,
        bool baronDefense
    ) public {
        attackForce = bound(attackForce, 0, 10_000);
        defenseForce = bound(attackForce, 0, 10_000);

        uint256 gP = gangWarWonProbFn(attackForce, defenseForce, baronDefense);

        uint256 pInjuredWon = isInjuredProbFn(gP, true);
        uint256 pInjuredLost = isInjuredProbFn(gP, false);

        // in valid range [0, 128]
        assertTrue(pInjuredWon < 1 << 128);
        assertTrue(pInjuredLost < 1 << 128);

        assertTrue(pInjuredWon < ((1 << 128) * 100) / INJURED_WON_FACTOR);
        assertTrue(pInjuredLost < ((1 << 128) * 100) / INJURED_LOST_FACTOR);

        assertTrue(pInjuredWon <= pInjuredLost);
    }

    // function test_gangWarWon(
    //     uint256 attackForce,
    //     uint256 defenseForce,
    //     bool baronDefense
    // ) public {
    //     vm.assume(attackForce < 10_000);
    //     vm.assume(defenseForce < 10_000);

    //     uint256 prob1 = game.gangWarWonProbFn(attackForce, defenseForce, baronDefense);
    //     uint256 prob2 = game.gangWarWonProb2(attackForce, defenseForce, baronDefense);

    //     assertEq(prob1, prob2);
    // }

    // function test_gangWarWonProbFn() public {
    //     test_gangWarWonProbProperties(94, 95, false);
    // }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/utils/LibString.sol";

import "/lib/ArrayUtils.sol";
import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "/GangWar.sol";

contract TestGangWarOutcome is Test {
    using ArrayUtils for *;
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

    function test_gangWarWonProbFFI(
        uint256 attackForce,
        uint256 defenseForce,
        bool baronDefense
    ) internal {
        vm.assume(attackForce < 10_000);
        vm.assume(defenseForce < 10_000);

        string[] memory inputs = new string[](8);
        inputs[0] = "python3";
        inputs[1] = "contracts/test/gang_war_outcome.py";
        inputs[2] = "--attack_force";
        inputs[3] = attackForce.toString();
        inputs[4] = "--defense_force";
        inputs[5] = defenseForce.toString();
        inputs[6] = "--baron_defense";
        inputs[7] = baronDefense ? uint256(1).toString() : uint256(0).toString();

        bytes memory result = vm.ffi(inputs);
        uint256 res = abi.decode(result, (uint256));

        uint256 prob = gangWarWonProb(attackForce, defenseForce, baronDefense);
        assertEq((prob * 1e12) >> 128, (res * 1e12) >> 128);
    }

    function test_gangWarWonProbProperties(
        uint16 attackForce,
        uint16 defenseForce,
        bool baronDefense
    ) public {
        vm.assume(attackForce < 10_000);
        vm.assume(defenseForce < 10_000);

        uint256 prob = gangWarWonProb(attackForce, defenseForce, baronDefense);

        // in valid range [0, 128]
        assertTrue(prob < 1 << 128);

        if (attackForce > 150) {
            if (defenseForce < attackForce) {
                // should be in favor of attackers (> 50%)
                assertTrue(prob > 1 << 127);
            }
        } else {
            if (attackForce < defenseForce) {
                // should be in favor of defenders (< 50%)
                assertTrue(prob < 1 << 127);
            }
        }
    }

    // function test_gangWarWon(
    //     uint256 attackForce,
    //     uint256 defenseForce,
    //     bool baronDefense
    // ) public {
    //     vm.assume(attackForce < 10_000);
    //     vm.assume(defenseForce < 10_000);

    //     uint256 prob1 = game.gangWarWonProb(attackForce, defenseForce, baronDefense);
    //     uint256 prob2 = game.gangWarWonProb2(attackForce, defenseForce, baronDefense);

    //     assertEq(prob1, prob2);
    // }

    // function test_gangWarWonProb() public {
    //     test_gangWarWonProbProperties(94, 95, false);
    // }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/test/utils/LibString.sol";

import "../lib/ArrayUtils.sol";
import {ERC721UDS} from "UDS/ERC721UDS.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967VersionedUDS.sol";

import "../GangWar.sol";

contract TestGangWar is Test {
    using ArrayUtils for *;
    using LibString for uint256;

    address bob = address(0xb0b);
    address alice = address(0xbabe);
    address chris = address(0xc215);
    address tester = address(this);

    GangWar impl = new GangWar();

    function setUp() public {}

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

    /* ------------- gangWarWonProbFFI() ------------- */

    function test_gangWarWonProbFFI() public {
        // uint256 attackForce,
        // uint256 defenseForce,
        // bool baronDefense
        // ) public {

        uint256 attackForce = 100;
        uint256 defenseForce = 100;
        bool baronDefense = true;

        string[] memory inputs = new string[](2);
        inputs[0] = "python";
        inputs[1] = "contracts/test/gang_war_outcome.py";
        inputs[2] = "--attack_force";
        inputs[3] = attackForce.toString();
        inputs[4] = "--defense_force";
        inputs[5] = defenseForce.toString();
        bytes memory result = vm.ffi(inputs);
        string memory res = abi.decode(result, (string));
        console.log(res);

        // impl.gangWarWonProb(attackForce, defenseForce, baronDefense);
    }
}

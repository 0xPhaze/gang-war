// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/utils/LibString.sol";

import "/lib/PackedMap.sol";

contract TestEncoding is Test {
    using PackedMap for *;

    function assertEq(bool[10][10] memory a, bool[10][10] memory b) internal {
        for (uint256 i; i < 10; i++) {
            for (uint256 j; j < 10; j++) {
                assertEq(a[i][j], b[i][j]);
            }
        }
    }

    function assertEq(bool[21][21] memory a, bool[21][21] memory b) internal {
        for (uint256 i; i < 21; i++) {
            for (uint256 j; j < 21; j++) {
                assertEq(a[i][j], b[i][j]);
            }
        }
    }

    function assertUpperTriangleMatrix(bool[10][10] memory map) public pure {
        for (uint256 i; i < 10; i++) {
            for (uint256 j; j < i + 1; j++) {
                require(!map[i][j], "lower triangle must be 0.");
            }
        }
    }

    function assertUpperTriangleMatrix(bool[21][21] memory map) public pure {
        for (uint256 i; i < 21; i++) {
            for (uint256 j; j < i + 1; j++) {
                require(!map[i][j], "lower triangle must be 0.");
            }
        }
    }

    /* ------------- encode() ------------- */

    function test_encode() public {
        bool[10][10] memory map;

        assertEq(map.encode(), 0);

        map[0][1] = true;

        assertEq(map.encode(), 1);

        map[0][2] = true;

        assertEq(map.encode(), 3);

        for (uint256 i; i < 10; i++) {
            for (uint256 j; j < 10; j++) {
                map[i][j] = true;
            }
        }

        assertEq(map.encode(), (1 << 45) - 1); // all 44 bits set to true
    }

    function test_encode10(bool[10][10] memory map) public {
        for (uint256 i; i < 10; i++) {
            for (uint256 j; j <= i; j++) {
                map[i][j] = false;
            }
        }
        assertUpperTriangleMatrix(map);
        assertEq(map.encode().decode10(), map);
    }

    function test_encode21(bool[21][21] memory map) public {
        for (uint256 i; i < 21; i++) {
            for (uint256 j; j <= i; j++) {
                map[i][j] = false;
            }
        }
        assertUpperTriangleMatrix(map);
        assertEq(map.encode().decode21(), map);
    }
}

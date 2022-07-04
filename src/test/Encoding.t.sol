// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/utils/LibString.sol";

import "../lib/ArrayUtils.sol";
import {ERC721UDS} from "UDS/ERC721UDS.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967VersionedUDS.sol";

import "../GangWar.sol";

/*
n = 10

enc = 10 * i + j - ((i + 1)^2 + (i + 1)) / 2

ij  0  1  2  3  4  5  6  7  8  9
0   \  0  1  2  3  4  5  6  7  8
1      \  9 10 11 12 13 14 15 16
2         \ 17 18 19 20 21 22 23
3            \ 24 25 26 27 28 29
4               \ 30 31 32 33 34
5                  \ 35 36 37 38
6                     \ 39 40 41
7                        \ 42 43
8                           \ 44
9                              \
*/

/// 10 * 10 - 1 - 10 * 11 / 2 = 44 bits
function encode(bool[10][10] memory map) pure returns (uint256 out) {
    for (uint256 i; i < 10; i++) {
        for (uint256 j = i + 1; j < 10; j++) {
            out |= uint256(map[i][j] ? 1 : 0) << (i * 10 + j - ((i + 1) * (i + 2)) / 2);
        }
    }
}

function decode10(uint256 enc) pure returns (bool[10][10] memory out) {
    for (uint256 i; i < 10; i++) {
        for (uint256 j = i + 1; j < 10; j++) {
            out[i][j] = (enc >> (i * 10 + j - ((i + 1) * (i + 2)) / 2)) & 1 != 0;
        }
    }
}

/// 21 uses 21 * 21 - 1 - 21 * 22 / 2 = 209 bits
/// 23 (252 bits) is the maximum
function encode(bool[21][21] memory map) pure returns (uint256 out) {
    for (uint256 i; i < 21; i++) {
        for (uint256 j = i + 1; j < 21; j++) {
            out |= uint256(map[i][j] ? 1 : 0) << (i * 21 + j - ((i + 1) * (i + 2)) / 2);
        }
    }
}

function decode21(uint256 enc) pure returns (bool[21][21] memory out) {
    for (uint256 i; i < 21; i++) {
        for (uint256 j = i + 1; j < 21; j++) {
            out[i][j] = (enc >> (i * 21 + j - ((i + 1) * (i + 2)) / 2)) & 1 != 0;
        }
    }
}

function isConnecting(
    uint256 enc,
    uint256 a,
    uint256 b
) pure returns (bool) {
    if (a < b) (a, b) = (b, a);
    return a == b || (enc >> (a * 21 + b - ((a + 1) * (a + 2)) / 2)) & 1 != 0;
}

contract TestEncoding is Test {
    using ArrayUtils for *;

    function setUp() public {}

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

    /* ------------- encode() ------------- */

    function test_encode() public {
        bool[10][10] memory map;

        assertEq(encode(map), 0);

        map[0][1] = true;

        assertEq(encode(map), 1);

        map[0][2] = true;

        assertEq(encode(map), 3);

        for (uint256 i; i < 10; i++) {
            for (uint256 j = i + 1; j < 10; j++) {
                map[i][j] = true;
            }
        }

        assertEq(encode(map), (1 << 45) - 1); // all 44 bits set to true
    }

    function test_fuzz_encode10(bool[10][10] memory map) public {
        for (uint256 i; i < 10; i++) {
            for (uint256 j; j <= i; j++) {
                map[i][j] = false;
            }
        }
        assertEq(decode10(encode(map)), map);
    }

    function test_fuzz_encode21(bool[21][21] memory map) public {
        for (uint256 i; i < 21; i++) {
            for (uint256 j; j <= i; j++) {
                map[i][j] = false;
            }
        }
        assertEq(decode21(encode(map)), map);
    }
}

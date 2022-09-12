// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Library for Packed Boolean Mappings
 * @author phaze (https://github.com/0xPhaze)
 * @dev Example (n=10):
 *
 *   enc = 10 * i + j - ((i + 1)^2 + (i + 1)) / 2
 *
 *   ij  0  1  2  3  4  5  6  7  8  9
 *   0   \  0  1  2  3  4  5  6  7  8
 *   1      \  9 10 11 12 13 14 15 16
 *   2         \ 17 18 19 20 21 22 23
 *   3            \ 24 25 26 27 28 29
 *   4               \ 30 31 32 33 34
 *   5                  \ 35 36 37 38
 *   6                     \ 39 40 41
 *   7                        \ 42 43
 *   8                           \ 44
 *   9                              \
 *
 *   Bitcount:
 *
 *   n = 10 uses: 10 * 10 - 1 - 10 * 11 / 2 = 44 bits
 *   n = 21 uses: 21 * 21 - 1 - 21 * 22 / 2 = 209 bits
 *   n = 23 is the maximum to fit in a uint256:
 *       23 * 23 - 1 - 23 * 24 / 2 = 252 bits
 **/
library LibPackedMap {
    function encode(bool[10][10] memory map) internal pure returns (uint256 out) {
        unchecked {
            for (uint256 i; i < 10; i++) {
                for (uint256 j = i + 1; j < 10; j++) {
                    out |= uint256(map[i][j] ? 1 : 0) << (i * 10 + j - ((i + 1) * (i + 2)) / 2);
                }
            }
        }
    }

    function decode10(uint256 enc) internal pure returns (bool[10][10] memory out) {
        unchecked {
            for (uint256 i; i < 10; i++) {
                for (uint256 j = i + 1; j < 10; j++) {
                    out[i][j] = (enc >> (i * 10 + j - ((i + 1) * (i + 2)) / 2)) & 1 != 0;
                }
            }
        }
    }

    function encode(bool[21][21] memory map) internal pure returns (uint256 out) {
        unchecked {
            for (uint256 i; i < 21; i++) {
                for (uint256 j = i + 1; j < 21; j++) {
                    out |= uint256(map[i][j] ? 1 : 0) << (i * 21 + j - ((i + 1) * (i + 2)) / 2);
                }
            }
        }
    }

    function decode21(uint256 enc) internal pure returns (bool[21][21] memory out) {
        unchecked {
            for (uint256 i; i < 21; i++) {
                for (uint256 j = i + 1; j < 21; j++) {
                    out[i][j] = isConnecting(enc, i, j);
                }
            }
        }
    }

    function isConnecting(
        uint256 enc,
        uint256 a,
        uint256 b
    ) internal pure returns (bool) {
        if (a > b) (a, b) = (b, a);
        return (a != b) && (enc >> (a * 21 + b - ((a + 1) * (a + 2)) / 2)) & 1 != 0;
    }
}

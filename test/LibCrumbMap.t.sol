// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "/lib/LibCrumbMap.sol";

contract TestLibCrumbMap is Test {
    using LibCrumbMap for LibCrumbMap.CrumbMap;

    LibCrumbMap.CrumbMap crumbMap;

    /* ------------- set() ------------- */

    function test_set() public {
        for (uint256 b; b < 3; b++) {
            uint256 data;

            for (uint256 i; i < 128; i++) {
                data |= (1 + ((b * 128 + i) % 3)) << (i << 1);
            }

            crumbMap.set32BytesChunk(b, data);

            assertEq(crumbMap.get32BytesChunk(b), data);

            for (uint256 i; i < 128; i++) {
                assertEq(crumbMap.get(b * 128 + i), 1 + ((b * 128 + i) % 3));
            }
        }
    }

    function test_set(uint256 index, uint8 crumbData, uint256 chunkData) public {
        uint256 data = bound(crumbData, 0, 3);

        crumbMap.set32BytesChunk(index >> 7, chunkData);
        crumbMap.set(index, data);

        uint256 crumbShift = (index & 0x7f) << 1;
        uint256 calculated = chunkData & (~uint256(0x03 << crumbShift));
        calculated |= data << crumbShift;

        assertEq(crumbMap.get32BytesChunk(index >> 7), calculated);
    }

    function test_set32BytesChunk(uint256 index, uint256 data) public {
        vm.assume(index < type(uint256).max >> 7);

        crumbMap.set32BytesChunk(index, data);

        uint256 recovered;

        for (uint256 i; i < 128; i++) {
            recovered |= crumbMap.get(128 * index + i) << (i << 1);
        }

        assertEq(recovered, data);
    }
}

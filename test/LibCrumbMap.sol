// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "/lib/LibCrumbMap.sol";

contract TestLibCrumbMap is Test {
    using LibCrumbMap for LibCrumbMap.CrumbMap;

    LibCrumbMap.CrumbMap crumbMap;

    /* ------------- encode() ------------- */

    // function test_setBytes1() public {
    //     uint256 recovered;
    //     uint256 data = (0x03 << 1) | (0xaabbcc << 8) | 1;

    //     // for (uint256 i; i < 128; i++) {
    //     //     uint256 crumb = (data >> (i << 1)) & 0x03;
    //     //     recovered |= crumb << (i << 1);
    //     // }

    //     console.logBytes32(bytes32(data));

    //     // data &= ~uint256(0x03 << 9);

    //     console.logBytes32(bytes32(data));

    //     // console.log("recovered", recovered);

    //     // assertEq(recovered, data);
    // }

    function test_set(
        uint256 index,
        uint8 crumbData,
        uint256 chunkData
    ) public {
        uint256 data = bound(crumbData, 0, 3);

        crumbMap.setBytes(index >> 7, chunkData);
        crumbMap.set(index, data);

        uint256 crumbShift = (index & 0x7f) << 1;
        uint256 calculated = chunkData & (~uint256(0x03 << crumbShift));
        calculated |= data << crumbShift;

        assertEq(crumbMap.getBytes(index >> 7), calculated);
    }

    function test_setBytes(uint256 index, uint256 data) public {
        vm.assume(index < type(uint256).max >> 7);

        crumbMap.setBytes(index, data);

        uint256 recovered;

        for (uint256 i; i < 128; i++) {
            recovered |= crumbMap.get(128 * index + i) << (i << 1);
        }

        assertEq(recovered, data);
    }
}

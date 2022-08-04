// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "/lib/EnumerableSet.sol";

contract TestEnumerableSet is Test {
    using LibEnumerableSet for AddressSet;

    AddressSet set;
    address[] _setValues;

    function indexOf(address value) internal view returns (uint256) {
        for (uint256 i; i < _setValues.length; i++) if (_setValues[i] == value) return i;
        return type(uint256).max;
    }

    function setIncludes(address value) internal view returns (bool) {
        return indexOf(value) != type(uint256).max;
    }

    function assertTrueSetIncludes(address value) internal {
        if (!setIncludes(value)) fail("Set does not include value");
    }

    function assertFalseSetIncludes(address value) internal {
        if (setIncludes(value)) fail("Set does not include value");
    }

    function assertEq(AddressSet storage set_, address[] storage values) internal {
        assertEq(set_.length(), values.length);

        for (uint256 i; i < values.length; i++) {
            assertTrue(set_.includes(values[i]));
        }
    }

    /* ------------- add() ------------- */

    function test_add(address value) public {
        bool includes = set.includes(value);
        bool added = set.add(value);

        assertEq(added, !includes);
        assertTrue(set.includes(value));

        // mirror
        assertEq(includes, setIncludes(value));
        if (!includes) _setValues.push(value);
        assertTrueSetIncludes(value);
    }

    function test_rem(address value) public {
        bool includes = set.includes(value);
        bool removed = set.remove(value);

        assertEq(removed, includes);
        assertFalse(set.includes(value));

        // mirror
        assertEq(includes, setIncludes(value));
        if (includes) {
            _setValues[indexOf(value)] = _setValues[_setValues.length - 1];
            _setValues.pop();
        }
        assertFalseSetIncludes(value);
    }

    function test_add_remove() public {
        test_rem(address(3));
        test_add(address(1));
        test_add(address(2));
        test_add(address(3));
        test_rem(address(3));
        test_add(address(2));
        test_rem(address(4));
        test_add(address(2));
        test_rem(address(3));
        test_add(address(2));
        test_rem(address(1));
        test_add(address(5));
        test_rem(address(1));
        test_add(address(5));
        test_add(address(7));
        test_rem(address(8));
        test_rem(address(2));
        test_rem(address(9));
        test_rem(address(3));

        assertEq(set, _setValues);
    }

    function test_add_remove(uint8[] calldata values) public {
        for (uint256 i; i < values.length; i++) {
            uint256 value = values[i];
            if (value > 100) test_add(address(uint160(value % 100)));
            else test_rem(address(uint160(value % 100)));
        }

        assertEq(set, _setValues);
    }
}

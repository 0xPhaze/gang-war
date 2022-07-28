// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library utils {
    function getOwnedIds(
        mapping(uint256 => address) storage ownerOf,
        address user,
        uint256 collectionSize
    ) internal view returns (uint256[] memory ids) {
        uint256 ptr;
        uint256 size;

        assembly {
            ids := mload(0x40)
            ptr := add(ids, 32)
        }

        unchecked {
            for (uint256 id = 0; id < collectionSize + 1; ++id) {
                if (ownerOf[id] == user) {
                    assembly {
                        mstore(ptr, id)
                        ptr := add(ptr, 32)
                        size := add(size, 1)
                    }
                }
            }
        }

        assembly {
            mstore(ids, size)
            mstore(0x40, ptr)
        }
    }

    function indexOf(address[] calldata arr, address addr) internal pure returns (bool found, uint256 index) {
        unchecked {
            for (uint256 i; i < arr.length; ++i) if (arr[i] == addr) return (true, i);
        }
        return (false, 0);
    }
}

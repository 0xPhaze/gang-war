// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library utils {
    function getOwnedIds(
        mapping(uint256 => address) storage ownerOf,
        address user,
        uint256 start,
        uint256 collectionSize
    ) internal view returns (uint256[] memory ids) {
        uint256 ptr;
        uint256 size;

        assembly {
            ids := mload(0x40)
            ptr := add(ids, 32)
        }

        unchecked {
            for (uint256 id = start; id < start + collectionSize; ++id) {
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

    //     function getOwnedIds(
    //     mapping(uint256 => address) storage ownerOf,
    //     address user,
    //     uint256 collectionSize
    // ) internal view returns (uint256[] memory ids) {
    //     uint256 memPtr;
    //     uint256 idsLength;

    //     assembly {
    //         ids := mload(0x40)
    //         memPtr := add(ids, 32)
    //     }

    //     unchecked {
    //         uint256 end = collectionSize + 1;
    //         for (uint256 id = 0; id < end; ++id) {
    //             if (ownerOf[id] == user) {
    //                 assembly {
    //                     mstore(memPtr, id)
    //                     memPtr := add(memPtr, 32)
    //                     idsLength := add(idsLength, 1)
    //                 }
    //             }
    //         }
    //     }

    //     assembly {
    //         mstore(ids, idsLength)
    //         mstore(0x40, memPtr)
    //     }
    // }

    // function toUint256Array(
    //     mapping(uint256 => address) storage map,
    //     address user,
    //     uint256 collectionSize
    // ) internal view returns (uint256[] memory ids) {
    //     uint256 memPtr;
    //     uint256 idsLength;

    //     assembly {
    //         ids := mload(0x40)
    //         memPtr := add(ids, 32)
    //     }

    //     unchecked {
    //         uint256 end = collectionSize + 1;
    //         for (uint256 id = 0; id < end; ++id) {
    //             if (map[id] == user) {
    //                 assembly {
    //                     mstore(memPtr, id)
    //                     memPtr := add(memPtr, 32)
    //                     idsLength := add(idsLength, 1)
    //                 }
    //             }
    //         }
    //     }

    //     assembly {
    //         mstore(ids, idsLength)
    //         mstore(0x40, memPtr)
    //     }
    // }

    function indexOf(address[] calldata arr, address addr) internal pure returns (bool found, uint256 index) {
        unchecked {
            for (uint256 i; i < arr.length; ++i) {
                if (arr[i] == addr) {
                    return (true, i);
                }
            }
        }
        return (false, 0);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

using LibCrumbMap for LibCrumbMap.CrumbMap;

/// @notice Efficient crumb map library for mapping integers to crumbs.
/// @author phaze
/// @author adapted from Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibBytemap.sol)
library LibCrumbMap {
    struct CrumbMap {
        mapping(uint256 => uint256) map;
    }

    function get(CrumbMap storage crumbMap, uint256 index) internal view returns (uint256 result) {
        assembly {
            mstore(0x20, crumbMap.slot)
            mstore(0x00, shr(7, index))
            result := and(shr(shl(1, and(index, 0x7f)), sload(keccak256(0x00, 0x20))), 0x03)
        }
    }

    function getBytes(CrumbMap storage crumbMap, uint256 bytesIndex) internal view returns (uint256 result) {
        assembly {
            mstore(0x20, crumbMap.slot)
            mstore(0x00, bytesIndex)
            result := sload(keccak256(0x00, 0x20))
        }
    }

    function setBytes(
        CrumbMap storage crumbMap,
        uint256 bytesIndex,
        uint256 value
    ) internal {
        assembly {
            mstore(0x20, crumbMap.slot)
            mstore(0x00, bytesIndex)
            sstore(keccak256(0x00, 0x20), value)
        }
    }

    function set(
        CrumbMap storage crumbMap,
        uint256 index,
        uint256 value
    ) internal {
        require(value < 5);

        assembly {
            mstore(0x20, crumbMap.slot)
            mstore(0x00, shr(7, index))
            let storageSlot := keccak256(0x00, 0x20)
            // Unset crumb at index and store.
            let chunkValue := and(sload(storageSlot), not(shl(shl(1, and(index, 0x7f)), 0x03)))
            sstore(storageSlot, chunkValue)
        }
    }
}

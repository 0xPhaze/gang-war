// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../lib/VRFConsumerV2.sol";

contract MockVRFCoordinatorV2 is IVRFCoordinatorV2 {
    uint256 public requestIdCounter;

    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32,
        uint32
    ) external override returns (uint256 requestId) {
        return ++requestIdCounter;
    }
}

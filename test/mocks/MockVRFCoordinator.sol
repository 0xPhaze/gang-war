// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "/lib/VRFConsumerV2.sol";

contract MockVRFCoordinatorV2 is IVRFCoordinatorV2 {
    uint256 public requestIdCounter;
    address sender;

    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32,
        uint32
    ) external override returns (uint256 requestId) {
        sender = msg.sender;
        return ++requestIdCounter;
    }

    function fulfillLatestRequest() public {
        (bool success, ) = sender.call(
            abi.encodeWithSelector(
                bytes4(keccak256("fulfillRandomWords(uint256,uint256[])")),
                requestIdCounter,
                blockhash(block.number - 1)
            )
        );
        require(success, "callback failed");
    }
}

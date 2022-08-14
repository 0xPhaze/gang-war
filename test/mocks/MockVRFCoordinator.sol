// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "/lib/VRFConsumerV2.sol";

contract MockVRFCoordinator is IVRFCoordinatorV2 {
    uint256 public requestIdCounter;
    address public game;
    uint256[] public pendingRequests;

    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32,
        uint32
    ) external override returns (uint256 requestId) {
        game = msg.sender;
        pendingRequests.push(requestId = ++requestIdCounter);
    }

    function fulfillLatestRequest() public {
        fulfillLatestRequest(uint256(blockhash(block.number - 1)));
    }

    function fulfillLatestRequest(uint256 rand) public {
        uint256 requestId = pendingRequests[pendingRequests.length - 1];
        pendingRequests.pop();

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = rand;

        (bool success, ) = game.call(
            abi.encodeWithSelector(
                bytes4(keccak256("rawFulfillRandomWords(uint256,uint256[])")),
                requestId,
                randomWords
            )
        );
        require(success, "callback failed");
    }
}

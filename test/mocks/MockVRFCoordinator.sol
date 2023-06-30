// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "/lib/VRFConsumerV2.sol";
import "forge-std/console.sol";

contract MockVRFCoordinator is IVRFCoordinatorV2 {
    uint256 public requestIdCounter;
    address public game;

    struct Request {
        address sender;
        uint256 requestId;
    }

    Request[] public pendingRequests;

    bytes32 seed;

    constructor() {
        seed = blockhash(block.number - 1);
    }

    function numPendingRequests() public view returns (uint256) {
        return pendingRequests.length;
    }

    function requestRandomWords(bytes32, uint64, uint16, uint32, uint32)
        external
        override
        returns (uint256 requestId)
    {
        pendingRequests.push(Request({sender: msg.sender, requestId: requestId = ++requestIdCounter}));
    }

    function fulfillLatestRequest() public {
        fulfillLatestRequest(uint256(seed = keccak256(abi.encode(seed))));
    }

    function fulfillLatestRequest(uint256 rand) public {
        Request storage request = pendingRequests[pendingRequests.length - 1];
        // console.log("Fulfilling request sender %s id %s rand %s", request.sender, request.requestId, rand);

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = rand;

        (bool success, bytes memory returndata) = request.sender.call(
            abi.encodeWithSelector(
                bytes4(keccak256("rawFulfillRandomWords(uint256,uint256[])")), request.requestId, randomWords
            )
        );

        if (!success) {
            assembly {
                revert(add(returndata, 32), mload(returndata))
            }
        }

        pendingRequests.pop();
    }

    function fulfillLatestRequests() public {
        uint256 pendingRequestsLength = pendingRequests.length;
        for (uint256 i; i < pendingRequestsLength; ++i) {
            fulfillLatestRequest();
        }
    }

    function addConsumer(uint64, address) external pure {
        revert("Adding consumer to mock");
    }
}

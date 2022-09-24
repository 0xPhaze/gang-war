// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ---------- constants

address constant COORDINATOR_RINKEBY = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
bytes32 constant KEYHASH_RINKEBY = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

address constant COORDINATOR_MUMBAI = 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed;
bytes32 constant KEYHASH_MUMBAI = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;

address constant COORDINATOR_POLYGON = 0xAE975071Be8F8eE67addBC1A82488F1C24858067;
bytes32 constant KEYHASH_POLYGON = 0x6e099d640cde6de9d40ac749b4b594126b0169747122711109c9985d47751f93;

address constant COORDINATOR_MAINNET = 0x271682DEB8C4E0901D1a1550aD2e64D568E69909;
bytes32 constant KEYHASH_MAINNET = 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef;

// ---------- interfaces

interface IVRFCoordinatorV2 {
    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256 requestId);
}

// ---------- errors

error CallerNotCoordinator();

/// @title VRFConsumerV2
/// @author phaze (https://github.com/0xPhaze)
abstract contract VRFConsumerV2 {
    bytes32 private immutable keyHash;
    address private immutable coordinator;
    uint64 private immutable subscriptionId;
    uint32 private immutable callbackGasLimit;
    uint16 private immutable requestConfirmations;

    constructor(
        address coordinator_,
        bytes32 keyHash_,
        uint64 subscriptionId_,
        uint16 requestConfirmations_,
        uint32 callbackGasLimit_
    ) {
        keyHash = keyHash_;
        coordinator = coordinator_;
        subscriptionId = subscriptionId_;
        callbackGasLimit = callbackGasLimit_;
        requestConfirmations = requestConfirmations_;
    }

    /* ------------- virtual ------------- */

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal virtual;

    /* ------------- external ------------- */

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external payable {
        if (msg.sender != coordinator) {
            revert CallerNotCoordinator();
        }

        fulfillRandomWords(requestId, randomWords);
    }

    /* ------------- internal ------------- */

    function requestVRF() internal virtual returns (uint256) {
        return
            IVRFCoordinatorV2(coordinator).requestRandomWords(
                keyHash,
                subscriptionId,
                requestConfirmations,
                callbackGasLimit,
                1
            );
    }
}

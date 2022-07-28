// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "solmate/test/utils/mocks/MockERC721.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "../src/GangWar.sol";
import "../src/lib/VRFConsumerV2.sol";
import {MockVRFCoordinatorV2} from "../test/mocks/MockVRFCoordinator.sol";

import "../src/lib/ArrayUtils.sol";

import "chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";

// function addConsumer(uint64 subId, address consumer) external override onlySubOwner(subId) nonReentrant {

// interface IVRFCoordinator

/* 
forge script script/GangWar.s.sol:Deploy --rpc-url $RINKEBY_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv
forge script script/GangWar.s.sol:Deploy --rpc-url $PROVIDER_MUMBAI  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv
forge script script/GangWar.s.sol:Deploy --rpc-url https://rpc.ankr.com/polygon  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 30gwei -vvvv
*/

contract Deploy is Script {
    using ArrayUtils for *;

    GangWar game;

    // uint64 subId = 6985;
    // address coordinator = COORDINATOR_RINKEBY;
    // bytes32 keyHash = KEYHASH_RINKEBY;

    // uint64 subId = 862;
    // address coordinator = COORDINATOR_MUMBAI;
    // bytes32 keyHash = KEYHASH_MUMBAI;

    // uint64 subId = 133;
    // address coordinator = COORDINATOR_POLYGON;
    // bytes32 keyHash = KEYHASH_POLYGON;

    function getChainlinkParams()
        public
        view
        returns (
            address coordinator,
            bytes32 keyHash,
            uint64 subId
        )
    {
        if (block.chainid == 137) {
            coordinator = COORDINATOR_POLYGON;
            keyHash = KEYHASH_POLYGON;
            subId = 133;
        } else if (block.chainid == 80001) {
            coordinator = COORDINATOR_MUMBAI;
            keyHash = KEYHASH_MUMBAI;
            subId = 862;
        } else if (block.chainid == 4) {
            coordinator = COORDINATOR_RINKEBY;
            keyHash = KEYHASH_RINKEBY;
            subId = 6985;
        } else revert("unknown chainid");
    }

    function run() external {
        (address coordinator, bytes32 keyHash, uint64 subId) = getChainlinkParams();

        vm.startBroadcast();

        MockERC721 gmc = new MockERC721("GMC", "GMC");

        Gang[] memory gangs = new Gang[](21);
        for (uint256 i; i < 21; i++) gangs[i] = Gang(i % 3);

        uint256[] memory yields = new uint256[](21);
        for (uint256 i; i < 21; i++) yields[i] = 100 + (i / 3);

        bytes memory initCall = abi.encodeWithSelector(game.init.selector, address(gmc), gangs, yields);
        // MockVRFCoordinatorV2 coordinator = new MockVRFCoordinatorV2();

        GangWar impl = new GangWar(coordinator, keyHash, subId, 3, 200_000);
        game = GangWar(address(new ERC1967Proxy(address(impl), initCall)));

        initGangWar();

        gmc.mint(msg.sender, 1); // Yakuza Gangster
        gmc.mint(msg.sender, 1001); // Yakuza Baron

        game.baronDeclareAttack(0, 1, 1001);
        game.joinGangAttack(0, 1, [1].toMemory());

        VRFCoordinatorV2(coordinator).addConsumer(subId, address(game));

        vm.stopBroadcast();
    }

    function initGangWar() internal {
        // bytes[] memory initData = new bytes[](2);

        bool[21][21] memory connections;
        connections[0][1] = true;
        connections[1][2] = true;
        connections[2][3] = true;
        connections[0][3] = true;
        connections[3][4] = true;
        connections[6][7] = true;
        game.setDistrictConnections(PackedMap.encode(connections));

        // Gang[21] memory gangs;
        // for (uint256 i; i < 21; i++) gangs[i] = Gang((i % 3) + 1);
        // initData[1] = abi.encodeWithSelector(game.setDistrictsInitialOwnership.selector, gangs);

        // for (uint256 i; i < 21; i++) console.log("gang", i, uint256(gangs[i]));

        // game.setDistrictsInitialOwnership(gangs);

        // game.multiCall(initData);
    }

    function validateSetup() external {}
}

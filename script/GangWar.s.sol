// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "solmate/test/utils/mocks/MockERC721.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967VersionedUDS.sol";

import "../src/GangWar.sol";
import "../src/lib/VRFConsumerV2.sol";
import {MockVRFCoordinatorV2} from "../src/test/mocks/MockVRFCoordinator.sol";

import "../src/lib/ArrayUtils.sol";

import "chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";

// function addConsumer(uint64 subId, address consumer) external override onlySubOwner(subId) nonReentrant {

// interface IVRFCoordinator

/* 
forge script script/GangWar.s.sol:Deploy --rpc-url $RINKEBY_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv
*/

contract Deploy is Script {
    using ArrayUtils for *;

    GangWar game;

    // uint64 subId = 6985;
    // address coordinator = COORDINATOR_RINKEBY;
    // bytes32 keyHash = KEYHASH_RINKEBY;
    uint64 subId = 862;
    address coordinator = COORDINATOR_MUMBAI;
    bytes32 keyHash = KEYHASH_MUMBAI;

    function run() external {
        vm.startBroadcast();

        MockERC721 gmc = new MockERC721("GMC", "GMC");

        Gang[] memory gangs = new Gang[](21);
        for (uint256 i; i < 21; i++) gangs[i] = Gang((i % 3) + 1);

        uint256[] memory yields = new uint256[](21);
        for (uint256 i; i < 21; i++) yields[i] = 100 + (i / 3);

        bytes memory initCall = abi.encodeWithSelector(game.init.selector, address(gmc), gangs, yields);
        // MockVRFCoordinatorV2 coordinator = new MockVRFCoordinatorV2();

        GangWar impl = new GangWar(coordinator, keyHash, subId, 3, 200_000);
        game = GangWar(address(new ERC1967Proxy(address(impl), initCall)));

        initGangWar();

        gmc.mint(msg.sender, 1); // Yakuza Gangster
        gmc.mint(msg.sender, 1001); // Yakuza Baron

        game.baronDeclareAttack(1, 2, 1001);
        game.joinGangAttack(1, 2, [1].toMemory());

        VRFCoordinatorV2(coordinator).addConsumer(subId, address(game));

        vm.stopBroadcast();
    }

    function initGangWar() internal {
        // bytes[] memory initData = new bytes[](2);

        uint256[] memory districtsA = [1, 2, 3, 1, 4, 7].toMemory();
        uint256[] memory districtsB = [2, 3, 4, 4, 5, 8].toMemory();
        // initData[0] = abi.encodeWithSelector(game.addDistrictConnections.selector, districtsA, districtsB);

        game.addDistrictConnections(districtsA, districtsB);

        // Gang[21] memory gangs;
        // for (uint256 i; i < 21; i++) gangs[i] = Gang((i % 3) + 1);
        // initData[1] = abi.encodeWithSelector(game.setDistrictsInitialOwnership.selector, gangs);

        // for (uint256 i; i < 21; i++) console.log("gang", i, uint256(gangs[i]));

        // game.setDistrictsInitialOwnership(gangs);

        // game.multiCall(initData);
    }

    function validateSetup() external {}
}

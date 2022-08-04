// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "../src/GangWar.sol";
import "../src/lib/VRFConsumerV2.sol";
import {MockVRFCoordinatorV2} from "../test/mocks/MockVRFCoordinator.sol";
import {MockGMC} from "../test/mocks/MockGMC.sol";

import {Mice} from "/tokens/Mice.sol";

import "../src/lib/ArrayUtils.sol";

import "chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";

// function addConsumer(uint64 subId, address consumer) external override onlySubOwner(subId) nonReentrant {

// interface IVRFCoordinator

/* 
source .env && forge script script/Deploy.s.sol:Deploy --rpc-url $RINKEBY_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv
source .env && forge script script/Deploy.s.sol:Deploy --rpc-url $PROVIDER_MUMBAI  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv
source .env && forge script script/Deploy.s.sol:Deploy --rpc-url https://rpc.ankr.com/polygon  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 30gwei -vvvv
*/

contract Deploy is Script {
    using ArrayUtils for *;

    bool[22][22] connections;
    uint256[22] yields;
    Gang[22] occupants;

    function run() external {
        (address coordinator, bytes32 keyHash, uint64 subId) = getChainlinkParams();
        coordinator;

        vm.startBroadcast();

        MockGMC gmc = new MockGMC();

        MockVRFCoordinatorV2 mockCoordinator = new MockVRFCoordinatorV2();

        MockERC20[3] memory tokens;
        tokens[0] = new MockERC20("Yakuza Token", "YKZ", 18);
        tokens[1] = new MockERC20("Cartel Token", "CTL", 18);
        tokens[2] = new MockERC20("Cyberpunk Token", "CBP", 18);
        MockERC20 badges = new MockERC20("Badges", "BADGE", 18);

        Mice mice = new Mice(address(tokens[0]), address(tokens[1]), address(tokens[2]), address(badges));

        // GangWar impl = new GangWar(coordinator, keyHash, subId, 3, 200_000);
        GangWar impl = new GangWar(address(mockCoordinator), keyHash, subId, 3, 200_000);

        (uint256 connectionsPacked, uint256[21] memory initialOccupants, uint256[21] memory initialYields) = initData();

        bytes memory initCallData = abi.encodeWithSelector(
            GangWar.init.selector,
            gmc,
            tokens,
            badges,
            connectionsPacked,
            initialOccupants,
            initialYields
        );

        GangWar game = GangWar(address(new ERC1967Proxy(address(impl), initCallData)));

        // VRFCoordinatorV2(coordinator).addConsumer(subId, address(game));

        // setup
        gmc.setGangWar(address(game));

        gmc.mintBatch();

        game.baronDeclareAttack(2, 0, 10_001);
        game.joinGangAttack(2, 0, [1].toMemory());

        game.baronDeclareAttack(2, 10, 10_004);
        game.joinGangAttack(2, 10, [4].toMemory());

        vm.stopBroadcast();

        console.log('gmc: "', address(gmc), '",');
        console.log('mice: "', address(mice), '",');
        console.log('tokenYakuza: "', address(tokens[0]), '",');
        console.log('tokenCartel: "', address(tokens[1]), '",');
        console.log('tokenCyberpunk: "', address(tokens[2]), '",');
        console.log('badges: "', address(badges), '",');
        console.log('game: "', address(game), '",');
        console.log('mockVRF: "', address(mockCoordinator), '",');
    }

    function getChainlinkParams()
        internal
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

    constructor() {
        connections[1][2] = true;
        connections[1][3] = true;
        connections[1][8] = true;
        connections[1][9] = true;
        connections[1][11] = true;
        connections[2][1] = true;
        connections[2][9] = true;
        connections[2][10] = true;
        connections[2][11] = true;
        connections[3][1] = true;
        connections[3][4] = true;
        connections[3][11] = true;
        connections[3][12] = true;
        connections[3][13] = true;
        connections[4][3] = true;
        connections[4][5] = true;
        connections[4][13] = true;
        connections[4][14] = true;
        connections[4][15] = true;
        connections[5][4] = true;
        connections[5][6] = true;
        connections[5][7] = true;
        connections[5][15] = true;
        connections[6][5] = true;
        connections[6][7] = true;
        connections[6][15] = true;
        connections[7][5] = true;
        connections[7][6] = true;
        connections[7][8] = true;
        connections[7][16] = true;
        connections[8][1] = true;
        connections[8][7] = true;
        connections[8][9] = true;
        connections[8][16] = true;
        connections[8][17] = true;
        connections[9][1] = true;
        connections[9][2] = true;
        connections[9][8] = true;
        connections[9][17] = true;
        connections[9][18] = true;
        connections[10][2] = true;
        connections[10][11] = true;
        connections[10][18] = true;
        connections[10][19] = true;
        connections[11][1] = true;
        connections[11][2] = true;
        connections[11][3] = true;
        connections[11][10] = true;
        connections[11][12] = true;
        connections[12][3] = true;
        connections[12][11] = true;
        connections[12][13] = true;
        connections[12][20] = true;
        connections[13][3] = true;
        connections[13][4] = true;
        connections[13][12] = true;
        connections[13][14] = true;
        connections[13][20] = true;
        connections[13][21] = true;
        connections[14][4] = true;
        connections[14][13] = true;
        connections[14][15] = true;
        connections[14][21] = true;
        connections[15][4] = true;
        connections[15][5] = true;
        connections[15][6] = true;
        connections[15][14] = true;
        connections[16][7] = true;
        connections[16][8] = true;
        connections[16][17] = true;
        connections[17][8] = true;
        connections[17][9] = true;
        connections[17][16] = true;
        connections[17][18] = true;
        connections[18][9] = true;
        connections[18][10] = true;
        connections[18][17] = true;
        connections[18][19] = true;
        connections[19][10] = true;
        connections[19][18] = true;
        connections[20][12] = true;
        connections[20][13] = true;
        connections[20][21] = true;
        connections[21][13] = true;
        connections[21][14] = true;
        connections[21][20] = true;

        occupants[3] = Gang.YAKUZA;
        occupants[4] = Gang.YAKUZA;
        occupants[12] = Gang.YAKUZA;
        occupants[13] = Gang.YAKUZA;
        occupants[14] = Gang.YAKUZA;
        occupants[20] = Gang.YAKUZA;
        occupants[21] = Gang.YAKUZA;

        occupants[1] = Gang.CARTEL;
        occupants[2] = Gang.CARTEL;
        occupants[9] = Gang.CARTEL;
        occupants[10] = Gang.CARTEL;
        occupants[11] = Gang.CARTEL;
        occupants[18] = Gang.CARTEL;
        occupants[19] = Gang.CARTEL;

        occupants[5] = Gang.CYBERP;
        occupants[6] = Gang.CYBERP;
        occupants[7] = Gang.CYBERP;
        occupants[8] = Gang.CYBERP;
        occupants[15] = Gang.CYBERP;
        occupants[16] = Gang.CYBERP;
        occupants[17] = Gang.CYBERP;

        yields[3] = 1_300_000;
        yields[4] = 1_000_000;
        yields[12] = 700_000;
        yields[13] = 1_000_000;
        yields[14] = 1_300_000;
        yields[20] = 1_700_000;
        yields[21] = 700_000;

        yields[1] = 1_300_000;
        yields[2] = 700_000;
        yields[9] = 1_000_000;
        yields[10] = 700_000;
        yields[11] = 1_300_000;
        yields[18] = 1_000_000;
        yields[19] = 1_700_000;

        yields[5] = 1_000_000;
        yields[6] = 1_700_000;
        yields[7] = 700_000;
        yields[8] = 1_000_000;
        yields[15] = 1_300_000;
        yields[16] = 700_000;
        yields[17] = 1_300_000;
    }

    function initData()
        internal
        view
        returns (
            uint256,
            uint256[21] memory,
            uint256[21] memory
        )
    {
        bool[21][21] memory connectionsNormalized;
        for (uint256 i; i < 21; i++) {
            for (uint256 j; j < 21; j++) {
                connectionsNormalized[i][j] = connections[i + 1][j + 1];

                assert(connections[i + 1][j + 1] == connections[j + 1][i + 1]);
            }
        }

        uint256 connectionsPacked = PackedMap.encode(connectionsNormalized);

        Gang[22] memory occ;
        occ = occupants;
        uint256[21] memory initialOccupants;

        assembly {
            initialOccupants := add(occ, 0x20)
        }

        uint256[21] storage initialYields;
        assembly {
            initialYields.slot := add(yields.slot, 1)
        }

        return (connectionsPacked, initialOccupants, initialYields);
    }

    function validateSetup() external {}
}

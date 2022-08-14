// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";

import "/lib/VRFConsumerV2.sol";
import "/GangWar.sol";
import "/tokens/GangToken.sol";
import "/tokens/GangWarItems.sol";

import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import {MockVRFCoordinator} from "../test/mocks/MockVRFCoordinator.sol";
import {MockGMC} from "../test/mocks/MockGMC.sol";

import {Mice} from "/tokens/Mice.sol";

import "f-utils/fUtils.sol";

// import "chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";

// function addConsumer(uint64 subId, address consumer) external override onlySubOwner(subId) nonReentrant {

// interface IVRFCoordinator

/* 
source .env && forge script script/Deploy.s.sol:Deploy --rpc-url $RINKEBY_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv
source .env && forge script script/Deploy.s.sol:Deploy --rpc-url https://rpc.ankr.com/polygon  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 30gwei -vvvv

cp ~/git/eth/GangWar/out/MockGMC.sol/MockGMC.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockERC20.sol/MockERC20.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockVRFCoordinator.sol/MockVRFCoordinator.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/GangWar.sol/GangWar.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/Mice.sol/Mice.json ~/git/eth/gmc-website/data/abi
*/

contract MockGangWar is GangWar {
    constructor(
        address coordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit
    ) GangWar(coordinator, keyHash, subscriptionId, requestConfirmations, callbackGasLimit) {}

    function setGangWarOutcome(
        uint256 districtId,
        uint256 roundId,
        uint256 outcome
    ) public {
        s().gangWarOutcomes[districtId][roundId] = outcome;
    }

    function setAttackForce(
        uint256 districtId,
        uint256 roundId,
        uint256 force
    ) public {
        s().districtAttackForces[districtId][roundId] = force;
    }

    function setDefenseForces(
        uint256 districtId,
        uint256 roundId,
        uint256 force
    ) public {
        s().districtDefenseForces[districtId][roundId] = force;
    }

    function getDistrictConnections() external view returns (uint256) {
        return s().districtConnections;
    }
}

contract Deploy is Script {
    using fUtils for *;

    // contracts
    MockGMC gmc;

    MockVRFCoordinator coordinator;

    GangToken[3] tokens;

    GangToken badges;

    GangWarItems gangItems;
    Mice mice;
    MockGangWar game;

    MockERC20 gouda;

    uint256 STAGING = (block.chainid == 31337) ? 0 : (block.chainid != 1 && block.chainid != 137) ? 1 : 2;

    function run() external {
        vm.startBroadcast();

        deployAndSetupGangWar();

        vm.stopBroadcast();

        // testing
        GangToken(tokens[0]).grantMintAuthority(msg.sender);
        GangToken(tokens[1]).grantMintAuthority(msg.sender);
        GangToken(tokens[2]).grantMintAuthority(msg.sender);

        // VRFCoordinatorV2(coordinator).addConsumer(subId, address(game));

        gmc.mintBatch(msg.sender);
        gmc.mintBatch(0x2181838c46bEf020b8Beb756340ad385f5BD82a8);

        game.baronDeclareAttack(2, 0, 10_001);
        game.joinGangAttack(2, 0, [1].toMemory());

        game.baronDeclareAttack(2, 10, 10_004);
        game.joinGangAttack(2, 10, [4].toMemory());

        console.log('gmc: "', address(gmc), '",');
        console.log('mice: "', address(mice), '",');
        console.log('tokenYakuza: "', address(tokens[0]), '",');
        console.log('tokenCartel: "', address(tokens[1]), '",');
        console.log('tokenCyberpunk: "', address(tokens[2]), '",');
        console.log('badges: "', address(badges), '",');
        console.log('game: "', address(game), '",');
        console.log('mockVRF: "', address(coordinator), '",');
    }

    function deployAndSetupGangWar() internal {
        (address coordinatorDeployed, bytes32 keyHash, uint64 subId) = getChainlinkParams();

        if (STAGING < 2) {
            coordinator = new MockVRFCoordinator();
            gmc = new MockGMC();
            gouda = new MockERC20("Gouda", "GOUDA", 18);
        } else {
            coordinator = MockVRFCoordinator(coordinatorDeployed);
        }

        address gangTokenImpl = address(new GangToken());

        tokens[0] = GangToken(address(new ERC1967Proxy(gangTokenImpl, abi.encodeWithSelector(GangToken.init.selector, "Yakuza Token", "YKZ")))); // prettier-ignore
        tokens[1] = GangToken(address(new ERC1967Proxy(gangTokenImpl, abi.encodeWithSelector(GangToken.init.selector, "Cartel Token", "CTL")))); // prettier-ignore
        tokens[2] = GangToken(address(new ERC1967Proxy(gangTokenImpl, abi.encodeWithSelector(GangToken.init.selector, "Cyberpunk Token", "CPK")))); // prettier-ignore

        badges = GangToken(address(new ERC1967Proxy(gangTokenImpl, abi.encodeWithSelector(GangToken.init.selector, "Badges", "BADGE")))); // prettier-ignore

        mice = Mice(address(new ERC1967Proxy(address(new Mice(address(tokens[0]), address(tokens[1]), address(tokens[2]), address(badges))), abi.encodePacked(Mice.init.selector)))); // prettier-ignore

        gangItems = GangWarItems(address(new ERC1967Proxy(address(new GangWarItems()), abi.encodeWithSelector(GangWarItems.init.selector, '', 5)))); // prettier-ignore

        if (STAGING == 0) {
            game = MockGangWar(address(new ERC1967Proxy(address(new MockGangWar(address(coordinator), keyHash, subId, 3, 200_000)), GangWarInitCalldata()))); // prettier-ignore
        } else {
            game = MockGangWar(address(new ERC1967Proxy(address(new GangWar(address(coordinator), keyHash, subId, 3, 200_000)), GangWarInitCalldata()))); // prettier-ignore
        }

        // setup

        gmc.setGangWar(address(game));

        GangToken(tokens[0]).grantMintAuthority(address(game));
        GangToken(tokens[1]).grantMintAuthority(address(game));
        GangToken(tokens[2]).grantMintAuthority(address(game));
        GangToken(badges).grantMintAuthority(address(game));

        GangToken(tokens[0]).grantBurnAuthority(address(mice));
        GangToken(tokens[1]).grantBurnAuthority(address(mice));
        GangToken(tokens[2]).grantBurnAuthority(address(mice));
        GangToken(badges).grantBurnAuthority(address(mice));
    }

    function getChainlinkParams()
        internal
        view
        returns (
            address coordinator_,
            bytes32 keyHash,
            uint64 subId
        )
    {
        if (block.chainid == 137) {
            coordinator_ = COORDINATOR_POLYGON;
            keyHash = KEYHASH_POLYGON;
            subId = 133;
        } else if (block.chainid == 80001) {
            coordinator_ = COORDINATOR_MUMBAI;
            keyHash = KEYHASH_MUMBAI;
            subId = 862;
        } else if (block.chainid == 4) {
            coordinator_ = COORDINATOR_RINKEBY;
            keyHash = KEYHASH_RINKEBY;
            subId = 6985;
        } else if (block.chainid == 31337) {
            coordinator_ = COORDINATOR_RINKEBY;
            keyHash = KEYHASH_RINKEBY;
            subId = 6985;
        } else revert("unknown chainid");
    }

    // settings
    bool[22][22] connections;
    uint256[22] yields;
    Gang[22] occupants;

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

    function GangWarInitCalldata() internal view returns (bytes memory) {
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

        bytes memory initCalldata = abi.encodeWithSelector(GangWar.init.selector, gmc, tokens, badges, connectionsPacked, initialOccupants, initialYields); // prettier-ignore

        return initCalldata;
    }

    function validateSetup() external {}
}

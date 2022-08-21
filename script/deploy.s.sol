// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

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

import "futils/futils.sol";
import {DeployScripts} from "./deploy-scripts.sol";

// import "chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";

// function addConsumer(uint64 subId, address consumer) external override onlySubOwner(subId) nonReentrant {

// interface IVRFCoordinator

/* 
source .env && forge script deploy --rpc-url $RINKEBY_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv

source .env && forge script deploy --rpc-url $RPC_MUMBAI -vvvv
source .env && forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --broadcast --with-gas-price 7wei -vvvv
source .env && forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 1.5gwei -vvvv
// source .env && forge script deploy --rpc-url https://rpc.ankr.com/polygon  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 30gwei -vvvv

cp ~/git/eth/GangWar/out/MockGMC.sol/MockGMC.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockERC20.sol/MockERC20.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockVRFCoordinator.sol/MockVRFCoordinator.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/GangWar.sol/GangWar.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/Mice.sol/Mice.json ~/git/eth/gmc-website/data/abi
*/

contract deploy is DeployScripts {
    using futils for *;

    MockGMC gmc;
    MockVRFCoordinator coordinator;
    GangToken[3] tokens;
    GangToken badges;
    GangWarItems gangItems;
    Mice mice;
    MockGangWar game;
    MockERC20 gouda;

    uint256 STAGING;

    uint256 constant GANGSTER_YAKUZA_1 = 1;
    uint256 constant GANGSTER_CARTEL_1 = 2;
    uint256 constant GANGSTER_CYBERP_1 = 3;
    uint256 constant GANGSTER_YAKUZA_2 = 4;
    uint256 constant GANGSTER_CARTEL_2 = 5;
    uint256 constant GANGSTER_CYBERP_2 = 6;

    uint256 constant BARON_YAKUZA_1 = 10_001;
    uint256 constant BARON_CARTEL_1 = 10_002;
    uint256 constant BARON_CYBERP_1 = 10_003;
    uint256 constant BARON_YAKUZA_2 = 10_004;
    uint256 constant BARON_CARTEL_2 = 10_005;
    uint256 constant BARON_CYBERP_2 = 10_006;

    uint256 constant DISTRICT_YAKUZA_1 = 2;
    uint256 constant DISTRICT_CARTEL_1 = 0;
    uint256 constant DISTRICT_CYBERP_1 = 7;
    uint256 constant DISTRICT_YAKUZA_2 = 3;
    uint256 constant DISTRICT_CARTEL_2 = 10;
    uint256 constant DISTRICT_CYBERP_2 = 4;

    constructor() {
        if (block.chainid == 31337) {
            STAGING = 0;
        } else if (block.chainid == 4 || block.chainid == 80_001) {
            STAGING = 1;
        } else if (block.chainid == 1 || block.chainid == 137) {
            STAGING = 2;
        } else {
            revert(string.concat("unknown chainid", vm.toString(block.chainid)));
        }

        setupVars();
    }

    // function tryLoadEnvAddressOrDeployProxy(string memory key) returns (address) {
    //     try vm.envAddress(key) returns (address addr) {
    //         return addr;
    //     } catch {
    //         // return new
    //     }

    // }

    // function deployOrLoadProxies() internal {
    //     // if (block.chainid == 80_001) {
    //     //     vm.envAddress("NOMAD_CORE_HOME_DOMAIN");
    //     MockGMC gmc;
    //     MockVRFCoordinator coordinator;
    //     GangToken[3] tokens;
    //     GangToken badges;
    //     GangWarItems gangItems;
    //     Mice mice;
    //     MockGangWar game;
    //     MockERC20 gouda;
    // }

    function setUpEnv() internal {
        string memory profile = tryLoadEnvString("FOUNDRY_PROFILE");

        if (eq(profile, "")) {
            vm.warp(1660993892);
            vm.roll(27702338);
        } else if (eq(profile, "mumbai")) {
            vm.selectFork(vm.createFork("mumbai"));
        }
    }

    function setUpContracts() internal {
        address gangTokenImpl = setUpContract("GANG_TOKEN_IMPLEMENTATION", "GangToken", type(GangToken).creationCode); // prettier-ignore

        // bytes memory yakuzaInitCall = abi.encodeWithSelector(GangToken.init.selector, "Yakuza Token", "YKZ");
        // bytes memory cartelInitCall = abi.encodeWithSelector(GangToken.init.selector, "CARTEL Token", "CTL");
        // bytes memory cyberpInitCall = abi.encodeWithSelector(GangToken.init.selector, "Cyberpunk Token", "CBP");
        // bytes memory badgesInitCall = abi.encodeWithSelector(GangToken.init.selector, "Badges", "BADGE");

        // tokens[0] = GangToken(setUpProxy("YAKUZA_TOKEN", "GangToken", gangTokenImpl, yakuzaInitCall));
        // tokens[1] = GangToken(setUpProxy("CARTEL_TOKEN", "GangToken", gangTokenImpl, cartelInitCall));
        // tokens[2] = GangToken(setUpProxy("CYBERP_TOKEN", "GangToken", gangTokenImpl, cyberpInitCall));
        // tokens[2] = GangToken(setUpProxy("BADGES_TOKEN", "GangToken", gangTokenImpl, badgesInitCall));

        // bytes memory miceCreationCode = abi.encodePacked(type(Mice).creationCode, abi.encode(tokens[0], tokens[1], tokens[2], badges)); // prettier-ignore

        // address miceImpl = setUpContract("MICE_IMPLEMENTATION", "Mice", miceCreationCode);
        // mice = Mice(setUpProxy("MICE", "Mice", miceImpl, abi.encodePacked(Mice.init.selector)));

        // bytes memory gangWarItemsInitCall = abi.encodeWithSelector(GangWarItems.init.selector, "", 5);
        // address gangWarItemsImpl = setUpContract("GANG_WAR_ITEMS_IMPLEMENTATION", "GangWarItems", type(GangWarItems).creationCode); // prettier-ignore
        // gangItems = GangWarItems(setUpProxy("GANG_WAR_ITEMS", "GangWarItems", gangWarItemsImpl, gangWarItemsInitCall)); // prettier-ignore

        // console.log(hash);

        // console.logBytes(data);
        // string memory res = abi.decode(data, (string));
        // console.log(res);

        // bytes32 data = abi.decode(vm.parseJson(json, ".address"), (bytes32));
        //   "address": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",

        // console.logAddress(addr);

        // string[] memory data = new string[](1);
        // data[0] = "env";
        // bytes memory out = vm.ffi(data);
        // console.log(string(out));

        // tokens[0] = GangToken(address(new ERC1967Proxy(gangTokenImpl, abi.encodeWithSelector(GangToken.init.selector, "Yakuza Token", "YKZ")))); // prettier-ignore
        // tokens[1] = GangToken(address(new ERC1967Proxy(gangTokenImpl, abi.encodeWithSelector(GangToken.init.selector, "Cartel Token", "CTL")))); // prettier-ignore
        // tokens[2] = GangToken(address(new ERC1967Proxy(gangTokenImpl, abi.encodeWithSelector(GangToken.init.selector, "Cyberpunk Token", "CPK")))); // prettier-ignore

        // mice = Mice(address( new ERC1967Proxy(address(new Mice(address(tokens[0]), address(tokens[1]), address(tokens[2]), address(badges))), abi.encodePacked(Mice.init.selector)))); // prettier-ignore

        // setUpProxy("GOUDA", type(MockERC20).creationCode, "", keccak256(type(MockERC20).runtimeCode));

        // gouda = new MockERC20("Gouda", "GOUDA", 18);

        // gmc = new MockGMC();
    }

    function run() external {
        vm.startBroadcast();

        setUpContracts();

        vm.stopBroadcast();

        logRegisteredContracts();

        // // console.log("arg", arg);
        // // uint256 forkId =
        // // vm.selectFork(vm.createFork("mumbai"));

        // // console.log(vm.rpcUrl("mumbai"));
        // setUpEnv();

        // console.log(block.chainid);

        // // string[2][] memory urls = vm.rpcUrls();
        // // for (uint256 i; i < urls.length; i++) {
        // //     console.log(urls[i][0], urls[i][1]);
        // // }
        // // console.logAddress(msg.sender);

        // // vm.recordLogs();

        // vm.startBroadcast();

        // deployAndSetupGangWar();

        // // Vm.Log[] memory logs = vm.getRecordedLogs();

        // // for (uint256 i; i < logs.length; i++) {
        // //     // console.log(logs[i])
        // // }
        // // struct Log {
        // //     bytes32[] topics;
        // //     bytes data;
        // // }
        // // console.log(logs.length);

        // if (STAGING < 2) {
        //     // testing
        //     GangToken(tokens[0]).grantMintAuthority(msg.sender);
        //     GangToken(tokens[1]).grantMintAuthority(msg.sender);
        //     GangToken(tokens[2]).grantMintAuthority(msg.sender);
        //     GangToken(badges).grantMintAuthority(msg.sender);

        //     // VRFCoordinatorV2(coordinator).addConsumer(subId, address(game));

        //     gmc.mintBatch(msg.sender);
        //     gmc.mintBatch(0x2181838c46bEf020b8Beb756340ad385f5BD82a8);

        //     game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);
        //     game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());

        //     game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_2, false);
        //     game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, [GANGSTER_YAKUZA_2].toMemory());
        // }

        // vm.stopBroadcast();

        // // string[] memory inp = new string[](2);
        // // inp[0] = "echo";
        // // inp[1] = "hi";
        // // bytes memory res = vm.ffi(inp);
        // // vm.setEnv("hi", "there");
        // // console.log(res);

        // console.log('gmc: "%s"', address(gmc));
        // console.log('mice: "%s"', address(mice));
        // console.log('tokenYakuza: "%s"', address(tokens[0]));
        // console.log('tokenCartel: "%s"', address(tokens[1]));
        // console.log('tokenCyberpunk: "%s"', address(tokens[2]));
        // console.log('badges: "%s"', address(badges));
        // console.log('game: "%s"', address(game));
        // console.log('mockVRF: "%s"', address(coordinator));
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

        mice = Mice(address( new ERC1967Proxy(address(new Mice(address(tokens[0]), address(tokens[1]), address(tokens[2]), address(badges))), abi.encodePacked(Mice.init.selector)))); // prettier-ignore

        gangItems = GangWarItems(address(new ERC1967Proxy(address(new GangWarItems()), abi.encodeWithSelector(GangWarItems.init.selector, '', 5)))); // prettier-ignore

        if (STAGING < 2) {
            game = MockGangWar(
                address(
                    new ERC1967Proxy(address(new MockGangWar(address(coordinator), keyHash, subId, 3, 200_000)), GangWarInitCalldata())
                )
            ); // prettier-ignore
        } else {
            // game = MockGangWar(address(new ERC1967Proxy(address(new MockGangWar(address(coordinator), keyHash, subId, 3, 200_000)), GangWarInitCalldata()))); // prettier-ignore
            game = MockGangWar(
                address(new ERC1967Proxy(address(new GangWar(address(coordinator), keyHash, subId, 3, 200_000)), GangWarInitCalldata()))
            ); // prettier-ignore
        }

        // // setup

        gmc.setGangWar(address(game));

        game.setBriberyFee(address(gouda), 2e18);

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
        } else {
            revert("unknown chainid");
        }
    }

    // settings
    bool[22][22] connections;
    uint256[22] yields;
    Gang[22] occupants;

    function setupVars() private {
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

        bytes memory initCalldata = abi.encodeWithSelector(
            GangWar.init.selector, gmc, tokens, badges, connectionsPacked, initialOccupants, initialYields
        ); // prettier-ignore

        return initCalldata;
    }

    function validateSetup() external {}
}

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

    function setYield(
        uint256 gang,
        uint256 token,
        uint256 yield
    ) public {
        _setYield(gang, token, yield);
    }
}

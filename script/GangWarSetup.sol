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
import {MockGangWar} from "../test/mocks/MockGangWar.sol";

import {Mice} from "/tokens/Mice.sol";

import "futils/futils.sol";
import {DeployScripts} from "./deploy-scripts.sol";

contract GangWarSetup is DeployScripts {
    using futils for *;

    // ---------------- vars
    MockGMC gmc;
    MockVRFCoordinator coordinator;
    GangToken[3] tokens;
    GangToken badges;
    GangWarItems gangItems;
    Mice mice;
    MockGangWar game;
    MockERC20 gouda;

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
        setUpGangWarConstants();
    }

    function setUpContracts() internal {
        address gangTokenImpl = setUpContract("GANG_TOKEN_IMPLEMENTATION", "GangToken", type(GangToken).creationCode); // prettier-ignore

        bytes memory yakuzaInitCall = abi.encodeWithSelector(GangToken.init.selector, "Yakuza Token", "YKZ");
        bytes memory cartelInitCall = abi.encodeWithSelector(GangToken.init.selector, "CARTEL Token", "CTL");
        bytes memory cyberpInitCall = abi.encodeWithSelector(GangToken.init.selector, "Cyberpunk Token", "CBP");
        bytes memory badgesInitCall = abi.encodeWithSelector(GangToken.init.selector, "Badges", "BADGE");

        tokens[0] = GangToken(setUpProxy("YAKUZA_TOKEN", "GangToken", gangTokenImpl, yakuzaInitCall));
        tokens[1] = GangToken(setUpProxy("CARTEL_TOKEN", "GangToken", gangTokenImpl, cartelInitCall));
        tokens[2] = GangToken(setUpProxy("CYBERP_TOKEN", "GangToken", gangTokenImpl, cyberpInitCall));
        badges = GangToken(setUpProxy("BADGES_TOKEN", "GangToken", gangTokenImpl, badgesInitCall));

        bytes memory miceCreationCode = abi.encodePacked(type(Mice).creationCode, abi.encode(tokens[0], tokens[1], tokens[2], badges)); // prettier-ignore
        address miceImpl = setUpContract("MICE_IMPLEMENTATION", "Mice", miceCreationCode);
        mice = Mice(setUpProxy("MICE", "Mice", miceImpl, abi.encodePacked(Mice.init.selector)));

        bytes memory gangWarItemsInitCall = abi.encodeWithSelector(GangWarItems.init.selector, "", 5);
        address gangWarItemsImpl = setUpContract("GANG_WAR_ITEMS_IMPLEMENTATION", "GangWarItems", type(GangWarItems).creationCode); // prettier-ignore
        gangItems = GangWarItems(setUpProxy("GANG_WAR_ITEMS", "GangWarItems", gangWarItemsImpl, gangWarItemsInitCall)); // prettier-ignore

        bytes memory goudaCreationCode = abi.encodePacked(type(MockERC20).creationCode, abi.encode("Gouda", "GOUDA", 18)); // prettier-ignore

        coordinator = MockVRFCoordinator(setUpContract("MOCK_VRF_COORDINATOR", "MockVRFCoordinator", type(MockVRFCoordinator).creationCode)); // prettier-ignore
        gmc = MockGMC(setUpContract("MOCK_GMC", "MockGMC", type(MockGMC).creationCode)); // prettier-ignore
        gouda = MockERC20(setUpContract("GOUDA", "MockERC20", goudaCreationCode)); // prettier-ignore

        (, bytes32 keyHash, uint64 subId) = getChainlinkParams();

        bytes memory gangWarInitCall = gangWarInitCalldata();
        bytes memory gangWarCreationCode = abi.encodePacked(type(MockGangWar).creationCode, abi.encode(coordinator, keyHash, subId, 3, 200_000)); // prettier-ignore
        address gangWarImpl = setUpContract("GANG_WAR_IMPLEMENTATION", "GangWar", gangWarCreationCode); // prettier-ignore
        game = MockGangWar(setUpProxy("GANG_WAR", "GangWar", gangWarImpl, gangWarInitCall)); // prettier-ignore
    }

    function initContracts() internal {
        gmc.setGangWar(address(game));
    }

    function initContractsTEST() internal {
        initContracts();

        GangToken(tokens[0]).grantMintAuthority(address(game));
        GangToken(tokens[1]).grantMintAuthority(address(game));
        GangToken(tokens[2]).grantMintAuthority(address(game));
        GangToken(badges).grantMintAuthority(address(game));

        GangToken(tokens[0]).grantBurnAuthority(address(mice));
        GangToken(tokens[1]).grantBurnAuthority(address(mice));
        GangToken(tokens[2]).grantBurnAuthority(address(mice));
        GangToken(badges).grantBurnAuthority(address(mice));
    }

    bytes32 constant MINT_AUTHORITY = keccak256("MINT_AUTHORITY");
    bytes32 constant BURN_AUTHORITY = keccak256("BURN_AUTHORITY");

    function initContractsCI() internal {
        if (firstTimeDeployed[address(game)]) initContracts();

        // don't re-send transactions unnecessarily
        if (!tokens[0].hasRole(MINT_AUTHORITY, address(game))) GangToken(tokens[0]).grantMintAuthority(address(game));
        if (!tokens[1].hasRole(MINT_AUTHORITY, address(game))) GangToken(tokens[1]).grantMintAuthority(address(game));
        if (!tokens[2].hasRole(MINT_AUTHORITY, address(game))) GangToken(tokens[2]).grantMintAuthority(address(game));
        if (!badges.hasRole(MINT_AUTHORITY, address(game))) GangToken(badges).grantMintAuthority(address(game));

        if (!tokens[0].hasRole(BURN_AUTHORITY, address(mice))) GangToken(tokens[0]).grantBurnAuthority(address(mice));
        if (!tokens[1].hasRole(BURN_AUTHORITY, address(mice))) GangToken(tokens[1]).grantBurnAuthority(address(mice));
        if (!tokens[2].hasRole(BURN_AUTHORITY, address(mice))) GangToken(tokens[2]).grantBurnAuthority(address(mice));
        if (!badges.hasRole(BURN_AUTHORITY, address(mice))) GangToken(badges).grantBurnAuthority(address(mice));
    }

    function initContractsCITEST() internal {
        initContractsCI();

        address lumy = 0x2181838c46bEf020b8Beb756340ad385f5BD82a8;

        // grant mint authority for test purposes
        if (!tokens[0].hasRole(MINT_AUTHORITY, msg.sender)) GangToken(tokens[0]).grantMintAuthority(msg.sender);
        if (!tokens[1].hasRole(MINT_AUTHORITY, msg.sender)) GangToken(tokens[1]).grantMintAuthority(msg.sender);
        if (!tokens[2].hasRole(MINT_AUTHORITY, msg.sender)) GangToken(tokens[2]).grantMintAuthority(msg.sender);
        if (!badges.hasRole(MINT_AUTHORITY, msg.sender)) GangToken(badges).grantMintAuthority(msg.sender);

        if (!tokens[0].hasRole(MINT_AUTHORITY, lumy)) GangToken(tokens[0]).grantMintAuthority(lumy);
        if (!tokens[1].hasRole(MINT_AUTHORITY, lumy)) GangToken(tokens[1]).grantMintAuthority(lumy);
        if (!tokens[2].hasRole(MINT_AUTHORITY, lumy)) GangToken(tokens[2]).grantMintAuthority(lumy);
        if (!badges.hasRole(MINT_AUTHORITY, lumy)) GangToken(badges).grantMintAuthority(lumy);

        // mint tokens for testing
        if (firstTimeDeployed[address(game)]) {
            gmc.mintBatch(msg.sender);
            gmc.mintBatch(lumy);

            GangToken(tokens[0]).mint(msg.sender, 100_000e18);
            GangToken(tokens[1]).mint(msg.sender, 100_000e18);
            GangToken(tokens[2]).mint(msg.sender, 100_000e18);
            GangToken(badges).mint(msg.sender, 100_000e18);

            GangToken(tokens[0]).mint(lumy, 100_000e18);
            GangToken(tokens[1]).mint(lumy, 100_000e18);
            GangToken(tokens[2]).mint(lumy, 100_000e18);
            GangToken(badges).mint(lumy, 100_000e18);
        }

        // setup a test attack
        if (uint8(game.getGangsterView(BARON_YAKUZA_1).state) == 0) {
            game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);
            game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());
        }

        if (uint8(game.getGangsterView(BARON_YAKUZA_2).state) == 0) {
            game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_2, false);
            game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, [GANGSTER_YAKUZA_2].toMemory());
        }
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

    // ---------------- constants
    bool[22][22] connections;
    uint256[22] yields;
    Gang[22] occupants;

    function setUpGangWarConstants() private {
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

    function gangWarInitCalldata() internal view returns (bytes memory) {
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

        // shift index by 1 so that districts start at 0: [1, 22) => [0, 21)
        assembly { initialOccupants := add(occ, 0x20) } // prettier-ignore

        uint256[21] storage initialYields;
        assembly { initialYields.slot := add(yields.slot, 1) } // prettier-ignore

        bytes memory initCalldata = abi.encodeWithSelector(
            GangWar.init.selector,
            gmc,
            tokens,
            badges,
            connectionsPacked,
            initialOccupants,
            initialYields
        );

        return initCalldata;
    }
}

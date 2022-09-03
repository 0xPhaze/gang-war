// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "/Constants.sol";
import "/lib/VRFConsumerV2.sol";

import {Mice} from "/tokens/Mice.sol";
import {GangWar} from "/GangWar.sol";
import {GMCChild} from "/tokens/GMCChild.sol";
import {GangVault} from "/GangVault.sol";
import {GangToken} from "/tokens/GangToken.sol";

import {MockGMCChild} from "../test/mocks/MockGMCChild.sol";
import {MockGangWar} from "../test/mocks/MockGangWar.sol";
import {MockVRFCoordinator} from "../test/mocks/MockVRFCoordinator.sol";

import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import "futils/futils.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {UpgradeScripts} from "upgrade-scripts/UpgradeScripts.sol";

contract GangWarSetup is UpgradeScripts {
    using futils for *;

    MockGMCChild gmc;
    GangToken[3] tokens;
    GangToken badges;
    Mice mice;
    MockGangWar game;
    GangVault vault;
    MockERC20 gouda;

    address coordinator;

    // ---------------- vars

    uint256 constant GANGSTER_YAKUZA_1 = 1;
    uint256 constant GANGSTER_CARTEL_1 = 2;
    uint256 constant GANGSTER_CYBERP_1 = 3;
    uint256 constant GANGSTER_YAKUZA_2 = 4;
    uint256 constant GANGSTER_CARTEL_2 = 5;
    uint256 constant GANGSTER_CYBERP_2 = 6;
    uint256 constant GANGSTER_YAKUZA_3 = 7;
    uint256 constant GANGSTER_CARTEL_3 = 8;
    uint256 constant GANGSTER_CYBERP_3 = 9;

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

    address linkCoordinator;
    bytes32 linkKeyHash;
    uint64 linkSubId;

    constructor() {
        if (block.chainid == 31337) {
            vm.warp(1660993892);
            vm.roll(27702338);
        }

        setUpGangWarConstants();
        setUpChainlinkParams();
    }

    function setUpContractsTEST() internal {
        coordinator = setUpContract("MockVRFCoordinator");

        address gmcImpl = setUpContract("MockGMCChild", abi.encode(address(0)));
        gmc = MockGMCChild(setUpProxy(gmcImpl, abi.encodePacked(GMCChild.init.selector), "GMC"));

        bytes memory goudaArgs = abi.encode("Gouda", "GOUDA", 18);
        gouda = MockERC20(setUpContract("MockERC20", goudaArgs, "GOUDA"));

        vm.label(address(gmc), "GMC");
        vm.label(address(gouda), "GOUDA");
        vm.label(address(coordinator), "coordinator");

        setUpContractsCommon();
    }

    function setUpContractsCommon() internal {
        bytes memory yakuzaInitCall = abi.encodeWithSelector(GangToken.init.selector, "Yakuza Token", "YKZ");
        bytes memory cartelInitCall = abi.encodeWithSelector(GangToken.init.selector, "CARTEL Token", "CTL");
        bytes memory cyberpInitCall = abi.encodeWithSelector(GangToken.init.selector, "Cyberpunk Token", "CBP");
        bytes memory badgesInitCall = abi.encodeWithSelector(GangToken.init.selector, "Badges", "BADGE");

        address gangTokenImpl = setUpContract("GangToken");

        tokens[0] = GangToken(setUpProxy(gangTokenImpl, yakuzaInitCall, "YakuzaToken"));
        tokens[1] = GangToken(setUpProxy(gangTokenImpl, cartelInitCall, "CartelToken"));
        tokens[2] = GangToken(setUpProxy(gangTokenImpl, cyberpInitCall, "CyberpunkToken"));
        badges = GangToken(setUpProxy(gangTokenImpl, badgesInitCall, "Badges"));

        bytes memory miceArgs = abi.encode(tokens[0], tokens[1], tokens[2], badges);
        bytes memory vaultArgs = abi.encode(tokens[0], tokens[1], tokens[2], GANG_VAULT_FEE);

        address vaultImpl = setUpContract("GangVault", vaultArgs);
        vault = GangVault(setUpProxy(vaultImpl, abi.encode(GangVault.init.selector)));

        address miceImpl = setUpContract("Mice", miceArgs);
        mice = Mice(setUpProxy(miceImpl, abi.encode(Mice.init.selector)));

        bytes memory gangWarArgs = abi.encode(
            gmc,
            vault,
            badges,
            connectionsPacked,
            coordinator,
            linkKeyHash,
            linkSubId,
            3,
            200_000
        );

        address gangWarImpl;

        if (isTestnet()) {
            gangWarImpl = setUpContract("MockGangWar", gangWarArgs);
        } else {
            gangWarImpl = setUpContract("GangWar", gangWarArgs);
        }

        game = MockGangWar(setUpProxy(gangWarImpl, abi.encodeCall(GangWar.init, ()))); // prettier-ignore

        vm.label(address(game), "GangWar");
        vm.label(address(mice), "Mice");
        vm.label(address(vault), "GangVault");
        vm.label(address(badges), "Badges");
        vm.label(address(tokens[0]), "YakuzaToken");
        vm.label(address(tokens[1]), "CartelToken");
        vm.label(address(tokens[2]), "CyberpunkToken");
    }

    function setUpContractsTestnet() internal {
        setUpContractsTEST();
    }

    function setUpContracts() internal {
        // setUpContractsCommon();
        // (
        //     ,
        //     /* coordinator */
        //     bytes32 keyHash,
        //     uint64 subId
        // ) = setUpChainlinkParams();
        // revert();
        // need to attach / create gouda child, gmc child
    }

    bytes32 constant GANG_VAULT_CONTROLLER = keccak256("GANG.VAULT.CONTROLLER");

    function initContracts() internal {
        gmc.setGangVault(address(vault));
        // game.setGangVault(address(vault));

        tokens[0].grantMintAuthority(address(vault));
        tokens[1].grantMintAuthority(address(vault));
        tokens[2].grantMintAuthority(address(vault));
        badges.grantMintAuthority(address(game));

        tokens[0].grantBurnAuthority(address(mice));
        tokens[1].grantBurnAuthority(address(mice));
        tokens[2].grantBurnAuthority(address(mice));
        badges.grantBurnAuthority(address(mice));

        vault.grantRole(GANG_VAULT_CONTROLLER, address(gmc));
        vault.grantRole(GANG_VAULT_CONTROLLER, address(game));

        game.setBaronItemCost(ITEM_SEWER, 3_000_000e18);
        game.setBaronItemCost(ITEM_BLITZ, 3_000_000e18);
        game.setBaronItemCost(ITEM_BARRICADES, 2_250_000e18);
        game.setBaronItemCost(ITEM_SMOKE, 2_250_000e18);
        game.setBaronItemCost(ITEM_911, 1_500_000e18);

        game.setBriberyFee(address(gouda), 2e18);

        game.reset(occupants, yields);
    }

    bytes32 constant MINT_AUTHORITY = keccak256("MINT_AUTHORITY");
    bytes32 constant BURN_AUTHORITY = keccak256("BURN_AUTHORITY");

    function initContractsCI() internal {
        if (firstTimeDeployed[address(game)]) initContracts();
    }

    function initContractsCITestnet() internal {
        initContractsCI();

        address lumy = 0x2181838c46bEf020b8Beb756340ad385f5BD82a8;

        // grant mint authority for test purposes
        if (!tokens[0].hasRole(MINT_AUTHORITY, msg.sender)) tokens[0].grantMintAuthority(msg.sender);
        if (!tokens[1].hasRole(MINT_AUTHORITY, msg.sender)) tokens[1].grantMintAuthority(msg.sender);
        if (!tokens[2].hasRole(MINT_AUTHORITY, msg.sender)) tokens[2].grantMintAuthority(msg.sender);
        if (!badges.hasRole(MINT_AUTHORITY, msg.sender)) badges.grantMintAuthority(msg.sender);

        if (!tokens[0].hasRole(MINT_AUTHORITY, lumy)) tokens[0].grantMintAuthority(lumy);
        if (!tokens[1].hasRole(MINT_AUTHORITY, lumy)) tokens[1].grantMintAuthority(lumy);
        if (!tokens[2].hasRole(MINT_AUTHORITY, lumy)) tokens[2].grantMintAuthority(lumy);
        if (!badges.hasRole(MINT_AUTHORITY, lumy)) badges.grantMintAuthority(lumy);

        if (!vault.hasRole(GANG_VAULT_CONTROLLER, address(game))) vault.grantRole(GANG_VAULT_CONTROLLER, address(game));

        // mint tokens for testing
        if (firstTimeDeployed[address(game)]) {
            tokens[0].mint(msg.sender, 100_000e18);
            tokens[1].mint(msg.sender, 100_000e18);
            tokens[2].mint(msg.sender, 100_000e18);
            badges.mint(msg.sender, 100_000e18);

            tokens[0].mint(lumy, 100_000e18);
            tokens[1].mint(lumy, 100_000e18);
            tokens[2].mint(lumy, 100_000e18);
            badges.mint(lumy, 100_000e18);

            gmc.mintBatch(msg.sender);
            gmc.mintBatch(lumy);
        }

        // console.log(block.chainid);
        // console.log(block.timestamp);

        // Anvil y u so weird
        if (block.chainid == 31337) return;

        // note: go for owned ids?
        // setup a test attack

        // // prettier-ignore
        // if (uint8(game.getGangster(BARON_YAKUZA_1).state) == 0 && uint8(game.getDistrict(DISTRICT_CARTEL_1).state) == 0) {
        //     game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false);
        //     game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory());
        // }

        // // prettier-ignore
        // if (uint8(game.getGangster(BARON_YAKUZA_2).state) == 0 && uint8(game.getDistrict(DISTRICT_CARTEL_2).state) == 0) {
        //     game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_2, false);
        //     game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, [GANGSTER_YAKUZA_2].toMemory());
        // }

        // // setup a test attack
        // try game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, BARON_YAKUZA_1, false) {} catch {}
        // try game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_1, [GANGSTER_YAKUZA_1].toMemory()) {} catch {}

        // try game.baronDeclareAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, BARON_YAKUZA_2, false) {} catch {}
        // try game.joinGangAttack(DISTRICT_YAKUZA_1, DISTRICT_CARTEL_2, [GANGSTER_YAKUZA_2].toMemory()) {} catch {}
    }

    function setUpChainlinkParams() internal {
        if (block.chainid == 137) {
            coordinator = COORDINATOR_POLYGON;
            linkKeyHash = KEYHASH_POLYGON;
            linkSubId = 133;
        } else if (block.chainid == 80001) {
            coordinator = COORDINATOR_MUMBAI;
            linkKeyHash = KEYHASH_MUMBAI;
            linkSubId = 862;
        } else if (block.chainid == 4) {
            coordinator = COORDINATOR_RINKEBY;
            linkKeyHash = KEYHASH_RINKEBY;
            linkSubId = 6985;
        } else if (block.chainid == 31337) {
            // coordinator = COORDINATOR_RINKEBY;
            // linkKeyHash = KEYHASH_RINKEBY;
            // linkSubId = 6985;
        } else {
            revert("unknown chainid");
        }
    }

    // ---------------- constants

    uint256 connectionsPacked;
    bool[21][21] connections;
    Gang[21] occupants;
    uint256[21] yields;

    bool[22][22] connections_1;
    Gang[22] occupants_1;

    function setUpGangWarConstants() private {
        connections_1[1][2] = true;
        connections_1[1][3] = true;
        connections_1[1][8] = true;
        connections_1[1][9] = true;
        connections_1[1][11] = true;
        connections_1[2][1] = true;
        connections_1[2][9] = true;
        connections_1[2][10] = true;
        connections_1[2][11] = true;
        connections_1[3][1] = true;
        connections_1[3][4] = true;
        connections_1[3][11] = true;
        connections_1[3][12] = true;
        connections_1[3][13] = true;
        connections_1[4][3] = true;
        connections_1[4][5] = true;
        connections_1[4][13] = true;
        connections_1[4][14] = true;
        connections_1[4][15] = true;
        connections_1[5][4] = true;
        connections_1[5][6] = true;
        connections_1[5][7] = true;
        connections_1[5][15] = true;
        connections_1[6][5] = true;
        connections_1[6][7] = true;
        connections_1[6][15] = true;
        connections_1[7][5] = true;
        connections_1[7][6] = true;
        connections_1[7][8] = true;
        connections_1[7][16] = true;
        connections_1[8][1] = true;
        connections_1[8][7] = true;
        connections_1[8][9] = true;
        connections_1[8][16] = true;
        connections_1[8][17] = true;
        connections_1[9][1] = true;
        connections_1[9][2] = true;
        connections_1[9][8] = true;
        connections_1[9][17] = true;
        connections_1[9][18] = true;
        connections_1[10][2] = true;
        connections_1[10][11] = true;
        connections_1[10][18] = true;
        connections_1[10][19] = true;
        connections_1[11][1] = true;
        connections_1[11][2] = true;
        connections_1[11][3] = true;
        connections_1[11][10] = true;
        connections_1[11][12] = true;
        connections_1[12][3] = true;
        connections_1[12][11] = true;
        connections_1[12][13] = true;
        connections_1[12][20] = true;
        connections_1[13][3] = true;
        connections_1[13][4] = true;
        connections_1[13][12] = true;
        connections_1[13][14] = true;
        connections_1[13][20] = true;
        connections_1[13][21] = true;
        connections_1[14][4] = true;
        connections_1[14][13] = true;
        connections_1[14][15] = true;
        connections_1[14][21] = true;
        connections_1[15][4] = true;
        connections_1[15][5] = true;
        connections_1[15][6] = true;
        connections_1[15][14] = true;
        connections_1[16][7] = true;
        connections_1[16][8] = true;
        connections_1[16][17] = true;
        connections_1[17][8] = true;
        connections_1[17][9] = true;
        connections_1[17][16] = true;
        connections_1[17][18] = true;
        connections_1[18][9] = true;
        connections_1[18][10] = true;
        connections_1[18][17] = true;
        connections_1[18][19] = true;
        connections_1[19][10] = true;
        connections_1[19][18] = true;
        connections_1[20][12] = true;
        connections_1[20][13] = true;
        connections_1[20][21] = true;
        connections_1[21][13] = true;
        connections_1[21][14] = true;
        connections_1[21][20] = true;

        for (uint256 i; i < 21; i++) {
            for (uint256 j; j < 21; j++) {
                connections[i][j] = connections_1[i + 1][j + 1];
            }
        }

        connectionsPacked = LibPackedMap.encode(connections);

        // assembly { occupants_1.slot := sub(occupants.slot, 1) } // prettier-ignore

        occupants_1[3] = Gang.YAKUZA;
        occupants_1[4] = Gang.YAKUZA;
        occupants_1[12] = Gang.YAKUZA;
        occupants_1[13] = Gang.YAKUZA;
        occupants_1[14] = Gang.YAKUZA;
        occupants_1[20] = Gang.YAKUZA;
        occupants_1[21] = Gang.YAKUZA;

        occupants_1[1] = Gang.CARTEL;
        occupants_1[2] = Gang.CARTEL;
        occupants_1[9] = Gang.CARTEL;
        occupants_1[10] = Gang.CARTEL;
        occupants_1[11] = Gang.CARTEL;
        occupants_1[18] = Gang.CARTEL;
        occupants_1[19] = Gang.CARTEL;

        occupants_1[5] = Gang.CYBERP;
        occupants_1[6] = Gang.CYBERP;
        occupants_1[7] = Gang.CYBERP;
        occupants_1[8] = Gang.CYBERP;
        occupants_1[15] = Gang.CYBERP;
        occupants_1[16] = Gang.CYBERP;
        occupants_1[17] = Gang.CYBERP;

        for (uint256 i; i < 21; i++) occupants[i] = occupants_1[i + 1];

        uint256[22] storage yields_1;

        assembly { yields_1.slot := sub(yields.slot, 1) } // prettier-ignore

        yields_1[3] = 1_300_000;
        yields_1[4] = 1_000_000;
        yields_1[12] = 700_000;
        yields_1[13] = 1_000_000;
        yields_1[14] = 1_300_000;
        yields_1[20] = 1_700_000;
        yields_1[21] = 700_000;

        yields_1[1] = 1_300_000;
        yields_1[2] = 700_000;
        yields_1[9] = 1_000_000;
        yields_1[10] = 700_000;
        yields_1[11] = 1_300_000;
        yields_1[18] = 1_000_000;
        yields_1[19] = 1_700_000;

        yields_1[5] = 1_000_000;
        yields_1[6] = 1_700_000;
        yields_1[7] = 700_000;
        yields_1[8] = 1_000_000;
        yields_1[15] = 1_300_000;
        yields_1[16] = 700_000;
        yields_1[17] = 1_300_000;
    }
}

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
import {GoudaRootTunnel} from "/tokens/GoudaRootTunnel.sol";

import {MockGMCRoot} from "../test/mocks/MockGMCRoot.sol";
import {MockGMCChild} from "../test/mocks/MockGMCChild.sol";
import {MockGangWar} from "../test/mocks/MockGangWar.sol";
import {MockVRFCoordinator} from "../test/mocks/MockVRFCoordinator.sol";

import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import "futils/futils.sol";
import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {UpgradeScripts} from "upgrade-scripts/UpgradeScripts.sol";

contract GangWarSetupBase is UpgradeScripts {
    address coordinator;
    bytes32 linkKeyHash;
    uint64 linkSubId;

    address fxRoot;
    address fxChild;
    address fxRootCheckpointManager;

    uint256 constant CHAINID_MAINNET = 1;
    uint256 constant CHAINID_RINKEBY = 4;
    uint256 constant CHAINID_GOERLI = 5;
    uint256 constant CHAINID_POLYGON = 137;
    uint256 constant CHAINID_MUMBAI = 80_001;
    uint256 constant CHAINID_TEST = 31_337;

    address constant GOUDA_ROOT = 0x3aD30C5E3496BE07968579169a96f00D56De4C1A;

    constructor() {
        __setUpChainlink();
        __setUpFxPortal();

        vm.label(GOUDA_ROOT, "GOUDA_ROOT");

        if (fxRoot != address(0)) vm.label(fxRoot, "FXROOT");
        if (fxChild != address(0)) vm.label(fxChild, "FXCHILD");
        if (fxRootCheckpointManager != address(0)) vm.label(fxChild, "FXROOTCHKPT");
    }

    function __setUpChainlink() internal {
        if (block.chainid == CHAINID_POLYGON) {
            coordinator = COORDINATOR_POLYGON;
            linkKeyHash = KEYHASH_POLYGON;
            linkSubId = 133;
        } else if (block.chainid == CHAINID_MUMBAI) {
            coordinator = COORDINATOR_MUMBAI;
            // @note should set up with real vrf
            coordinator = setUpContract("MockVRFCoordinator");
            linkKeyHash = KEYHASH_MUMBAI;
            linkSubId = 862;
        } else if (block.chainid == CHAINID_RINKEBY) {
            coordinator = COORDINATOR_RINKEBY;
            linkKeyHash = KEYHASH_RINKEBY;
            linkSubId = 6985;
        } else if (block.chainid == CHAINID_TEST) {
            coordinator = setUpContract("MockVRFCoordinator");
            linkKeyHash = bytes32(uint256(123));
            linkSubId = 123;
        }
    }

    function __setUpFxPortal() internal {
        if (block.chainid == CHAINID_MAINNET) {
            fxRoot = 0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2;
            fxRootCheckpointManager = 0x86E4Dc95c7FBdBf52e33D563BbDB00823894C287;
        } else if (block.chainid == CHAINID_POLYGON) {
            fxChild = 0x8397259c983751DAf40400790063935a11afa28a;
        } else if (block.chainid == CHAINID_GOERLI) {
            fxRoot = 0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA;
            fxRootCheckpointManager = 0x2890bA17EfE978480615e330ecB65333b880928e;
        } else if (block.chainid == CHAINID_MUMBAI) {
            fxChild = 0xCf73231F28B7331BBe3124B907840A94851f9f11;
        }
    }
}

contract GangWarSetupRoot is GangWarSetupBase {
    MockERC20 gouda;
    MockGMCRoot gmc;
    GoudaRootTunnel goudaTunnel;

    function setUpContractsMainnet() internal {
        if (fxRootCheckpointManager == address(0) || fxRoot == address(0)) revert("Invalid FxPortal setup.");

        gouda = MockERC20(GOUDA_ROOT);

        setUpContractsCommon();
    }

    function setUpContractsTestnet() internal {
        bytes memory goudaArgs = abi.encode("Gouda", "GOUDA", 18);
        gouda = MockERC20(setUpContract("MockERC20", goudaArgs, "GoudaRoot"));

        setUpContractsCommon();
    }

    function setUpContractsCommon() internal {
        bytes memory goudaTunnelArgs = abi.encode(address(gouda), fxRootCheckpointManager, fxRoot);
        goudaTunnel = GoudaRootTunnel(setUpContract("GoudaRootTunnel", goudaTunnelArgs));

        bytes memory gmcArgs = abi.encode(fxRootCheckpointManager, fxRoot);
        gmc = MockGMCRoot(setUpContract("MockGMCRoot", gmcArgs, "GMCRoot"));

        linkWithChild();
    }

    function linkWithChild() internal {
        uint256 childChainId;

        if (block.chainid == CHAINID_GOERLI) childChainId = CHAINID_MUMBAI;
        if (block.chainid == CHAINID_MAINNET) childChainId = CHAINID_POLYGON;

        // @note change key to GMC!!!
        address latestFxChildTunnel = loadLatestDeployedAddress("GMCChild", childChainId);

        address fxChildTunnel = gmc.fxChildTunnel();

        if (latestFxChildTunnel == address(0)) {
            console.log("\nWARNING: No latest GMCChild deployment found for child chain %s:", childChainId);
            throwError("!! fxChildTunnel unset (MUST be set for root!!) !!");
        } else {
            if (fxChildTunnel != latestFxChildTunnel) {
                console.log("\n  => Updating fxChildTunnel: %s -> %s::GMCChild(%s)", fxChildTunnel, childChainId, latestFxChildTunnel); // prettier-ignore

                gmc.setFxChildTunnel(latestFxChildTunnel);
            } else {
                console.log("Child tunnel up-to-date: %s::GMCChild(%s)", childChainId, fxChildTunnel);
            }
        }
    }
}

contract GangWarSetup is GangWarSetupBase {
    using futils for *;

    Mice mice;
    MockERC20 gouda;
    GangVault vault;
    GangToken badges;
    MockGangWar game;
    MockGMCChild gmc;
    GangToken[3] tokens;

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

    constructor() {
        if (block.chainid == CHAINID_TEST) {
            vm.warp(1660993892);
            vm.roll(27702338);
        }

        __setUpGangWarConstants();
    }

    function setUpContractsTEST() internal {
        address gmcImpl = setUpContract("MockGMCChild", abi.encode(address(0)));
        gmc = MockGMCChild(setUpProxy(gmcImpl, abi.encodePacked(GMCChild.init.selector), "GMCChild"));

        bytes memory goudaArgs = abi.encode("Gouda", "GOUDA", 18);
        gouda = MockERC20(setUpContract("MockERC20", goudaArgs, "GoudaChild"));

        setUpContractsCommon();
    }

    function setUpContractsCommon() internal {
        if (coordinator == address(0) || linkKeyHash == 0 || linkSubId == 0) revert("Invalid Chainlink setup.");

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

        address vaultImpl = setUpContract("GangVault", vaultArgs, "GangVaultImplementation");
        vault = GangVault(setUpProxy(vaultImpl, abi.encode(GangVault.init.selector), "Vault"));

        address miceImpl = setUpContract("Mice", miceArgs, "MiceImplementation");
        mice = Mice(setUpProxy(miceImpl, abi.encode(Mice.init.selector), "Mice"));

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
            gangWarImpl = setUpContract("MockGangWar", gangWarArgs, "GangWarImplementation");
        } else {
            gangWarImpl = setUpContract("GangWar", gangWarArgs, "GangWarImplementation");
        }

        game = MockGangWar(setUpProxy(gangWarImpl, abi.encodeCall(GangWar.init, ()), "GangWar")); // prettier-ignore
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
        // ) = __setUpChainlink();
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

    bytes32 constant MINT_AUTHORITY = keccak256("MINT.AUTHORITY");
    bytes32 constant BURN_AUTHORITY = keccak256("BURN.AUTHORITY");

    function initContractsCI() internal {
        if (firstTimeDeployed[block.chainid][address(game)]) initContracts();

        linkWithRoot();
    }

    function linkWithRoot() internal {
        uint256 rootChainId;
        if (block.chainid == CHAINID_MUMBAI) rootChainId = CHAINID_GOERLI;
        if (block.chainid == CHAINID_POLYGON) rootChainId = CHAINID_MAINNET;

        address latestFxRootTunnel = loadLatestDeployedAddress("GMCRoot", rootChainId);
        address fxRootTunnel = gmc.fxRootTunnel();

        if (latestFxRootTunnel == address(0)) {
            console.log("\nWARNING: No latest GMCRoot deployment found for root chain %s:", rootChainId);
            console.log("!! current fxRootTunnel (%s) not up-to-date !!", fxRootTunnel);
        } else {
            if (fxRootTunnel != latestFxRootTunnel) {
                console.log("\n  => Updating fxRootTunnel: %s -> %s::GMCRoot(%s)", fxRootTunnel, rootChainId, latestFxRootTunnel); // prettier-ignore

                gmc.setFxRootTunnel(latestFxRootTunnel);
            } else {
                console.log("Root tunnel up-to-date: %s::GMCRoot(%s)", rootChainId, fxRootTunnel);
            }
        }
    }

    function initContractsCITestnet() internal {
        initContractsCI();

        address lumy = 0x2181838c46bEf020b8Beb756340ad385f5BD82a8;
        address antoine = 0x4f41aFa6DcF74BD757549CD379CB042C63e66385;

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
        if (firstTimeDeployed[block.chainid][address(game)]) {
            tokens[0].mint(msg.sender, 100_000e18);
            tokens[1].mint(msg.sender, 100_000e18);
            tokens[2].mint(msg.sender, 100_000e18);
            badges.mint(msg.sender, 100_000e18);

            tokens[0].mint(lumy, 100_000e18);
            tokens[1].mint(lumy, 100_000e18);
            tokens[2].mint(lumy, 100_000e18);
            badges.mint(lumy, 100_000e18);

            tokens[0].mint(antoine, 100_000e18);
            tokens[1].mint(antoine, 100_000e18);
            tokens[2].mint(antoine, 100_000e18);
            badges.mint(antoine, 100_000e18);

            gmc.mintBatch(msg.sender);
            gmc.mintBatch(antoine);
            gmc.mintBatch(lumy);
        }

        // console.log(block.chainid);
        // console.log(block.timestamp);

        // Anvil y u so weird
        if (block.chainid == CHAINID_TEST) return;

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

    // ---------------- constants

    uint256 connectionsPacked;
    bool[21][21] connections;
    Gang[21] occupants;
    uint256[21] yields;

    bool[22][22] connections_1;
    Gang[22] occupants_1;

    function __setUpGangWarConstants() private {
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

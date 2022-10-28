// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "/GangWar.sol";
import "/lib/VRFConsumerV2.sol";

import {Mice} from "/tokens/Mice.sol";
// import {GangWar} from "/GangWar.sol";
import {GangToken} from "/tokens/GangToken.sol";
import {SafeHouses} from "/tokens/SafeHouses.sol";
import {GoudaChild} from "/tokens/GoudaChild.sol";
import {StaticProxy} from "/utils/StaticProxy.sol";
import {LibPackedMap} from "./lib/LibPackedMap.sol";
import {DIAMOND_STORAGE_GMC_MARKET} from "/GMCMarket.sol";
import {DIAMOND_STORAGE_GANG_WAR, SEASON} from "/GangWar.sol";
import {DIAMOND_STORAGE_GMC_CHILD, GMCChild} from "/tokens/GMCChild.sol";
import {DIAMOND_STORAGE_GANG_VAULT, DIAMOND_STORAGE_GANG_VAULT_FX, GangVault} from "/GangVault.sol";

// Root (only needed for mock testing tunnel on same chain)
import {GMC as GMCRoot} from "/tokens/GMCRoot.sol";
import {GoudaRootRelay} from "/tokens/GoudaRootRelay.sol";
// import {MockFxTunnel} from "../test/mocks/MockFxTunnel.sol";

import "./SetupBase.sol";
import "./SetupRoot.sol";

import "futils/futils.sol";

contract SetupChild is SetupRoot {
    using futils for *;

    address banana = 0xbC91347e80886453F3f8bBd6d7aC07C122D87735;
    address spit = 0x5c947eB80D096A5e332bF79bfDc9feb3D0a201d7;

    constructor() {
        setUpGangWarConstants();
    }

    function assertStorageSeasonSet() internal pure {
        // these can be completely/partially reset
        require(DIAMOND_STORAGE_GANG_WAR == keccak256(bytes(string.concat("diamond.storage.gang.war.", SEASON))), 'Storage season does not match.'); // prettier-ignore
        // require(DIAMOND_STORAGE_GANG_VAULT_FX == keccak256(bytes(string.concat("diamond.storage.gang.vault.", SEASON))), 'Storage season does not match.'); // prettier-ignore

        require(DIAMOND_STORAGE_GANG_VAULT == keccak256(bytes(string.concat("diamond.storage.gang.vault"))), 'Invalid storage location'); // prettier-ignore
        require(DIAMOND_STORAGE_GMC_MARKET == keccak256(bytes(string.concat("diamond.storage.gmc.market.v2"))), 'Invalid storage location'); // prettier-ignore
        // @note this one NEEDS TO STAY "rumble", because that's how it was initialized
        require(DIAMOND_STORAGE_GMC_CHILD == keccak256(bytes(string.concat("diamond.storage.gmc.child.season.rumble"))), 'Invalid storage location'); // prettier-ignore
    }

    function setUpContracts() internal virtual override {
        checkDeployConfirmation();

        assertStorageSeasonSet();

        setUpFxPortal();
        setUpChainlink();

        staticProxy = StaticProxy(setUpContract("StaticProxy")); // placeholder to disable UUPS contracts

        if (coordinator == address(0) || linkKeyHash == 0 || linkSubId == 0) revert("Invalid Chainlink setup.");

        bytes memory goudaArgs = abi.encode(fxChild);
        bytes memory goudaInit = abi.encodeWithSelector(GoudaChild.init.selector);

        address goudaChildImplementation = setUpContract("GoudaChild", goudaArgs, "GoudaChildImplementation");
        gouda = GoudaChild(setUpProxy(goudaChildImplementation, goudaInit, "GoudaChild"));

        bytes memory yakuzaInitCall = abi.encodeWithSelector(GangToken.init.selector, "Yakuza Token", "YKZ");
        bytes memory cartelInitCall = abi.encodeWithSelector(GangToken.init.selector, "CARTEL Token", "CTL");
        bytes memory cyberpInitCall = abi.encodeWithSelector(GangToken.init.selector, "Cyberpunk Token", "CBP");
        bytes memory badgesInitCall = abi.encodeWithSelector(GangToken.init.selector, "Badges", "BADGE");

        address gangTokenImpl = setUpContract("GangToken");

        badges = GangToken(setUpProxy(gangTokenImpl, badgesInitCall, "Badges"));
        tokens[0] = GangToken(setUpProxy(gangTokenImpl, yakuzaInitCall, "YakuzaToken"));
        tokens[1] = GangToken(setUpProxy(gangTokenImpl, cartelInitCall, "CartelToken"));
        tokens[2] = GangToken(setUpProxy(gangTokenImpl, cyberpInitCall, "CyberpunkToken"));

        bytes memory vaultArgs = abi.encode(tokens[0], tokens[1], tokens[2], GANG_VAULT_FEE); // prettier-ignore
        address vaultImpl = setUpContract("GangVault", vaultArgs, "GangVaultImplementation");
        vault = GangVault(setUpProxy(vaultImpl, abi.encode(GangVault.init.selector), "Vault"));

        bool DEMO = false;
        string memory GMCContractName = DEMO ? "GMCChildDemo" : "GMCChild";
        bytes memory gmcArgs = DEMO
            ? abi.encode(fxChild, address(vault), address(gouda))
            : abi.encode(fxChild, address(vault));
        address gmcImpl = setUpContract(GMCContractName, gmcArgs, "GMCChildImplementation");
        gmc = GMCChild(setUpProxy(gmcImpl, abi.encodeWithSelector(GMCChild.init.selector), "GMCChild"));

        setUpContract("GangProxy", abi.encode(gmc, 0), "YakuzaGangProxy");
        setUpContract("GangProxy", abi.encode(gmc, 1), "CartelGangProxy");
        setUpContract("GangProxy", abi.encode(gmc, 2), "CyberpunkGangProxy");

        bytes memory miceArgs = abi.encode(tokens[0], tokens[1], tokens[2], badges);
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
            1_500_000
        );

        bool keepExistingGangWar = false;
        address gangWarImpl = setUpContract("GangWar", gangWarArgs, "GangWarImplementation", keepExistingGangWar);
        game = GangWar(setUpProxy(gangWarImpl, abi.encodeWithSelector(GangWar.init.selector), "GangWar", keepExistingGangWar)); // prettier-ignore

        bytes memory safeHousesArgs = abi.encode(
            mice,
            badges,
            gouda,
            tokens[0],
            tokens[1],
            tokens[2],
            fxChild,
            coordinator,
            linkKeyHash,
            linkSubId,
            3,
            1_500_000
        );
        address safeHousesImplementation = setUpContract("SafeHouses", safeHousesArgs, "SafeHousesImplementation");
        safeHouses = SafeHouses(setUpProxy(safeHousesImplementation, abi.encodeWithSelector(SafeHouses.init.selector), "SafeHouses")); // prettier-ignore

        if (MOCK_TUNNEL_TESTING) {
            // should normally be deployed on root-chain
            // however mocking on same chain for easier testing
            SetupRoot.setUpContractsRoot();
        }

        initContractsChild();
        linkContractsWithRoot();
    }

    function linkContractsWithRoot() internal virtual {
        if (MOCK_TUNNEL_TESTING) {
            FxBaseChildTunnel(gmc).setFxRootTunnel(address(gmcRoot));
            FxBaseChildTunnel(gouda).setFxRootTunnel(address(goudaTunnel));
            FxBaseChildTunnel(safeHouses).setFxRootTunnel(address(safeHouseClaim));
        } else if (block.chainid != CHAINID_TEST) {
            linkWithRoot(address(gmc), "GMCRoot");
            linkWithRoot(address(gouda), "GoudaRootRelay");
            linkWithRoot(address(safeHouses), "SafeHouseClaim");
        }
    }

    bytes32 constant AUTHORITY = keccak256("AUTHORITY");
    bytes32 constant GANG_VAULT_CONTROLLER = keccak256("GANG.VAULT.CONTROLLER");

    function initContractsChild() internal virtual {
        bool firstDeployment = firstTimeDeployed[block.chainid][address(game)];

        // INIT
        if (firstDeployment) {
            badges.grantRole(AUTHORITY, address(game));
            tokens[0].grantRole(AUTHORITY, address(vault));
            tokens[1].grantRole(AUTHORITY, address(vault));
            tokens[2].grantRole(AUTHORITY, address(vault));
            tokens[0].grantRole(AUTHORITY, address(safeHouses));
            tokens[1].grantRole(AUTHORITY, address(safeHouses));
            tokens[2].grantRole(AUTHORITY, address(safeHouses));

            badges.grantRole(AUTHORITY, address(mice));
            tokens[0].grantRole(AUTHORITY, address(mice));
            tokens[1].grantRole(AUTHORITY, address(mice));
            tokens[2].grantRole(AUTHORITY, address(mice));
            tokens[0].grantRole(AUTHORITY, address(safeHouses));
            tokens[1].grantRole(AUTHORITY, address(safeHouses));
            tokens[2].grantRole(AUTHORITY, address(safeHouses));

            gouda.grantRole(AUTHORITY, address(gmc));
            gouda.grantRole(AUTHORITY, address(safeHouses));

            vault.grantRole(GANG_VAULT_CONTROLLER, address(gmc));
            vault.grantRole(GANG_VAULT_CONTROLLER, address(game));

            game.setBaronItemCost(ITEM_SEWER, 3_000_000e18);
            game.setBaronItemCost(ITEM_BLITZ, 3_000_000e18);
            game.setBaronItemCost(ITEM_BARRICADES, 2_250_000e18);
            game.setBaronItemCost(ITEM_SMOKE, 2_250_000e18);
            game.setBaronItemCost(ITEM_911, 1_500_000e18);

            game.setBriberyFee(address(gouda), 2e18);
            game.setBriberyFee(address(banana), 5e18);
            game.setBriberyFee(address(spit), 10e18);

            game.reset(occupants, yields);
            game.setBaronItemBalances(0.range(NUM_BARON_ITEMS), 3.repeat(NUM_BARON_ITEMS));
        }

        // CI: make sure permissions are good
        if (!firstDeployment) {
            if (!badges.hasRole(AUTHORITY, address(game))) badges.grantRole(AUTHORITY, address(game));
            if (!tokens[0].hasRole(AUTHORITY, address(vault))) tokens[0].grantRole(AUTHORITY, address(vault));
            if (!tokens[1].hasRole(AUTHORITY, address(vault))) tokens[1].grantRole(AUTHORITY, address(vault));
            if (!tokens[2].hasRole(AUTHORITY, address(vault))) tokens[2].grantRole(AUTHORITY, address(vault));

            if (!badges.hasRole(AUTHORITY, address(mice))) badges.grantRole(AUTHORITY, address(mice));
            if (!tokens[0].hasRole(AUTHORITY, address(mice))) tokens[0].grantRole(AUTHORITY, address(mice));
            if (!tokens[1].hasRole(AUTHORITY, address(mice))) tokens[1].grantRole(AUTHORITY, address(mice));
            if (!tokens[2].hasRole(AUTHORITY, address(mice))) tokens[2].grantRole(AUTHORITY, address(mice));

            if (!gouda.hasRole(AUTHORITY, address(gmc))) gouda.grantRole(AUTHORITY, address(gmc));

            if (!vault.hasRole(GANG_VAULT_CONTROLLER, address(gmc)))
                vault.grantRole(GANG_VAULT_CONTROLLER, address(gmc));
            if (!vault.hasRole(GANG_VAULT_CONTROLLER, address(game)))
                vault.grantRole(GANG_VAULT_CONTROLLER, address(game));

            if (game.briberyFee(address(gouda)) == 0) {
                game.setBriberyFee(address(gouda), 2e18);
                game.setBriberyFee(address(banana), 5e18);
                game.setBriberyFee(address(spit), 10e18);
            }

            if (game.baronItemCost(0) == 0) {
                game.setBaronItemCost(ITEM_SEWER, 3_000_000e18);
                game.setBaronItemCost(ITEM_BLITZ, 3_000_000e18);
                game.setBaronItemCost(ITEM_BARRICADES, 2_250_000e18);
                game.setBaronItemCost(ITEM_SMOKE, 2_250_000e18);
                game.setBaronItemCost(ITEM_911, 1_500_000e18);
            }

            // game.reset(occupants, yields);
        }
    }

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
    uint256 constant BARON_YAKUZA_2 = 10_002;
    uint256 constant BARON_CARTEL_1 = 10_008;
    uint256 constant BARON_CARTEL_2 = 10_009;
    uint256 constant BARON_CYBERP_1 = 10_015;
    uint256 constant BARON_CYBERP_2 = 10_016;

    uint256 constant DISTRICT_YAKUZA_1 = 2;
    uint256 constant DISTRICT_CARTEL_1 = 0;
    uint256 constant DISTRICT_CYBERP_1 = 7;
    uint256 constant DISTRICT_YAKUZA_2 = 3;
    uint256 constant DISTRICT_CARTEL_2 = 10;
    uint256 constant DISTRICT_CYBERP_2 = 4;

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
        yields_1[6] = 1_300_000;
        yields_1[7] = 700_000;
        yields_1[8] = 1_000_000;
        yields_1[15] = 1_300_000;
        yields_1[16] = 1_700_000;
        yields_1[17] = 700_000;
    }
}

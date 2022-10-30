// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {MockFxTunnel} from "fx-contracts/../test/mocks/MockFxTunnel.sol";
import {UpgradeScripts} from "upgrade-scripts/UpgradeScripts.sol";
import {FxBaseRootTunnel} from "fx-contracts/base/FxBaseRootTunnel.sol";
import {FxBaseChildTunnel} from "fx-contracts/base/FxBaseChildTunnel.sol";

import {MockGenesis} from "../test/mocks/MockGenesis.sol";
import {MockVRFCoordinator} from "../test/mocks/MockVRFCoordinator.sol";

// ROOT
import {GMC as GMCRoot} from "/tokens/GMCRoot.sol";
import {GoudaRootRelay} from "/tokens/GoudaRootRelay.sol";
import {SafeHouseClaim} from "/tokens/SafeHouseClaim.sol";

import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

// CHILD
import "/GangWar.sol";
import "/lib/VRFConsumerV2.sol";
import {Mice} from "/tokens/Mice.sol";
import {GangToken} from "/tokens/GangToken.sol";
import {SafeHouses} from "/tokens/SafeHouses.sol";
import {GoudaChild} from "/tokens/GoudaChild.sol";
import {StaticProxy} from "/utils/StaticProxy.sol";
import {LibPackedMap} from "./lib/LibPackedMap.sol";
import {DIAMOND_STORAGE_GMC_MARKET} from "/GMCMarket.sol";
import {DIAMOND_STORAGE_GANG_WAR, SEASON} from "/GangWar.sol";
import {DIAMOND_STORAGE_GMC_CHILD, GMCChild} from "/tokens/GMCChild.sol";
import {DIAMOND_STORAGE_GANG_VAULT, DIAMOND_STORAGE_GANG_VAULT_FX, GangVault} from "/GangVault.sol";

contract SetupBase is UpgradeScripts {
    // chainlink
    address coordinator;
    bytes32 linkKeyHash;
    uint64 linkSubId;

    // PoS Bridge
    address fxRoot;
    address fxChild;
    address fxRootCheckpointManager;

    uint256 chainIdChild;
    uint256 chainIdRoot;

    // set to true to deploy MockFxTunnel (mock tunnel on same chain)
    bool MOCK_TUNNEL_TESTING = block.chainid == CHAINID_TEST;

    // Chains
    uint256 constant CHAINID_MAINNET = 1;
    uint256 constant CHAINID_RINKEBY = 4;
    uint256 constant CHAINID_GOERLI = 5;
    uint256 constant CHAINID_POLYGON = 137;
    uint256 constant CHAINID_MUMBAI = 80_001;
    uint256 constant CHAINID_TEST = 31_337;

    uint256 lastDeployConfirmation = 1666527177;

    // ROOT
    GMCRoot gmcRoot;
    GoudaRootRelay goudaTunnel;
    SafeHouseClaim safeHouseClaim;
    MockERC20 goudaRoot = MockERC20(0x3aD30C5E3496BE07968579169a96f00D56De4C1A);
    MockGenesis troupe = MockGenesis(0x74d9d90a7fc261FBe92eD47B606b6E0E00d75E70);
    MockGenesis genesis = MockGenesis(0x3aD30c5e2985e960E89F4a28eFc91BA73e104b77);

    // CHILD
    Mice mice;
    GangWar game;
    GMCChild gmc;
    GangVault vault;
    GangToken badges;
    GoudaChild gouda;
    GangToken[3] tokens;
    StaticProxy staticProxy;
    SafeHouses safeHouses;

    constructor() {
        if (block.chainid == CHAINID_TEST) {
            vm.warp(1660993892);
            vm.roll(27702338);
        }
    }

    function checkDeployConfirmation() internal {
        if (!isTestnet() && !UPGRADE_SCRIPTS_DRY_RUN) {
            if (block.timestamp - lastDeployConfirmation > 10 minutes) {
                console.log("\nMust reconfirm mainnet deployment:");
                console.log("```");
                console.log("uint256 lastDeployConfirmation = %s;", block.timestamp);
                console.log("```");
                revert(
                    string.concat(
                        "CONFIRMATION REQUIRED: \n```\nuint256 lastDeployConfirmation = ",
                        vm.toString(block.timestamp),
                        ";\n```"
                    )
                );
            }
        }
    }

    function setUpChainlink() internal {
        if (block.chainid == CHAINID_POLYGON) {
            coordinator = COORDINATOR_POLYGON;
            linkKeyHash = KEYHASH_POLYGON;
            linkSubId = 344;
        } else if (block.chainid == CHAINID_MUMBAI) {
            coordinator = COORDINATOR_MUMBAI;
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

    function setUpFxPortal() internal {
        if (MOCK_TUNNEL_TESTING && !isTestnet()) revert("Mock Tunnel not allowed on mainnet.");

        if (MOCK_TUNNEL_TESTING) {
            // link these on same chain via MockTunnel for testing
            fxChild = fxRoot = setUpContract("MockFxTunnel");
            chainIdRoot = block.chainid;
            chainIdChild = block.chainid;
        } else if (block.chainid == CHAINID_MAINNET) {
            chainIdChild = CHAINID_POLYGON;

            fxRoot = 0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2;
            fxRootCheckpointManager = 0x86E4Dc95c7FBdBf52e33D563BbDB00823894C287;
        } else if (block.chainid == CHAINID_POLYGON) {
            chainIdRoot = CHAINID_MAINNET;

            fxChild = 0x8397259c983751DAf40400790063935a11afa28a;
        } else if (block.chainid == CHAINID_GOERLI) {
            chainIdChild = CHAINID_MUMBAI;

            fxRoot = 0x3d1d3E34f7fB6D26245E6640E1c50710eFFf15bA;
            fxRootCheckpointManager = 0x2890bA17EfE978480615e330ecB65333b880928e;
        } else if (block.chainid == CHAINID_MUMBAI) {
            chainIdRoot = CHAINID_GOERLI;

            fxChild = 0xCf73231F28B7331BBe3124B907840A94851f9f11;
        } else if (block.chainid == CHAINID_RINKEBY) {}

        if (fxRoot != address(0)) vm.label(fxRoot, "FXROOT");
        if (fxChild != address(0)) vm.label(fxChild, "FXCHILD");
        if (fxRootCheckpointManager != address(0)) vm.label(fxChild, "FXROOTCHKPT");
    }

    function linkWithChild(address root, string memory childKey) internal {
        if (chainIdChild == 0) revert("Child chain id unset.");

        address fxChildTunnel = FxBaseRootTunnel(root).fxChildTunnel();
        address latestFxChildTunnel = registeredContractAddress[chainIdChild][childKey]; // can be on same chain for testing

        // bypassing here, as we'll only be working on 1 chain at most when testing
        if (UPGRADE_SCRIPTS_BYPASS) return FxBaseRootTunnel(root).setFxChildTunnel(latestFxChildTunnel);

        if (latestFxChildTunnel == address(0)) latestFxChildTunnel = loadLatestDeployedAddress(childKey, chainIdChild);
        if (latestFxChildTunnel == address(0)) {
            console.log("\nWARNING: No latest deployment found for [%s] on child chain %s:", childKey, chainIdChild);

            // throwError("!! fxChildTunnel unset (MUST be set for root!!) !!");
        } else {
            if (fxChildTunnel != latestFxChildTunnel) {
                console.log("\nLinking tunnel on chains %s -> %s", block.chainid, chainIdChild);
                console.log("=> Updating fxChildTunnel: %s -> %s(%s)", fxChildTunnel, childKey, latestFxChildTunnel); // prettier-ignore

                FxBaseRootTunnel(root).setFxChildTunnel(latestFxChildTunnel);
            } else {
                console.log("Child tunnel linked: %s::%s(%s)", chainIdChild, childKey, fxChildTunnel);
            }
        }
    }

    function linkWithRoot(address child, string memory rootKey) internal {
        if (chainIdRoot == 0) revert("Root chain id unset.");

        address fxRootTunnel = FxBaseChildTunnel(child).fxRootTunnel();
        address latestFxRootTunnel = registeredContractAddress[chainIdRoot][rootKey]; // can be on same chain for testing

        // bypassing here, as we'll only be working on 1 chain at most when testing
        if (UPGRADE_SCRIPTS_BYPASS) return FxBaseChildTunnel(child).setFxRootTunnel(latestFxRootTunnel);

        if (latestFxRootTunnel == address(0)) latestFxRootTunnel = loadLatestDeployedAddress(rootKey, chainIdRoot);
        if (latestFxRootTunnel == address(0)) {
            console.log("\nWARNING: No latest %s deployment found for root chain %s:", rootKey, chainIdRoot);
            console.log("!! current fxRootTunnel (%s) not linked !!", fxRootTunnel);
        } else {
            if (fxRootTunnel != latestFxRootTunnel) {
                console.log("\nLinking tunnel on chains %s -> %s", block.chainid, chainIdRoot);
                console.log("=> Updating fxRootTunnel: %s -> %s(%s)", fxRootTunnel, rootKey, latestFxRootTunnel); // prettier-ignore

                FxBaseChildTunnel(child).setFxRootTunnel(latestFxRootTunnel);
            } else {
                console.log("Root tunnel linked: %s::%s(%s)", chainIdRoot, rootKey, fxRootTunnel);
            }
        }
    }
}

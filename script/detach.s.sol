// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {SetupChild} from "../src/SetupChild.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {UpgradeScripts} from "upgrade-scripts/UpgradeScripts.sol";
import {StaticProxy, DIAMOND_STORAGE_STATIC_PROXY} from "/utils/StaticProxy.sol";

/* 

# Anvil
source .env && US_DRY_RUN=true forge script detach --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script detach --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Mumbai
source .env && US_DRY_RUN=true forge script detach --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script detach --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --broadcast 

*/

contract detach is SetupChild {
    bool ATTACH_ONLY;

    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_BYPASS_SAFETY = true;
        ATTACH_ONLY = true;
    }

    function upgradeProxy(address proxy, address newImplementation) internal override {
        address oldImplementation = loadProxyStoredImplementation(proxy);

        StaticProxy(proxy).upgradeToAndCall(newImplementation, abi.encodeCall(staticProxy.init, (oldImplementation)));
    }

    function run() external {
        startBroadcastIfNotDryRun();

        setUpContract("GMCChild", abi.encode(address(0)), "GMCChildImplementation", ATTACH_ONLY);
        setUpContract("GoudaChild", "", "GoudaChildImplementation", ATTACH_ONLY);
        setUpContract("GangToken", "", "GangToken", ATTACH_ONLY);
        setUpContract("GangVault", "", "GangVaultImplementation", ATTACH_ONLY);
        setUpContract("Mice", "", "MiceImplementation", ATTACH_ONLY);
        setUpContract("GangWar", "", "GangWarImplementation", ATTACH_ONLY);

        staticProxy = StaticProxy(setUpContract("StaticProxy")); // placeholder to disable UUPS contracts

        setUpProxy(address(staticProxy), abi.encodeCall(staticProxy.init, (address(gmc))), "GMCChild");
        setUpProxy(address(staticProxy), abi.encodeCall(staticProxy.init, (address(gouda))), "GoudaChild");

        setUpProxy(address(staticProxy), abi.encodeCall(staticProxy.init, (address(badges))), "Badges");
        setUpProxy(address(staticProxy), abi.encodeCall(staticProxy.init, (address(tokens[0]))), "YakuzaToken");
        setUpProxy(address(staticProxy), abi.encodeCall(staticProxy.init, (address(tokens[1]))), "CartelToken");
        setUpProxy(address(staticProxy), abi.encodeCall(staticProxy.init, (address(tokens[2]))), "CyberpunkToken");

        setUpProxy(address(staticProxy), abi.encodeCall(staticProxy.init, (address(vault))), "Vault");
        setUpProxy(address(staticProxy), abi.encodeCall(staticProxy.init, (address(mice))), "Mice");
        setUpProxy(address(staticProxy), abi.encodeCall(staticProxy.init, (address(game))), "GangWar");

        vm.stopBroadcast();

        storeDeployments();
    }

    // function isStaticProxy(address proxy) internal view returns (bool isStatic) {
    //     try StaticProxy(proxy).isStaticProxy() returns (bool isStatic_) {
    //         isStatic = isStatic_;
    //     } catch {}
    // }

    // function upgradeProxy(address proxy, address newImplementation) internal override {
    //     if (isStaticProxy(proxy)) {
    //         console.log("Static upgrade to %s.", newImplementation);

    //         StaticProxy(proxy).upgradeToAndCall(proxy, abi.encodeCall(StaticProxy.init, (newImplementation)));
    //     } else {
    //         // normal proxy
    //         StaticProxy(proxy).upgradeToAndCall(newImplementation, "");
    //     }
    // }

    // function loadProxyStoredImplementation(address proxy, string memory label)
    //     internal
    //     override
    //     returns (address implementation)
    // {
    //     if (isStaticProxy(proxy)) {
    //         try vm.load(proxy, DIAMOND_STORAGE_STATIC_PROXY) returns (bytes32 data) {
    //             implementation = address(uint160(uint256(data)));
    //         } catch {}

    //         console.log("Loading static proxy implementation %s.", implementation);
    //     } else {
    //         return UpgradeScripts.loadProxyStoredImplementation(proxy, label);
    //     }
    // }
}

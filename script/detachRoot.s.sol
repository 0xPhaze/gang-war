// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {SetupRoot} from "../src/SetupRoot.sol";
import {StaticProxy} from "/utils/StaticProxy.sol";

/* 
# ANVIL
source .env && US_DRY_RUN=true forge script detachRoot --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script detachRoot --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# 2: Simulate
source .env && US_DRY_RUN=true forge script detachRoot --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --with-gas-price 8gwei -vvvv --ffi

# 3: Deploy
source .env && forge script detachRoot --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 8gwei -vvvv --ffi --broadcast 

*/

contract detachRoot is SetupRoot {
    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_BYPASS_SAFETY = true;
    }

    function upgradeProxy(address proxy, address newImplementation) internal override {
        address oldImplementation = loadProxyStoredImplementation(proxy);

        StaticProxy(proxy).upgradeToAndCall(newImplementation, abi.encodeCall(staticProxy.init, (oldImplementation)));
    }

    function run() external {
        startBroadcastIfNotDryRun();

        staticProxy = StaticProxy(setUpContract("StaticProxy")); // placeholder to disable UUPS contracts

        setUpProxy(address(staticProxy), abi.encodeCall(staticProxy.init, (address(0))), "GMCRoot");
        setUpProxy(address(staticProxy), abi.encodeCall(staticProxy.init, (address(0))), "GoudaRootRelay");

        vm.stopBroadcast();

        storeDeployments();
    }
}

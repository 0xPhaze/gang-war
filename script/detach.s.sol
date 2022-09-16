// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {SetupChild} from "../src/SetupChild.sol";
import {StaticProxy} from "/utils/StaticProxy.sol";

/* 
# Anvil
source .env && US_DRY_RUN=true forge script detach --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script detach --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Mumbai
source .env && US_DRY_RUN=true forge script detach --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --with-gas-price 11gwei -vvvv --ffi
source .env && forge script detach --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 11gwei -vvvv --ffi --broadcast 

*/

contract detach is SetupChild {
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
}

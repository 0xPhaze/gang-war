// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {GangWarSetupRoot} from "../src/Setup.sol";

// import "chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";
// function addConsumer(uint64 subId, address consumer) external override onlySubOwner(subId) nonReentrant {

/* 
# 1: Run Tests
forge test -vvv

# ANVIL
source .env && US_DRY_RUN=true forge script deployRoot --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script deployRoot --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# 2: Simulate
source .env && US_DRY_RUN=true forge script deployRoot --rpc-url $RPC_GOERLI --private-key $PRIVATE_KEY -vvvv --ffi

3 #: Deploy
source .env && forge script deployRoot --rpc-url $RPC_GOERLI --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv --ffi --broadcast 

cp ~/git/eth/GangWar/out/MockGMCRoot.sol/MockGMCRoot.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockERC20.sol/MockERC20.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/GoudaRootTunnel.sol/GoudaRootTunnel.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/deployments/5/deploy-latest.json ~/git/eth/gmc-website/data/deployments_5.json
*/

contract deployRoot is GangWarSetupRoot {
    function run() external {
        startBroadcastIfNotDryRun();

        if (isTestnet()) {
            setUpContractsTestnet();
        } else {
            setUpContractsMainnet();
        }

        vm.stopBroadcast();

        logDeployments();
        storeLatestDeployments();
    }
}

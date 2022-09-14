// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {SetupRoot} from "../src/SetupRoot.sol";

/* 

# Anvil
source .env && US_DRY_RUN=true forge script deployRoot --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script deployRoot --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Goerli
source .env && US_DRY_RUN=true forge script deployRoot --rpc-url $RPC_GOERLI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script deployRoot --rpc-url $RPC_GOERLI --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv --ffi --broadcast 

cp ~/git/eth/GangWar/out/GMCRoot.sol/GMC.json ~/git/eth/gmc-website/data/abi/GMCRoot.json
cp ~/git/eth/GangWar/out/MockERC20.sol/MockERC20.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/GoudaRootRelay.sol/GoudaRootRelay.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/deployments/5/deploy-latest.json ~/git/eth/gmc-website/data/deployments_5.json

*/

contract deployRoot is SetupRoot {
    function run() external {
        startBroadcastIfNotDryRun();

        setUpContracts();

        vm.stopBroadcast();

        storeDeployments();
    }
}

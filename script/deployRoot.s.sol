// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {SetupRoot} from "../src/SetupRoot.sol";

import "forge-std/Script.sol";
import "futils/futils.sol";

/* 
# Mainnet
source .env && US_DRY_RUN=true forge script deployRoot --rpc-url $RPC_MAINNET --private-key $PRIVATE_KEY_GMC -vvvv --ffi
source .env && forge script deployRoot --rpc-url $RPC_MAINNET --private-key $PRIVATE_KEY_GMC --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv --ffi --broadcast 

# Anvil
source .env && US_DRY_RUN=true forge script deployRoot --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script deployRoot --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Goerli
source .env && US_DRY_RUN=true forge script deployRoot --rpc-url $RPC_GOERLI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script deployRoot --rpc-url $RPC_GOERLI --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv --ffi --broadcast 

# Mumbai
source .env && US_DRY_RUN=true forge script deployRoot --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script deployRoot --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --broadcast 

cp ~/git/eth/gang-war/out/GMCRoot.sol/GMC.json ~/git/eth/gmc-website/data/abi/GMCRoot.json
cp ~/git/eth/gang-war/out/MockERC20.sol/MockERC20.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/GoudaRootRelay.sol/GoudaRootRelay.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/SafeHouseClaim.sol/SafeHouseClaim.json ~/git/eth/gmc-website/data/abi

cp ~/git/eth/gang-war/deployments/80001/deploy-latest.json ~/git/eth/gmc-website/data/deployments_80001.json
cp ~/git/eth/gang-war/deployments/137/deploy-latest.json ~/git/eth/gmc-website/data/deployments_137.json
cp ~/git/eth/gang-war/deployments/5/deploy-latest.json ~/git/eth/gmc-website/data/deployments_5.json
cp ~/git/eth/gang-war/deployments/1/deploy-latest.json ~/git/eth/gmc-website/data/deployments_1.json

*/

contract deployRoot is SetupRoot {
    using futils for *;

    function run() external {
        startBroadcastIfNotDryRun();

        setUpContracts();

        // gmc.airdrop([msg.sender].toMemory(), 500, false);

        // gmc.unlockAndTransmit(msg.sender, 1.range(10));
        // gmc.lockAndTransmit(msg.sender, 30.range(40));
        // gmc.lockAndTransmit(msg.sender, 50.range(80));

        // gmc.airdrop([msg.sender].toMemory(), 50, true);
        // gmc.airdrop([msg.sender].toMemory(), 100, true);
        // gmc.airdrop([msg.sender].toMemory(), 10, true);

        vm.stopBroadcast();

        storeDeployments();
    }
}

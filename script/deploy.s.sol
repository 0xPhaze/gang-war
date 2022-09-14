// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SetupChild} from "../src/SetupChild.sol";

import "forge-std/Script.sol";
import "futils/futils.sol";

/* 

# Polygon Mainnet 
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY -vvvv --ffi 
source .env && US_DRY_RUN=false forge script deploy --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 38gwei -vvvv --ffi --slow --broadcast 

# Anvil
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && US_DRY_RUN=false forge script deploy --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Mumbai
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && US_DRY_RUN=false forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 38gwei -vvvv --ffi --broadcast 

cp ~/git/eth/GangWar/out/GMCChild.sol/GMCChild.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockERC20.sol/MockERC20.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockVRFCoordinator.sol/MockVRFCoordinator.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/GangWar.sol/GangWar.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/GangVault.sol/GangVault.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/Mice.sol/Mice.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/deployments/80001/deploy-latest.json ~/git/eth/gmc-website/data/deployments_80001.json

*/

contract deploy is SetupChild {
    using futils for *;

    function run() external {
        startBroadcastIfNotDryRun();

        setUpContracts();

        vm.stopBroadcast();

        storeDeployments();
    }
}

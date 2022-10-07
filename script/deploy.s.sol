// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SetupChild} from "../src/SetupChild.sol";

import "/GangWar.sol";

import "forge-std/Script.sol";
import "futils/futils.sol";

/* 

# Polygon Mainnet 
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY -vvvv --ffi 
source .env && forge script deploy --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --slow --broadcast 

# Anvil
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script deploy --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Mumbai
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --broadcast 

cp ~/git/eth/gang-war/out/GMCChild.sol/GMCChild.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/GMCRoot.sol/GMC.json ~/git/eth/gmc-website/data/abi/GMCRoot.json
cp ~/git/eth/gang-war/out/GoudaChild.sol/GoudaChild.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/MockERC20.sol/MockERC20.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/MockVRFCoordinator.sol/MockVRFCoordinator.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/GangWar.sol/GangWar.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/GangVault.sol/GangVault.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/Mice.sol/Mice.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/deployments/80001/deploy-latest.json ~/git/eth/gmc-website/data/deployments_80001.json
cp ~/git/eth/gang-war/deployments/137/deploy-latest.json ~/git/eth/gmc-website/data/deployments_137.json
cp ~/git/eth/gang-war/deployments/1/deploy-latest.json ~/git/eth/gmc-website/data/deployments_1.json
cp ~/git/eth/gang-war/js/signaturesDemo.json ~/git/eth/gmc-website/data/
cp ~/git/eth/gang-war/js/signaturesGMCMint.json ~/git/eth/gmc-website/data/

*/

contract deploy is SetupChild {
    using futils for *;

    function run() external {
        startBroadcastIfNotDryRun();

        setUpContracts();

        game.reset(occupants, yields);
        game.setBaronItemBalances(0.range(NUM_BARON_ITEMS), 3.repeat(NUM_BARON_ITEMS));

        vm.stopBroadcast();

        storeDeployments();
    }
}

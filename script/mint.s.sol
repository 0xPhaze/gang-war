// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {SetupChild} from "../src/SetupChild.sol";

import "/GangWar.sol";
import "forge-std/Script.sol";

/* 

# Polygon Mainnet 
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY -vvvv --ffi 
source .env && forge script mint --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 8gwei -vvvv --ffi --slow --broadcast 

# Anvil
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script mint --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Mumbai
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script mint --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 8gwei -vvvv --ffi --broadcast 

*/

import "futils/futils.sol";

contract mint is SetupChild {
    using futils for *;

    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_ATTACH_ONLY = true;
    }

    function run() external {
        startBroadcastIfNotDryRun();

        setUpContracts();

        uint256[] memory ids = gmc.getOwnedIds(msg.sender);
        for (uint256 i; i < ids.length; i++) {
            console.log(ids[i]);
        }

        vm.stopBroadcast();
    }
}

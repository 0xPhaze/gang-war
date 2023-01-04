// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {SetupChild} from "../src/SetupChild.sol";

import "/GangWar.sol";
import "forge-std/Script.sol";

/* 

# Polygon Mainnet 
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY_GMC -vvvv --ffi 
source .env && forge script mint --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY_GMC --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --slow --broadcast

# Anvil
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script mint --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Mumbai
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script mint --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --broadcast 

#*/

import "futils/futils.sol";

contract mint is SetupChild {
    using futils for *;

    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_ATTACH_ONLY = true;
        MOCK_TUNNEL_TESTING = block.chainid == CHAINID_MUMBAI;
    }

    function run() external {
        startBroadcastIfNotDryRun();

        setUpContracts();

        // if (isTestnet()) {
        //     badges.grantRole(AUTHORITY, msg.sender);
        //     badges.grantRole(AUTHORITY, 0x2181838c46bEf020b8Beb756340ad385f5BD82a8);
        //     badges.mint(0x2181838c46bEf020b8Beb756340ad385f5BD82a8, 50000000e18);
        //     mice.grantRole(AUTHORITY, msg.sender);
        //     mice.grantRole(AUTHORITY, 0x2181838c46bEf020b8Beb756340ad385f5BD82a8);
        //     mice.mint(0x2181838c46bEf020b8Beb756340ad385f5BD82a8, 50000000e18);
        //     // console.log(genesis.getOwnedIds(0x68442589f40E8Fc3a9679dE62884c85C6E524888)[0]);
        //     // game.setBriberyFee(address(banana), 5e18);
        //     // game.setBriberyFee(address(spit), 10e18);
        //     // game.reset(occupants, yields);
        // }
    }
}

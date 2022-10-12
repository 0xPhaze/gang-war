// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {SetupChild} from "../src/SetupChild.sol";

import "/GangWar.sol";
import "forge-std/Script.sol";

/* 

# Polygon Mainnet 
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY -vvvv --ffi 
source .env && forge script mint --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --slow --broadcast 

# Anvil
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script mint --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Mumbai
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script mint --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --broadcast 

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

        //         gmc.resyncBarons([
        // '0x93085Af7a963E43C6b56C6ac2dc71cfe1Bd1923d',
        // '0x805a3b79917055a18abc171e14e4c7e36119d9b6',
        // '0x4b8ee1eEf0bD930c2277a60c839834B142B373d2',
        // '0xcea2c2b93CB242f64C8C3CF36e659cb0EC7d937e',
        // '0x409e5f34ae011e9df40e360ee37387fa8b0980cb',
        // '0x7Ce5039A2383ba2CDf57DF1a8Bd353E021c37492',
        // '0x49f2b78458B553229c51a389C811C4A73ae84C73',

        // '0xe2c32116ab0d54c80092d5150c97555ad37e0d63',
        // '0x983c09D36d78A8FB433a88499A95c73524954Af6',
        // '0x158e61A181959844D6Ac426a2A50eec065B3a943',
        // '0xd2bEC77b8BEcdDA350DDaA4Be3b0D91C119b6851',
        // '0x2d254aB8625f9738200E3D1e359e6b1Bf6e0E912',
        // '0x6C7AC914D586F7089e5a68375E0df549317c3eE8',
        // '0xB7fc617Da6546febfC31dfc8283B8588E192B3ec',

        // '0x6d711be0693b5ff41678ba3f4507c0bf1ae1ff17',
        // '0x673a278E13a5B6D34e43B3f7F936Ea89a7e6eEc7',
        // '0x5143b2f5e573be79aa5d96ae1367bfc6f095c4d9',
        // '0xb32b26d02cf757e61c824b1416013714a460483f',
        // '0x205C4d9d198a2e9D74eee70151d1Ba02f3C70Daa',
        // '0x02C1422931439B3e945e2F2F721c80F6c0feaF56',
        // '0x205FfDa46164C3e6ae60AF559c82F26f9470072E',
        //                  ]);
        vm.stopBroadcast();
    }
}

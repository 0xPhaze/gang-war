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
// import "solmate/test/utils/mocks/MockERC721.sol";

// contract TestMint {
//     constructor(address troupe) {
//         for (uint256 i; i < 20; i++) {
//             MockERC721(troupe).mint(0x2181838c46bEf020b8Beb756340ad385f5BD82a8, i);
//         }
//         for (uint256 i; i < 20; i++) {
//             MockERC721(troupe).mint(tx.origin, 20 + i);
//         }
//     }
// }

contract deployRoot is SetupRoot {
    using futils for *;

    constructor() {}

    function run() external {
        startBroadcastIfNotDryRun();

        setUpContracts();

        // troupe.airdrop([msg.sender, 0x2181838c46bEf020b8Beb756340ad385f5BD82a8].toMemory(), 20);
        // genesis.airdrop([msg.sender, 0x2181838c46bEf020b8Beb756340ad385f5BD82a8].toMemory(), 10);

        // new TestMint(address(troupe));

        // goudaRoot.mint(msg.sender, 100e18);
        // goudaRoot.approve(address(goudaTunnel), type(uint256).max);
        // goudaTunnel.lock(msg.sender, 50e18);

        // MockERC721(troupe).mint(tx.origin, 20 + i);
        // MockERC721(troupe).setApprovalForAll(address(safeHouseClaim), true);
        // uint256[][] memory ids = new uint256[][](1);
        // ids[0] = 26.range(31);
        // safeHouseClaim.claim(ids);

        vm.stopBroadcast();

        storeDeployments();
    }
}

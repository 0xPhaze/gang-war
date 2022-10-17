// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SetupChild} from "../src/SetupChild.sol";

import "/GangWar.sol";

import "forge-std/Script.sol";
import "futils/futils.sol";
import "solmate/test/utils/mocks/MockERC721.sol";

/* 

# Polygon Mainnet 
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY_GMC -vvvv --ffi 
source .env && forge script deploy --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY_GMC --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --slow --broadcast 

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
cp ~/git/eth/gang-war/out/SafeHouses.sol/SafeHouses.json ~/git/eth/gmc-website/data/abi

cp ~/git/eth/gang-war/out/GMCRoot.sol/GMC.json ~/git/eth/gmc-website/data/abi/GMCRoot.json
cp ~/git/eth/gang-war/out/MockERC20.sol/MockERC20.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/GoudaRootRelay.sol/GoudaRootRelay.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/SafeHouseClaim.sol/SafeHouseClaim.json ~/git/eth/gmc-website/data/abi

cp ~/git/eth/gang-war/deployments/80001/deploy-latest.json ~/git/eth/gmc-website/data/deployments_80001.json
cp ~/git/eth/gang-war/deployments/137/deploy-latest.json ~/git/eth/gmc-website/data/deployments_137.json
cp ~/git/eth/gang-war/deployments/5/deploy-latest.json ~/git/eth/gmc-website/data/deployments_5.json
cp ~/git/eth/gang-war/deployments/1/deploy-latest.json ~/git/eth/gmc-website/data/deployments_1.json

*/

contract deploy is SetupChild {
    using futils for *;

    function run() external {
        startBroadcastIfNotDryRun();

        setUpContracts();

        if (isTestnet()) {
            game.reset(occupants, yields);
            game.setBaronItemBalances(0.range(NUM_BARON_ITEMS), 3.repeat(NUM_BARON_ITEMS));
            game.setSeason(1665421200, 1668099600);
            gmc.resyncIds(msg.sender, 1.range(21));
            gmc.resyncIds(0x2181838c46bEf020b8Beb756340ad385f5BD82a8, 21.range(41));
            gmc.resyncBarons(
                [
                    msg.sender,
                    msg.sender,
                    msg.sender,
                    0x2181838c46bEf020b8Beb756340ad385f5BD82a8,
                    0x2181838c46bEf020b8Beb756340ad385f5BD82a8,
                    0x2181838c46bEf020b8Beb756340ad385f5BD82a8
                ].toMemory()
            );
            bytes32 CONTROLLER = keccak256("GANG.VAULT.CONTROLLER");
            vault.grantRole(CONTROLLER, msg.sender);
            vault.setYield(0, [uint256(7_700_000), 7_700_000, 7_700_000]);
            vault.setYield(1, [uint256(7_700_000), 7_700_000, 7_700_000]);
            vault.setYield(2, [uint256(7_700_000), 7_700_000, 7_700_000]);
        }

        // goudaRoot.mint(msg.sender, 100e18);
        // goudaRoot.approve(address(goudaTunnel), type(uint256).max);
        // goudaTunnel.lock(msg.sender, 50e18);

        vm.stopBroadcast();

        storeDeployments();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {SetupChild} from "../src/SetupChild.sol";

import "/Constants.sol";
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

        // game.reset(occupants, yields);
        // game.setBaronItemBalances(0.range(NUM_BARON_ITEMS), 3.repeat(NUM_BARON_ITEMS));
        // game.addBaronItemBalances(2, 0.range(NUM_BARON_ITEMS), 3.repeat(NUM_BARON_ITEMS));

        // if (isTestnet()) {
        //     // gouda.grantRole(AUTHORITY, msg.sender);

        //     sendBarons();
        //     // sendGangsters();
        // }

        vm.stopBroadcast();

        storeDeployments();
    }

    // uint256 constant NUM_BARONS_PER_PLAYER = 1;
    // uint256 constant NUM_GANGSTERS_PER_PLAYER = 10;
    // uint256 baronId = 10_001;
    // uint256 gangsterId = 1;

    // function sendBarons() internal {
    //     string memory baronJson = vm.readFile("script/dataBarons.json");
    //     address[] memory players = abi.decode(vm.parseJson(baronJson, ".players"), (address[]));
    //     uint256[] memory gangs = abi.decode(vm.parseJson(baronJson, ".gangs"), (uint256[]));

    //     require(players.length == gangs.length, "barons length mismatch");

    //     for (uint256 i; i < players.length && i <= 10 && i < 15; i++) {
    //         uint256[] memory baronIds = baronId.range(baronId + NUM_BARONS_PER_PLAYER);
    //         uint256[] memory gangsterIds = gangsterId.range(gangsterId + NUM_GANGSTERS_PER_PLAYER);

    //         gmc.resyncIds(players[i], baronIds.union(gangsterIds), gangs[i]);

    //         // if (gouda.balanceOf(players[i]) < 100e18) gouda.mint(players[i], 100e18);

    //         baronId += baronIds.length;
    //         gangsterId += gangsterIds.length;
    //     }
    // }

    // function sendGangsters() internal {
    //     string memory baronJson = vm.readFile("script/dataGangsters.json");
    //     address[] memory players = abi.decode(vm.parseJson(baronJson, ".players"), (address[]));
    //     uint256[] memory gangs = abi.decode(vm.parseJson(baronJson, ".gangs"), (uint256[]));

    //     require(players.length == gangs.length, "gangsters length mismatch");

    //     for (uint256 i; i < players.length && i < 10; i++) {
    //         uint256[] memory gangsterIds = gangsterId.range(gangsterId + NUM_GANGSTERS_PER_PLAYER);

    //         gmc.resyncIds(players[i], gangsterIds, gangs[i]);

    //         gangsterId += gangsterIds.length;

    //         // if (gouda.balanceOf(players[i]) < 100e18) gouda.mint(players[i], 100e18);
    //     }
    // }

    // function tryLoadEnvAddress(string memory key) internal returns (address user) {
    //     try vm.envAddress(key) returns (address user_) {
    //         user = user_;
    //     } catch {}
    // }
}

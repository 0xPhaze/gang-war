// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {SetupChild} from "../src/SetupChild.sol";

import "/Constants.sol";
import "forge-std/Script.sol";

/* 

# Polygon Mainnet 
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY -vvvv --ffi 
source .env && forge script mint --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 11gwei -vvvv --ffi --slow --broadcast 

# Anvil
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script mint --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Mumbai
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script mint --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 11gwei -vvvv --ffi --broadcast 

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

        if (isTestnet()) {
            // game.addBaronItem(0, 1, 3);
            // game.addBaronItem(1, 1, 3);
            // game.addBaronItem(2, 1, 3);

            // game.addBaronItem(0, 2, 3);
            // game.addBaronItem(1, 2, 3);
            // game.addBaronItem(2, 2, 3);

            // game.addBaronItem(0, 3, 3);
            // game.addBaronItem(1, 3, 3);
            // game.addBaronItem(2, 3, 3);

            // game.reset(occupants, yields);

            // vault.setYield(0, [uint256(0), 0, 0]);
            // vault.setYield(1, [uint256(0), 0, 0]);
            // vault.setYield(2, [uint256(0), 0, 0]);

            game.setBaronItemBalances(0.range(NUM_BARON_ITEMS), 3.repeat(NUM_BARON_ITEMS));

            // vault.setYield(0, [uint256(7700000), 7700000, 7700000]);
            // vault.setYield(1, [uint256(7700000), 7700000, 7700000]);
            // vault.setYield(2, [uint256(7700000), 7700000, 7700000]);

            // setUpAdmins();

            // sendIdsToPlayers();
        }

        vm.stopBroadcast();

        storeDeployments();
    }

    uint256 baronId = 1;
    uint256 gangsterId = 1;

    function setUpAdmins() internal {
        address[3] memory admin = [
            msg.sender,
            tryLoadEnvAddress("lumy"),
            tryLoadEnvAddress("antoine")
        ]; // prettier-ignore

        for (uint256 i; i < admin.length; i++) {
            address user = admin[i];
            if (user == address(0)) continue;

            if (!gouda.hasRole(AUTHORITY, user)) gouda.grantRole(AUTHORITY, user);
            if (!badges.hasRole(AUTHORITY, user)) badges.grantRole(AUTHORITY, user);
            if (!tokens[0].hasRole(AUTHORITY, user)) tokens[0].grantRole(AUTHORITY, user);
            if (!tokens[1].hasRole(AUTHORITY, user)) tokens[1].grantRole(AUTHORITY, user);
            if (!tokens[2].hasRole(AUTHORITY, user)) tokens[2].grantRole(AUTHORITY, user);

            if (gouda.balanceOf(user) < 100_000e18) gouda.mint(user, 100_000e18);
            if (badges.balanceOf(user) < 100_000e18) badges.mint(user, 100_000e18);
            if (tokens[0].balanceOf(user) < 100_000e18) tokens[0].mint(user, 100_000e18);
            if (tokens[1].balanceOf(user) < 100_000e18) tokens[1].mint(user, 100_000e18);
            if (tokens[2].balanceOf(user) < 100_000e18) tokens[2].mint(user, 100_000e18);
        }

        address[] memory baronUsers = abi
            .encode(
                admin[0],
                admin[1],
                admin[2],
                tryLoadEnvAddress("guden"),
                0x417C4b9885C9301f07a88162eBDBfDAde88a61fB,
                0x7534a35214Fe6BaBA32867373ab03a3fa9bc661E,
                0xB51c245AD7C9B17B2c01b23045a347895d1FA985,
                0x008524Ae46fbB63bcd1DCB1BB766eb9eD798B1B4
            )
            ._toAddressArray();

        for (uint256 i; i < baronUsers.length; i++) {
            address user = baronUsers[i];
            if (user == address(0)) continue;

            uint256[] memory baronIds = baronId.range(baronId + 6);
            uint256[] memory gangsterIds = gangsterId.range(gangsterId + 10);

            baronId += baronIds.length;
            gangsterId += gangsterIds.length;

            gmc.resyncIds(user, gangsterIds.union(baronIds));

            if (gouda.balanceOf(user) < 100_000e18) gouda.mint(user, 100_000e18);
        }
    }

    function sendIdsToPlayers() internal {
        Player[] memory players = abi.decode(playerData.toEncodedArrayType(0x40), (Player[]));

        uint256[] memory allIds;
        uint256[] memory allGangs;

        for (uint256 i; i < players.length; i++) {
            uint256[] memory gangsterIds = gangsterId.range(gangsterId + 3);

            gmc.resyncIds(players[i].wallet, gangsterIds);

            gangsterId += gangsterIds.length;

            allIds = allIds.union(gangsterIds);
            allGangs = allGangs.union(players[i].gang.repeat(gangsterIds.length));
        }

        gmc.setGang(allIds, allGangs);
    }

    function tryLoadEnvAddress(string memory key) internal returns (address user) {
        try vm.envAddress(key) returns (address user_) {
            user = user_;
        } catch {}
    }
}

struct Player {
    address wallet;
    uint256 gang;
}

bytes constant playerData = abi.encode(
    Player({wallet: address(0x13370aabbccdd), gang: 1}),
    Player({wallet: address(0x13371aabbccdd), gang: 1}),
    Player({wallet: address(0x13372aabbccdd), gang: 2}),
    Player({wallet: address(0x13373aabbccdd), gang: 2}),
    Player({wallet: address(0x13374aabbccdd), gang: 0}),
    Player({wallet: address(0x13375aabbccdd), gang: 0}),
    Player({wallet: address(0x13376aabbccdd), gang: 0}),
    Player({wallet: address(0x13377aabbccdd), gang: 2}),
    Player({wallet: address(0x13378aabbccdd), gang: 2}),
    Player({wallet: address(0x13379aabbccdd), gang: 1})
);

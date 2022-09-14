// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {SetupChild} from "../src/SetupChild.sol";

import "forge-std/Script.sol";

/* 

# Polygon Mainnet 
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY -vvvv --ffi 
source .env && forge script mint --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 38gwei -vvvv --ffi --slow --broadcast 

# Anvil
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script mint --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Mumbai
source .env && US_DRY_RUN=true forge script mint --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script mint --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 38gwei -vvvv --ffi --broadcast 

*/

import "futils/futils.sol";

contract mint is SetupChild {
    using futils for *;

    // function setUpUpgradeScripts() internal override {
    //     UPGRADE_SCRIPTS_ATTACH_ONLY = true;
    // }

    function run() external {
        startBroadcastIfNotDryRun();

        setUpContracts();

        if (isTestnet()) initContractsTestnet();

        vm.stopBroadcast();

        storeDeployments();

        // uint256[3] memory shares = vault.getUserShares(msg.sender);
        // console.log("shares0", shares[0]);
        // console.log("shares1", shares[1]);
        // console.log("shares2", shares[2]);
        // // uint256[] memory ownedIds = gmc.getOwnedIds(msg.sender);
        // // for (uint256 i; i < ownedIds.length; i++) console.log(ownedIds[i]);
        // // for (uint256 i; i < 3; i++) {
        // //     vm.prank(address(0));
        // //     uint256[3] memory balances = game.getGangVaultBalance(i);
        // //     console.log(balances[0]);
        // //     console.log(balances[1]);
        // //     console.log(balances[2]);
        // // }
    }

    function initContractsTestnet() internal {
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

        uint256 baronId = 1;
        uint256 gangsterId = 1;

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

        // address[] memory players = abi
        //     .encode(
        //         [
        //             address(0x13370),
        //             address(0x13371),
        //             address(0x13372),
        //             address(0x13373),
        //             address(0x13374),
        //             address(0x13375),
        //             address(0x13376),
        //             address(0x13377),
        //             address(0x13378),
        //             address(0x13379)
        //         ]
        //     )
        //     ._toAddressArray();

        // for (uint256 i; i < players.length; i++) {
        //     address user = players[i];
        //     if (user == address(0)) continue;

        //     uint256[] memory gangsterIds = gangsterId.range(gangsterId += 10);

        //     gmc.resyncIds(user, gangsterIds);
        // }

        if (game.getBaronItemBalances(0)[4] < 10) game.addBaronItem(0, 4, 10);
        if (game.getBaronItemBalances(1)[4] < 10) game.addBaronItem(1, 4, 10);
        if (game.getBaronItemBalances(2)[4] < 10) game.addBaronItem(2, 4, 10);

        if (game.getBaronItemBalances(0)[0] < 10) game.addBaronItem(0, 0, 10);
        if (game.getBaronItemBalances(1)[0] < 10) game.addBaronItem(1, 0, 10);
        if (game.getBaronItemBalances(2)[0] < 10) game.addBaronItem(2, 0, 10);

        game.reset(occupants, yields);
        // vault.reset();

        // if (firstTimeDeployed[block.chainid][address(game)]) {
        // vault.grantRole(GANG_VAULT_CONTROLLER, msg.sender);

        // vault.setYield(0, [uint256(7700000), 7700000, 7700000]);
        // vault.setYield(1, [uint256(7700000), 7700000, 7700000]);
        // vault.setYield(2, [uint256(7700000), 7700000, 7700000]);
        // }
    }

    function tryLoadEnvAddress(string memory key) internal returns (address user) {
        try vm.envAddress(key) returns (address user_) {
            user = user_;
        } catch {}
    }
}

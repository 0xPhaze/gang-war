// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {SetupChild} from "../src/SetupChild.sol";

// import "chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";
// function addConsumer(uint64 subId, address consumer) external override onlySubOwner(subId) nonReentrant {

/* 
# 2: Simulate
forge script attach --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --with-gas-price 38gwei -vvvv

3 #: Run
forge script attach --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --with-gas-price 38gwei -vvvv --broadcast 
*/

import "futils/futils.sol";
import "forge-std/Script.sol";

contract attach is Script {
    // function setUpUpgradeScripts() internal override {
    //     UPGRADE_SCRIPTS_ATTACH_ONLY = true;
    // }

    using futils for *;

    function run() external {
        // vm.getCode("MockVRFCoordinator.sol");
        // setUpContractsTestnet();
        // vm.startBroadcast();
        // // vm.startPrank(msg.sender);
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
}

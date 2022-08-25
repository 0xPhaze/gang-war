// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {GangWarSetup} from "./GangWarSetup.sol";

// import "chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";
// function addConsumer(uint64 subId, address consumer) external override onlySubOwner(subId) nonReentrant {

/* 
# 2: Simulate
forge script attach --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --with-gas-price 38gwei -vvvv

3 #: Run
forge script attach --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --with-gas-price 38gwei -vvvv --broadcast 
*/

contract attach is GangWarSetup {
    function __upgrade_scripts_init() internal override {
        __UPGRADE_SCRIPTS_ATTACH = true;
        super.__upgrade_scripts_init();
    }

    function run() external {
        setUpContractsTestnet();

        vm.startBroadcast();
        // vm.startPrank(msg.sender);

        uint256[] memory ownedIds = gmc.getOwnedIds(msg.sender);
        for (uint256 i; i < ownedIds.length; i++) console.log(ownedIds[i]);

        // for (uint256 i; i < 3; i++) {
        //     vm.prank(address(0));
        //     uint256[3] memory balances = game.getGangVaultBalance(i);
        //     console.log(balances[0]);
        //     console.log(balances[1]);
        //     console.log(balances[2]);
        // }
    }
}

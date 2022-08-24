// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {GangWarSetup} from "./GangWarSetup.sol";

// import "chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";
// function addConsumer(uint64 subId, address consumer) external override onlySubOwner(subId) nonReentrant {

/* 
# 2: Simulate
forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --with-gas-price 38gwei -vvvv

3 #: Deploy
source .env && forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 38gwei -vvvv --ffi --broadcast 
*/

contract deploy is GangWarSetup {
    function startBroadcastIfFFIEnabled() internal {
        if (isFFIEnabled()) {
            vm.startBroadcast();
        } else {
            console.log('FFI disabled: run again with `--ffi` to save deployments and run storage compatibility checks.'); // prettier-ignore
            console.log('Disabling `broadcast`, continuing as a "dry-run".\n');

            // need to start prank instead now to be consistent in "dry-run"
            vm.stopBroadcast();
            vm.startPrank(msg.sender);
        }
    }

    function run() external {
        vm.startBroadcast();

        if (isTestnet()) {
            setUpContractsTestnet();
            initContractsCITestnet();
        } else {
            setUpContracts();
            initContractsCI();
        }

        vm.stopBroadcast();

        logRegisteredContracts();
    }
}

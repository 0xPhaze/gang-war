// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {GangWarSetup} from "./GangWarSetup.sol";

// import "chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";

// function addConsumer(uint64 subId, address consumer) external override onlySubOwner(subId) nonReentrant {

// interface IVRFCoordinator

/* 
source .env && forge script deploy --rpc-url $RINKEBY_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv

source .env && forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --ffi --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 38gwei -vvvv

cp ~/git/eth/GangWar/out/MockGMC.sol/MockGMC.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockERC20.sol/MockERC20.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockVRFCoordinator.sol/MockVRFCoordinator.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/GangWar.sol/GangWar.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/Mice.sol/Mice.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/deployments/80001/deploy-latest.json ~/git/eth/gmc-website/data/deployments_80001.json
*/

contract deploy is GangWarSetup {
    // using futils for *;

    // function setUpEnv() internal {
    //     string memory profile = tryLoadEnvString("FOUNDRY_PROFILE");

    //     if (eq(profile, "")) {
    //         vm.warp(1660993892);
    //         vm.roll(27702338);
    //     } else if (eq(profile, "mumbai")) {
    //         vm.selectFork(vm.createFork("mumbai"));
    //     }
    // }

    function run() external {
        vm.startBroadcast();

        setUpContracts();

        if (isTestnet()) initContractsCITEST();
        else initContractsCI();

        vm.stopBroadcast();

        logRegisteredContracts();
    }

    function validateSetup() external {}
}

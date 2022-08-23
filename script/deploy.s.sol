// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {GangWarSetup} from "./GangWarSetup.sol";

// import "chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";
// function addConsumer(uint64 subId, address consumer) external override onlySubOwner(subId) nonReentrant {

/* 
source .env && forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 38gwei -vvvv --ffi --broadcast 

cp ~/git/eth/GangWar/out/MockGMC.sol/MockGMC.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockERC20.sol/MockERC20.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockVRFCoordinator.sol/MockVRFCoordinator.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/GangWar.sol/GangWar.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/Mice.sol/Mice.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/deployments/80001/deploy-latest.json ~/git/eth/gmc-website/data/deployments_80001.json
*/

contract deploy is GangWarSetup {
    function isFFIEnabled() internal returns (bool) {
        string[] memory script = new string[](1);
        script[0] = "echo";
        try vm.ffi(script) {
            return true;
        } catch {
            return false;
        }
    }

    function startBroadcastIfFFIEnabled() internal {
        if (isFFIEnabled()) {
            vm.startBroadcast();
        } else {
            console.log('FFI disabled: run again with `--ffi` to save deployments and run storage compatibility checks.'); // prettier-ignore
            console.log('Disabling `broadcast`, continuing as a "dry-run".\n');

            __DEPLOY_SCRIPTS_DRY_RUN = true;

            // need to start prank instead now to be consistent in "dry-run"
            vm.stopBroadcast();
            vm.startPrank(msg.sender);
        }
    }

    function run() external {
        startBroadcastIfFFIEnabled();

        setUpContracts();

        if (isTestnet()) initContractsCITEST();
        else initContractsCI();

        vm.stopBroadcast();

        logRegisteredContracts();

        if (!__DEPLOY_SCRIPTS_DRY_RUN) {
            string memory json = getRegisteredContractsJson();

            vm.writeFile(getDeploymentsPath(string.concat("deploy-latest.json")), json);
            vm.writeFile(getDeploymentsPath(string.concat("deploy-", vm.toString(block.timestamp), ".json")), json);
        }
    }
}

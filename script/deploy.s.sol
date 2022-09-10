// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {SetupChild} from "../src/SetupChild.sol";

// import "chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";
// function addConsumer(uint64 subId, address consumer) external override onlySubOwner(subId) nonReentrant {

/* 
# 1: Run Tests
forge test -vvv

# ANVIL
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script deploy --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# 2: Simulate
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --with-gas-price 38gwei -vvvv --ffi

3 #: Deploy
source .env && forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 38gwei -vvvv --ffi --broadcast 

cp ~/git/eth/GangWar/out/MockGMCChild.sol/MockGMCChild.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockERC20.sol/MockERC20.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockVRFCoordinator.sol/MockVRFCoordinator.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/GangWar.sol/GangWar.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/GangVault.sol/GangVault.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/Mice.sol/Mice.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/deployments/80001/deploy-latest.json ~/git/eth/gmc-website/data/deployments_80001.json
*/

contract deploy is SetupChild {
    function run() external {
        startBroadcastIfNotDryRun();

        setUpContracts();
        initContracts();

        if (isTestnet()) initContractsTestnet();

        vm.stopBroadcast();

        logDeployments();
        storeLatestDeployments();
    }

    function initContractsTestnet() internal {
        address lumy = 0x2181838c46bEf020b8Beb756340ad385f5BD82a8;
        address antoine = 0x4f41aFa6DcF74BD757549CD379CB042C63e66385;

        // grant mint authority
        if (!tokens[0].hasRole(AUTHORITY, msg.sender)) tokens[0].grantRole(AUTHORITY, msg.sender);
        if (!tokens[1].hasRole(AUTHORITY, msg.sender)) tokens[1].grantRole(AUTHORITY, msg.sender);
        if (!tokens[2].hasRole(AUTHORITY, msg.sender)) tokens[2].grantRole(AUTHORITY, msg.sender);
        if (!badges.hasRole(AUTHORITY, msg.sender)) badges.grantRole(AUTHORITY, msg.sender);

        if (!tokens[0].hasRole(AUTHORITY, lumy)) tokens[0].grantRole(AUTHORITY, lumy);
        if (!tokens[1].hasRole(AUTHORITY, lumy)) tokens[1].grantRole(AUTHORITY, lumy);
        if (!tokens[2].hasRole(AUTHORITY, lumy)) tokens[2].grantRole(AUTHORITY, lumy);
        if (!badges.hasRole(AUTHORITY, lumy)) badges.grantRole(AUTHORITY, lumy);

        // mint tokens for testing
        if (firstTimeDeployed[block.chainid][address(game)]) {
            tokens[0].mint(msg.sender, 100_000e18);
            tokens[1].mint(msg.sender, 100_000e18);
            tokens[2].mint(msg.sender, 100_000e18);
            badges.mint(msg.sender, 100_000e18);

            tokens[0].mint(lumy, 100_000e18);
            tokens[1].mint(lumy, 100_000e18);
            tokens[2].mint(lumy, 100_000e18);
            badges.mint(lumy, 100_000e18);

            tokens[0].mint(antoine, 100_000e18);
            tokens[1].mint(antoine, 100_000e18);
            tokens[2].mint(antoine, 100_000e18);
            badges.mint(antoine, 100_000e18);

            gmc.mintBatch(msg.sender);
            gmc.mintBatch(antoine);
            gmc.mintBatch(lumy);

            vault.grantRole(GANG_VAULT_CONTROLLER, msg.sender);

            vault.setYield(0, [uint256(7700000), 7700000, 7700000]);
            vault.setYield(1, [uint256(7700000), 7700000, 7700000]);
            vault.setYield(2, [uint256(7700000), 7700000, 7700000]);
        }
    }
}

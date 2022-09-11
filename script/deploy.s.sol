// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {SetupChild} from "../src/SetupChild.sol";

import "futils/futils.sol";

/* 
# 1: Run Tests
forge test -vvv

# ANVIL
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script deploy --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# 2: Simulate
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --with-gas-price 38gwei -vvvv --ffi

# 3: Deploy
source .env && forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY --with-gas-price 38gwei -vvvv --ffi --broadcast 

source .env && forge script deploy --rpc-url $RPC_RINKEBY --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv --ffi --broadcast 

cp ~/git/eth/GangWar/out/GMCChild.sol/GMCChild.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockERC20.sol/MockERC20.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/MockVRFCoordinator.sol/MockVRFCoordinator.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/GangWar.sol/GangWar.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/GangVault.sol/GangVault.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/out/Mice.sol/Mice.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/GangWar/deployments/80001/deploy-latest.json ~/git/eth/gmc-website/data/deployments_80001.json
*/

contract deploy is SetupChild {
    using futils for *;

    // function setUpUpgradeScripts() internal override {
    //     UPGRADE_SCRIPTS_BYPASS_SAFETY = true;
    // }

    function run() external {
        startBroadcastIfNotDryRun();

        isUpgradeSafe[80001][0x4155935E9E4751c772598E32e108Dc97c0679b38][
            0xc6aC70bEE1437d21d735f4011542cBcED8D977D5
        ] = true;
        isUpgradeSafe[80001][0x7D20643C0b9d091998d49d5224dc968b41f489B4][
            0x9c796eddC535F4D5f4E42c1eA24C04B38dCfac63
        ] = true;

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

            gmc.resyncIds(lumy, 21.range(31).union(10_0015.range(10_022)));
            gmc.resyncIds(antoine, 11.range(21).union(10_008.range(10_015)));
            gmc.resyncIds(msg.sender, 1.range(11).union(10_001.range(10_008)));

            vault.grantRole(GANG_VAULT_CONTROLLER, msg.sender);

            vault.setYield(0, [uint256(7700000), 7700000, 7700000]);
            vault.setYield(1, [uint256(7700000), 7700000, 7700000]);
            vault.setYield(2, [uint256(7700000), 7700000, 7700000]);
        }
    }
}

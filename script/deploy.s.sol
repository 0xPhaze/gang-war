// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {SetupChild} from "../src/SetupChild.sol";

import "/GangWar.sol";

import "forge-std/Script.sol";
import "futils/futils.sol";
import "solmate/test/utils/mocks/MockERC721.sol";

/* 

# Polygon Mainnet 
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY_GMC -vvvv --ffi 
source .env && forge script deploy --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY_GMC --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --slow --broadcast 

# Anvil
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script deploy --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Mumbai
source .env && US_DRY_RUN=true forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script deploy --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --broadcast 

cp ~/git/eth/gang-war/out/GMCChild.sol/GMCChild.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/GMCRoot.sol/GMC.json ~/git/eth/gmc-website/data/abi/GMCRoot.json
cp ~/git/eth/gang-war/out/GoudaChild.sol/GoudaChild.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/MockERC20.sol/MockERC20.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/MockVRFCoordinator.sol/MockVRFCoordinator.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/GangWar.sol/GangWar.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/GangVault.sol/GangVault.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/GangVaultRewards.sol/GangVaultRewards.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/Mice.sol/Mice.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/SafeHouses.sol/SafeHouses.json ~/git/eth/gmc-website/data/abi

cp ~/git/eth/gang-war/out/GMCRoot.sol/GMC.json ~/git/eth/gmc-website/data/abi/GMCRoot.json
cp ~/git/eth/gang-war/out/MockERC20.sol/MockERC20.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/GoudaRootRelay.sol/GoudaRootRelay.json ~/git/eth/gmc-website/data/abi
cp ~/git/eth/gang-war/out/SafeHouseClaim.sol/SafeHouseClaim.json ~/git/eth/gmc-website/data/abi

cp ~/git/eth/gang-war/deployments/80001/deploy-latest.json ~/git/eth/gmc-website/data/deployments_80001.json
cp ~/git/eth/gang-war/deployments/137/deploy-latest.json ~/git/eth/gmc-website/data/deployments_137.json
cp ~/git/eth/gang-war/deployments/5/deploy-latest.json ~/git/eth/gmc-website/data/deployments_5.json
cp ~/git/eth/gang-war/deployments/1/deploy-latest.json ~/git/eth/gmc-website/data/deployments_1.json

__*/

contract deploy is SetupChild {
    using futils for *;

    constructor() {
        // MOCK_TUNNEL_TESTING = block.chainid == CHAINID_MUMBAI;

        mainnetConfirmation = 1668635623;
        // mainnetConfirmation = block.timestamp;
    }

    function run() external {
        startBroadcastIfNotDryRun();

        setUpContracts();

        vault.resetGangVaultBalances();

        // vault.resetGangVaultBalances();

        // gangVaultRewards.addReward(1, 4_000e18);

        // game.reset(occupants, yields);

        // // new Date('November 23, 2022 4:00 PM').getTime() / 1000
        // // new Date('December 23, 2022 4:00 PM').getTime() / 1000

        // game.setSeason(1669215600, 1671807600);

        gmc.resyncBarons(
            abi.encode(
                [
                    0xe2c32116AB0D54C80092D5150c97555AD37E0d63,
                    0x805a3B79917055A18aBc171E14e4c7e36119D9B6,
                    0x4b8ee1eEf0bD930c2277a60c839834B142B373d2,
                    0xcea2c2b93CB242f64C8C3CF36e659cb0EC7d937e,
                    0x409e5f34Ae011e9Df40E360eE37387fA8b0980CB,
                    0x7Ce5039A2383ba2CDf57DF1a8Bd353E021c37492,
                    0x49f2b78458B553229c51a389C811C4A73ae84C73,
                    0x78f8C78a212d64CE1148355DEE3F26a6e029EbBa,
                    0x983c09D36d78A8FB433a88499A95c73524954Af6,
                    0x158e61A181959844D6Ac426a2A50eec065B3a943,
                    0xd2bEC77b8BEcdDA350DDaA4Be3b0D91C119b6851,
                    0x2d254aB8625f9738200E3D1e359e6b1Bf6e0E912,
                    0x6C7AC914D586F7089e5a68375E0df549317c3eE8,
                    0xB7fc617Da6546febfC31dfc8283B8588E192B3ec,
                    0x6d711bE0693B5ff41678bA3f4507c0BF1Ae1ff17,
                    0xD29588f9867CB0bD9D61A2c099A79B4926940351,
                    0x5143B2F5e573Be79aA5D96Ae1367bFC6F095C4d9,
                    0xDe23301fEd4034651bCF6612A5f89D9ADC5b8a2b,
                    0x205C4d9d198a2e9D74eee70151d1Ba02f3C70Daa,
                    0x02C1422931439B3e945e2F2F721c80F6c0feaF56,
                    0x205FfDa46164C3e6ae60AF559c82F26f9470072E
                ]
            )._toAddressArray()
        );

        // safeHouses.setBaseURI("ipfs://QmRJUciN3rdfUK9TjnsNNB5nbSCy3oRmmh2yaJC9k4QP76/");
        // safeHouses.setPostFixURI(".json");

        // badges.grantRole(AUTHORITY, msg.sender);
        // badges.grantRole(AUTHORITY, 0x2181838c46bEf020b8Beb756340ad385f5BD82a8);
        // badges.mint(0x2181838c46bEf020b8Beb756340ad385f5BD82a8, 50000000e18);
        // mice.grantRole(AUTHORITY, msg.sender);
        // mice.grantRole(AUTHORITY, 0x2181838c46bEf020b8Beb756340ad385f5BD82a8);
        // mice.mint(0x2181838c46bEf020b8Beb756340ad385f5BD82a8, 50000000e18);

        if (isTestnet()) {
            // gmc.resyncBarons(
            //     [
            //         0x0000000000000000000000000000000000000000,
            //         0x0000000000000000000000000000000000000000,
            //         0x0000000000000000000000000000000000000000,
            //         0x0000000000000000000000000000000000000000,
            //         0x0000000000000000000000000000000000000000,
            //         0x0000000000000000000000000000000000000000
            //     ].toMemory()
            // );
            gmc.resyncBarons(
                [
                    msg.sender,
                    msg.sender,
                    msg.sender,
                    0x2181838c46bEf020b8Beb756340ad385f5BD82a8,
                    0x2181838c46bEf020b8Beb756340ad385f5BD82a8,
                    0x2181838c46bEf020b8Beb756340ad385f5BD82a8
                ].toMemory()
            );
        }

        if (isTestnet() && isFirstTimeDeployed(address(game))) {
            // troupe.airdrop([msg.sender, 0x2181838c46bEf020b8Beb756340ad385f5BD82a8].toMemory(), 10);
            // genesis.airdrop([msg.sender, 0x2181838c46bEf020b8Beb756340ad385f5BD82a8].toMemory(), 10);

            game.reset(occupants, yields);
            game.setBaronItemBalances(0.range(NUM_BARON_ITEMS), 3.repeat(NUM_BARON_ITEMS));
            game.setSeason(1665421200, 1668099600);
            gmc.resyncIds(msg.sender, 1.range(21));
            gmc.resyncIds(0x2181838c46bEf020b8Beb756340ad385f5BD82a8, 21.range(41));
            gmc.resyncBarons(
                [
                    msg.sender,
                    msg.sender,
                    msg.sender,
                    0x2181838c46bEf020b8Beb756340ad385f5BD82a8,
                    0x2181838c46bEf020b8Beb756340ad385f5BD82a8,
                    0x2181838c46bEf020b8Beb756340ad385f5BD82a8
                ].toMemory()
            );
            bytes32 CONTROLLER = keccak256("GANG.VAULT.CONTROLLER");
            vault.grantRole(CONTROLLER, msg.sender);
            vault.setYield(0, [uint256(7_700_000), 7_700_000, 7_700_000]);
            vault.setYield(1, [uint256(7_700_000), 7_700_000, 7_700_000]);
            vault.setYield(2, [uint256(7_700_000), 7_700_000, 7_700_000]);
        }

        // goudaRoot.mint(msg.sender, 100e18);
        // goudaRoot.approve(address(goudaTunnel), type(uint256).max);
        // goudaTunnel.lock(msg.sender, 50e18);

        // vm.stopBroadcast();

        storeDeployments();
    }
}

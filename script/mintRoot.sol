// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {SetupRoot} from "../src/SetupRoot.sol";

import "forge-std/Script.sol";
import "futils/futils.sol";

/* 
# Mainnet
source .env && US_DRY_RUN=true forge script mintRoot --rpc-url $RPC_MAINNET --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script mintRoot --rpc-url $RPC_MAINNET --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv --ffi --broadcast 

# Anvil
source .env && US_DRY_RUN=true forge script mintRoot --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script mintRoot --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Goerli
source .env && US_DRY_RUN=true forge script mintRoot --rpc-url $RPC_GOERLI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script mintRoot --rpc-url $RPC_GOERLI --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv --ffi --broadcast */

// import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";

// contract Airdrop {
//     function transfer(address collection, uint256[] calldata data) external payable {
//         unchecked {
//             for (uint256 i; i < data.length; ++i) {
//                 ERC721UDS(collection).transferFrom(msg.sender, address(uint160(data[i])), data[i] >> 160);
//             }
//         }
//     }
// }

contract mintRoot is SetupRoot {
    using futils for *;

    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_ATTACH_ONLY = true;
    }

    function run() external {
        startBroadcastIfNotDryRun();

        setUpContracts();

        // gmc.airdrop([msg.sender].toMemory(), 554, false);
        // gmc.setSigner(msg.sender);

        // Airdrop airdrop = new Airdrop();
        // Airdrop airdrop = Airdrop(0x74239E4b25B692FeFFeAEbECfB776eA49625d111);

        // gmc.setApprovalForAll(address(airdrop), true);

        // airdrop.transfer(
        //     address(gmcRoot),
        //     abi
        //         .encode(
        //             [
        //                 uint256((0x009Bd4b05B6F3cD3778012f72C16c42Fd0490CfB3e)) | (uint256(495) << 160),
        //                 uint256((0x009Bd4b05B6F3cD3778012f72C16c42Fd0490CfB3e)) | (uint256(496) << 160),
        //                 uint256((0x009Bd4b05B6F3cD3778012f72C16c42Fd0490CfB3e)) | (uint256(497) << 160),
        //                 uint256((0x009Bd4b05B6F3cD3778012f72C16c42Fd0490CfB3e)) | (uint256(498) << 160),
        //                 uint256((0x009Bd4b05B6F3cD3778012f72C16c42Fd0490CfB3e)) | (uint256(499) << 160),
        //                 uint256((0x00eba0b9844f174258cc81b4b4ffa9fba80a9b4138)) | (uint256(500) << 160),
        //                 uint256((0x00eba0b9844f174258cc81b4b4ffa9fba80a9b4138)) | (uint256(501) << 160),
        //                 uint256((0x0089b554d6fe86b1f0d65ad3f44f5ae07a6f1a0c32)) | (uint256(502) << 160),
        //                 uint256((0x0013b67186e86bc031ed4b5c83c013b3051ec38a52)) | (uint256(503) << 160),
        //                 uint256((0x0013b67186e86bc031ed4b5c83c013b3051ec38a52)) | (uint256(504) << 160)
        //             ]
        //         )
        //         ._toUint256Array()
        // );

        // gmc.unlockAndTransmit(msg.sender, 1.range(10));
        // gmc.lockAndTransmit(msg.sender, 30.range(40));
        // gmc.lockAndTransmit(msg.sender, 50.range(80));

        // gmc.airdrop([msg.sender].toMemory(), 50, true);
        // gmc.airdrop([msg.sender].toMemory(), 100, true);
        // gmc.airdrop([msg.sender].toMemory(), 10, true);

        vm.stopBroadcast();

        storeDeployments();
    }
}

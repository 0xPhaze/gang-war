// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC1967Proxy} from "UDS/proxy/ERC1967Proxy.sol";
import {SetupChild} from "../src/SetupChild.sol";

import "/GangWar.sol";
import "forge-std/Script.sol";

import "UDS/lib/LibEnumerableSet.sol";

/* 

# Polygon Mainnet 
--block-number 35973258
source .env && US_DRY_RUN=true forge script airdrop --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY_GMC -vvvv --ffi 
source .env && forge script airdrop --rpc-url $RPC_POLYGON --private-key $PRIVATE_KEY_GMC --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --slow --broadcast

# Anvil
source .env && US_DRY_RUN=true forge script airdrop --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi
source .env && forge script airdrop --rpc-url $RPC_ANVIL --private-key $PRIVATE_KEY_ANVIL -vvvv --ffi --broadcast 

# Mumbai
source .env && US_DRY_RUN=true forge script airdrop --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY -vvvv --ffi
source .env && forge script airdrop --rpc-url $RPC_MUMBAI --private-key $PRIVATE_KEY --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv --ffi --broadcast 

#*/

import "futils/futils.sol";

// contract snapshot is SetupChild {
//     using futils for *;
//     using LibEnumerableSet for LibEnumerableSet.AddressSet;

//     function setUpUpgradeScripts() internal override {
//         UPGRADE_SCRIPTS_ATTACH_ONLY = true;
//         MOCK_TUNNEL_TESTING = block.chainid == CHAINID_MUMBAI;
//     }

//     mapping(uint256 => address) owners;
//     LibEnumerableSet.AddressSet ownerSet;

//     function run() external {
//         startBroadcastIfNotDryRun();

//         setUpContracts();

//         for (uint256 i; i < 6666; i++) {
//             uint256 id = i + 1;
//             address owner = gmc.ownerOf(id);

//             owners[id] = owner;
//             ownerSet.add(owner);
//         }

//         for (uint256 i; i < ownerSet.length(); i++) {
//             address owner = ownerSet.at(i);
//             uint256[3] memory unclaimed = vault.getClaimableUserBalance(owner);

//             if (unclaimed[0] + unclaimed[1] + unclaimed[2] == 0) continue;

//             console.log(owner, unclaimed[0], unclaimed[1], unclaimed[2]);
//         }
//     }
// }

struct AirdropInfo {
    address recipient;
    string token0;
    string token1;
    string token2;
}

contract TokenAirdrop {
    constructor(address collection, uint256[] memory data) payable {
        unchecked {
            for (uint256 i; i < data.length; ++i) {
                ERC721UDS(collection).transferFrom(msg.sender, address(uint160(data[i])), data[i] >> 160);
            }
        }
    }
}

contract airdrop is SetupChild {
    using futils for *;

    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_ATTACH_ONLY = true;
    }

    address[] recipients;
    uint256[] tokenAmounts0;
    uint256[] tokenAmounts1;
    uint256[] tokenAmounts2;

    function run() external {
        startBroadcastIfNotDryRun();

        setUpContracts();

        string memory json = vm.readFile("./script/airdrop.json");
        bytes memory data = vm.parseJson(json);

        AirdropInfo[] memory info = abi.decode(data, (AirdropInfo[]));

        for (uint256 i; i < info.length; i++) {
            recipients.push(info[i].recipient);

            tokenAmounts0.push(vm.parseUint(info[i].token0));
            tokenAmounts1.push(vm.parseUint(info[i].token1));
            tokenAmounts2.push(vm.parseUint(info[i].token2));
        }

        tokens[0].airdrop(recipients, tokenAmounts0);
        tokens[1].airdrop(recipients, tokenAmounts1);
        tokens[2].airdrop(recipients, tokenAmounts2);
    }
}

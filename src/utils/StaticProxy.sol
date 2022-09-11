// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {OwnableUDS, s as ownableDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {ERC1967_PROXY_STORAGE_SLOT} from "UDS/proxy/ERC1967Proxy.sol";

bytes32 constant DIAMOND_STORAGE_STATIC_PROXY = keccak256("diamond.storage.static.proxy");

struct StaticProxyDS {
    address staticImplementation;
}

function s() pure returns (StaticProxyDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_STATIC_PROXY;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

error NotAuthorized();

/// @title Static Proxy
/// @author phaze (https://github.com/0xPhaze)
/// @notice Allows for continued staticcalls to implementation
///         contract. Disables all non-static calls.
contract StaticProxy is UUPSUpgrade, OwnableUDS {
    function init(address implementation) public reinitializer {
        if (owner() == address(0)) {
            ownableDS().owner = msg.sender;
        }

        s().staticImplementation = implementation;
    }

    fallback() external {
        if (msg.sender != address(this)) {
            // open static-call context and continue with 'else' control-flow
            assembly {
                calldatacopy(0, 0, calldatasize())

                let success := staticcall(gas(), address(), 0, calldatasize(), 0, 0)

                returndatacopy(0, 0, returndatasize())

                if success {
                    return(0, returndatasize())
                }

                revert(0, returndatasize())
            }
        } else {
            // must be in static-call context now
            address implementation = s().staticImplementation;

            assembly {
                calldatacopy(0, 0, calldatasize())

                let success := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

                returndatacopy(0, 0, returndatasize())

                if success {
                    return(0, returndatasize())
                }

                revert(0, returndatasize())
            }
        }
    }

    function _authorizeUpgrade() internal override onlyOwner {}
}

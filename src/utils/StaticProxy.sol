// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {OwnableUDS, s as ownableDS} from "UDS/auth/OwnableUDS.sol";
import {ERC1967_PROXY_STORAGE_SLOT} from "UDS/proxy/ERC1967Proxy.sol";

// ------------- storage

bytes32 constant DIAMOND_STORAGE_STATIC_PROXY = keccak256("diamond.storage.static.proxy");

struct StaticProxyDS {
    address staticImplementation;
}

function s() pure returns (StaticProxyDS storage diamondStorage) {
    bytes32 slot = DIAMOND_STORAGE_STATIC_PROXY;
    assembly { diamondStorage.slot := slot } // prettier-ignore
}

// ------------- errors

error NotAuthorized();
error StaticImplementationNotSet();

/// @title Static Proxy
/// @author phaze (https://github.com/0xPhaze)
/// @notice Allows for continued staticcalls to implementation
///         contract. Disables all non-static calls.
contract StaticProxy is UUPSUpgrade, OwnableUDS {
    bool public constant isStaticProxy = true;

    /* ------------- init ------------- */

    function init(address implementation) public reinitializer {
        if (owner() == address(0)) {
            ownableDS().owner = msg.sender;
        }

        if (implementation != address(0)) s().staticImplementation = implementation;
        if (s().staticImplementation == address(0)) revert StaticImplementationNotSet();
    }

    /* ------------- external ------------- */

    // function upgradeToAndCall(address logic, bytes calldata data) external override {
    //     _authorizeUpgrade();
    //     _upgradeToAndCall(logic, data);
    // }

    function upgradeStaticImplementation(address logic) external {
        _authorizeUpgrade();
        s().staticImplementation = logic;
    }

    /* ------------- upkeep ------------- */

    /// @dev pause all upkeeps
    function checkUpkeep(bytes calldata) external view returns (bool upkeepNeeded, bytes memory data) {}

    /* ------------- fallback ------------- */

    fallback() external {
        if (msg.sender != address(this) && tx.origin != owner()) {
            // open static-call context, loop back in
            // and continue with 'else' control-flow
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
            // and we can safely perform delegatecalls

            address target = s().staticImplementation;

            assembly {
                calldatacopy(0, 0, calldatasize())

                let success := delegatecall(gas(), target, 0, calldatasize(), 0, 0)

                returndatacopy(0, 0, returndatasize())

                if success {
                    return(0, returndatasize())
                }

                revert(0, returndatasize())
            }
        }
    }

    /* ------------- override ------------- */

    function _authorizeUpgrade() internal override onlyOwner {}
}

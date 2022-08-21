// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {AccessControlUDS} from "UDS/auth/AccessControlUDS.sol";
import {FxERC20RootTunnelUDS} from "fx-contracts/FxERC20RootTunnelUDS.sol";

contract GoudaRootTunnel is UUPSUpgrade, OwnableUDS, FxERC20RootTunnelUDS {
    constructor(
        address gouda,
        address checkpointManager,
        address fxRoot
    ) FxERC20RootTunnelUDS(gouda, checkpointManager, fxRoot) {}

    function init() public initializer {
        __Ownable_init();
    }

    /* ------------- owner ------------- */

    function _authorizeUpgrade() internal override onlyOwner {}

    function _authorizeTunnelController() internal override onlyOwner {}
}

// deploy:
// call init, call setFxChildTunnel

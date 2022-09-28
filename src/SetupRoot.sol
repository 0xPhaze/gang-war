// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {GMC as GMCRoot} from "/tokens/GMCRoot.sol";
import {GoudaRootRelay} from "/tokens/GoudaRootRelay.sol";
import {StaticProxy} from "/utils/StaticProxy.sol";

import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import "./SetupBase.sol";

contract SetupRoot is SetupBase {
    GMCRoot gmc;
    MockERC20 gouda;
    GoudaRootRelay goudaTunnel;
    StaticProxy staticProxy;

    function setUpContracts() internal {
        setUpFxPortal();
        setUpChainlink();

        staticProxy = StaticProxy(setUpContract("StaticProxy")); // placeholder to disable UUPS contracts

        if (isTestnet()) {
            bytes memory goudaArgs = abi.encode("Gouda", "GOUDA", 18);
            gouda = MockERC20(setUpContract("MockERC20", goudaArgs, "GoudaRoot"));
        } else {
            if (fxRootCheckpointManager == address(0) || fxRoot == address(0)) revert("Invalid FxPortal setup.");

            // @note Gouda Mainnet needs MINT.AUTHORITY?
            gouda = MockERC20(GOUDA_ROOT);
        }

        bytes memory goudaTunnelArgs = abi.encode(address(gouda), fxRootCheckpointManager, fxRoot);
        goudaTunnel = GoudaRootRelay(setUpContract("GoudaRootRelay", goudaTunnelArgs));

        bytes memory gmcArgs = abi.encode(fxRootCheckpointManager, fxRoot);
        gmc = GMCRoot(setUpContract("GMCRoot.sol:GMC", gmcArgs, "GMCRoot"));

        linkWithChild(address(gmc), "GMCChild");
        linkWithChild(address(goudaTunnel), "GoudaChild");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {MockGMCRoot} from "../test/mocks/MockGMCRoot.sol";
import {GoudaRootRelay} from "/tokens/GoudaRootRelay.sol";

import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import "./SetupBase.sol";

contract SetupRoot is SetupBase {
    MockERC20 gouda;
    MockGMCRoot gmc;
    GoudaRootRelay goudaTunnel;

    function setUpContractsMainnet() internal {
        if (fxRootCheckpointManager == address(0) || fxRoot == address(0)) revert("Invalid FxPortal setup.");

        gouda = MockERC20(GOUDA_ROOT);

        setUpContracts();
    }

    function setUpContracts() internal {
        if (isTestnet()) {
            bytes memory goudaArgs = abi.encode("Gouda", "GOUDA", 18);
            gouda = MockERC20(setUpContract("MockERC20", goudaArgs, "GoudaRoot"));
        }

        bytes memory goudaTunnelArgs = abi.encode(address(gouda), fxRootCheckpointManager, fxRoot);
        goudaTunnel = GoudaRootRelay(setUpContract("GoudaRootRelay", goudaTunnelArgs));

        bytes memory gmcArgs = abi.encode(fxRootCheckpointManager, fxRoot);
        gmc = MockGMCRoot(setUpContract("MockGMCRoot", gmcArgs, "GMCRoot"));

        linkWithChild(address(gmc), "GMCChild");
        linkWithChild(address(goudaTunnel), "GoudaChild");
    }
}

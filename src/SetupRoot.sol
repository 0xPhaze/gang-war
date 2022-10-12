// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {GMC as GMCRoot} from "/tokens/GMCRoot.sol";
import {GoudaRootRelay} from "/tokens/GoudaRootRelay.sol";
import {StaticProxy} from "/utils/StaticProxy.sol";
import {SafeHouseClaim} from "/tokens/SafeHouseClaim.sol";

import "solmate/test/utils/mocks/MockERC721.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import "./SetupBase.sol";

contract SetupRoot is SetupBase {
    GMCRoot gmc;
    MockERC20 gouda;
    GoudaRootRelay goudaTunnel;
    SafeHouseClaim safeHouseClaim;
    StaticProxy staticProxy;
    address troupe = 0x74d9d90a7fc261FBe92eD47B606b6E0E00d75E70;

    function setUpContracts() internal virtual {
        setUpFxPortal();
        setUpChainlink();

        // staticProxy = StaticProxy(setUpContract("StaticProxy")); // placeholder to disable UUPS contracts

        if (isTestnet()) {
            bytes memory goudaArgs = abi.encode("Gouda", "GOUDA", 18);
            gouda = MockERC20(setUpContract("MockERC20", goudaArgs, "GoudaRoot"));

            troupe = address(setUpContract("MockERC721", abi.encode("Troupe", "TRP"), "Troupe"));
        } else {
            if (fxRootCheckpointManager == address(0) || fxRoot == address(0)) revert("Invalid FxPortal setup.");

            gouda = MockERC20(GOUDA_ROOT);
        }

        bool attachOnly = block.chainid == 1;

        bytes memory goudaTunnelArgs = abi.encode(address(gouda), fxRootCheckpointManager, fxRoot);
        goudaTunnel = GoudaRootRelay(setUpContract("GoudaRootRelay", goudaTunnelArgs));

        bytes memory gmcArgs = abi.encode(fxRootCheckpointManager, fxRoot);
        gmc = GMCRoot(setUpContract("GMCRoot.sol:GMC", gmcArgs, "GMCRoot", attachOnly));

        bytes memory safeHouseClaimArgs = abi.encode(address(troupe), fxRootCheckpointManager, fxRoot);
        address safeHouseClaimImplementation = setUpContract("SafeHouseClaim", safeHouseClaimArgs, "SafeHouseClaimImplementation"); // prettier-ignore
        safeHouseClaim = SafeHouseClaim(setUpProxy(safeHouseClaimImplementation, abi.encodeWithSelector(safeHouseClaim.init.selector), "SafeHouseClaim")); // prettier-ignore

        linkContracts();
    }

    function linkContracts() internal virtual {
        linkWithChild(address(gmc), "GMCChild");
        linkWithChild(address(goudaTunnel), "GoudaChild");
        linkWithChild(address(safeHouseClaim), "SafeHouses");
    }
}

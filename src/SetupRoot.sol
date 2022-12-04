// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {StaticProxy} from "/utils/StaticProxy.sol";

import "./SetupBase.sol";

contract SetupRoot is SetupBase {
    function setUpContracts() internal virtual {
        setUpFxPortal();
        setUpChainlink();

        setUpContractsRoot();
    }

    function setUpContractsRoot() internal virtual {
        // staticProxy = StaticProxy(setUpContract("StaticProxy")); // placeholder to disable UUPS contracts

        if (isTestnet()) {
            bytes memory goudaArgs = abi.encode("Gouda", "GOUDA", 18);
            goudaRoot = MockERC20(setUpContract("MockERC20", goudaArgs, "GoudaRoot"));

            troupe = MockGenesis(address(setUpContract("MockGenesis", abi.encode("Troupe", "TRP"), "Troupe")));
            genesis = MockGenesis(address(setUpContract("MockGenesis", abi.encode("Genesis", "GNS"), "Genesis")));
        } else if (fxRootCheckpointManager == address(0) || fxRoot == address(0)) {
            revert("Invalid FxPortal setup.");
        }

        bool attachOnly = block.chainid == 1;

        bytes memory goudaTunnelArgs = abi.encode(address(goudaRoot), fxRootCheckpointManager, fxRoot);
        goudaTunnel = GoudaRootRelay(setUpContract("GoudaRootRelay", goudaTunnelArgs, "GoudaRootRelay", true));

        bytes memory gmcArgs = abi.encode(fxRootCheckpointManager, fxRoot);
        gmcRoot = GMCRoot(setUpContract("GMCRoot.sol:GMC", gmcArgs, "GMCRoot", attachOnly));

        bytes memory safeHouseClaimArgs = abi.encode(address(genesis), address(troupe), fxRootCheckpointManager, fxRoot);
        safeHouseClaim = SafeHouseClaim(setUpContract("SafeHouseClaim", safeHouseClaimArgs));
        // safeHouseClaim = SafeHouseClaim(setUpProxy(safeHouseClaimImplementation, abi.encodeWithSelector(safeHouseClaim.init.selector), "SafeHouseClaim")); // forgefmt: disable-line

        linkContractsRoot();
    }

    function linkContractsRoot() internal virtual {
        if (MOCK_TUNNEL_TESTING) {
            gmcRoot.setFxChildTunnel(address(gmc));
            goudaTunnel.setFxChildTunnel(address(gouda));
            safeHouseClaim.setFxChildTunnel(address(safeHouses));
        } else {
            linkWithChild(address(gmcRoot), "GMCChild");
            linkWithChild(address(goudaTunnel), "GoudaChild");
            linkWithChild(address(safeHouseClaim), "SafeHouses");
        }
    }
}

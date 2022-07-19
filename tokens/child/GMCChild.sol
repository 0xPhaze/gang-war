// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {FxBaseChildTunnelUDS} from "./lib/FxBaseChildTunnelUDS.sol";
import {FxERC721SyncedChildUDS} from "./lib/FxERC721SyncedChildUDS.sol";

import "solmate/utils/LibString.sol";

error Disabled();

contract GMCChild is UUPSUpgrade(1), FxERC721SyncedChildUDS {
    using LibString for uint256;

    constructor(address fxChild) FxBaseChildTunnelUDS(fxChild) {}

    string private baseURI;

    function init() external initializer {
        __ERC721UDS_init("GMC", "GMC");
        __Ownable_init();
    }

    /* ------------- Public ------------- */

    function tokenURI(uint256 id) public view override returns (string memory) {
        return string.concat(baseURI, id.toString());
    }

    /* ------------- Owner ------------- */

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /* ------------- Internal ------------- */

    function _authorizeUpgrade() internal override onlyOwner {}
}

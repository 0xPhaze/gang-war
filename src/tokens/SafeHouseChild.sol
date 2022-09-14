// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721UDS} from "UDS/tokens/ERC721UDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";

import "solady/utils/LibString.sol";

// ------------- error

contract SafeHouse is UUPSUpgrade, OwnableUDS, ERC721UDS {
    using LibString for uint256;

    string public constant override name = "Safe House";
    string public constant override symbol = "SAFE";

    string private baseURI;

    // constructor() ERC721UDS() {}

    function init() external initializer {
        __Ownable_init();
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return string.concat(baseURI, id.toString());
    }

    /* ------------- owner ------------- */

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function _authorizeUpgrade() internal override onlyOwner {}
}

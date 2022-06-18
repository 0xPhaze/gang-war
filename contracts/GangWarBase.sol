// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {UUPSUpgradeV} from "UDS/proxy/UUPSUpgradeV.sol";
import {OwnableUDS} from "UDS/OwnableUDS.sol";
import {ERC721UDS} from "UDS/ERC721UDS.sol";

import "./GangWarStorage.sol";

/* ============= Error ============= */

error CallerNotOwner();

abstract contract GangWarBase {
    ERC721UDS gmc;

    function __GangWarBase_init(ERC721UDS gmc_) internal {
        gmc = gmc_;
    }

    /* ------------- View ------------- */

    function isBaron(uint256 tokenId) internal pure returns (bool) {
        return tokenId >= 1000;
    }

    function gangOf(uint256 id) public pure returns (GANG) {
        return id == 0 ? GANG.NONE : GANG(((id < 1000 ? id - 1 : id - 1001) % 3) + 1);
    }

    function _validateOwnership(address owner, uint256 tokenId) internal view {
        if (gmc.ownerOf(tokenId) != owner) revert CallerNotOwner();
    }

    function isConnecting(uint256 districtA, uint256 districtB) internal view returns (bool) {
        return
            districtA < districtB
                ? ds().districtConnections[districtA][districtB]
                : ds().districtConnections[districtB][districtA]; // prettier-ignore
    }

    function _afterDistrictTransfer(
        GANG attackers,
        GANG defenders,
        uint256 id
    ) internal virtual;

    /* ------------- Public ------------- */

    /* ------------- Internal ------------- */
}

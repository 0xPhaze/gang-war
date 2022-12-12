// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GMCChild} from "./GMCChild.sol";

/// @title Gang Proxy
/// @author phaze (https://github.com/0xPhaze)
contract GangProxy {
    address immutable gmc;
    uint256 immutable gang;

    constructor(address gmc_, uint256 gang_) {
        gmc = gmc_;
        gang = gang_;
    }

    function balanceOf(address user) public view returns (uint256) {
        return GMCChild(gmc).gangBalancesOf(user)[gang];
    }
}

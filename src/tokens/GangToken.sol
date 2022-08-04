// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {s as erc20ds} from "UDS/tokens/ERC20UDS.sol";
import {ERC20BurnableUDS} from "UDS/tokens/ERC20BurnableUDS.sol";
import {AccessControlUDS} from "UDS/auth/AccessControlUDS.sol";

abstract contract GangToken is UUPSUpgrade, OwnableUDS, ERC20BurnableUDS, AccessControlUDS {
    uint8 public constant override decimals = 18;

    bytes32 constant MINT_AUTHORITY = keccak256("MINT_AUTHORITY");
    bytes32 constant BURN_AUTHORITY = keccak256("BURN_AUTHORITY");

    function init() public virtual initializer {
        __Ownable_init();
        __AccessControl_init();
    }

    /* ------------- external ------------- */

    function mint(address user, uint256 amount) external onlyRole(MINT_AUTHORITY) {
        _mint(user, amount);
    }

    /* ------------- ERC20Burnable ------------- */

    function burnFrom(address from, uint256 amount) public override {
        if (msg.sender == from || hasRole(BURN_AUTHORITY, msg.sender)) _burn(from, amount);
        else super.burnFrom(from, amount);
    }

    /* ------------- authority ------------- */

    function grantMintAuthority(address operator) external {
        grantRole(MINT_AUTHORITY, operator);
    }

    function grantBurnAuthority(address operator) external {
        grantRole(BURN_AUTHORITY, operator);
    }

    /* ------------- owner ------------- */

    function _authorizeUpgrade() internal override onlyOwner {}
}

contract YakuzaToken is GangToken {
    string public constant override name = "Yakuza Token";
    string public constant override symbol = "YKZ";
}

contract CartelToken is GangToken {
    string public constant override name = "Cartel Token";
    string public constant override symbol = "CTL";
}

contract CyberpunkToken is GangToken {
    string public constant override name = "Cyberpunk Token";
    string public constant override symbol = "CPK";
}

contract Badges is GangToken {
    string public constant override name = "Badges";
    string public constant override symbol = "BDG";
}

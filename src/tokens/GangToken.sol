// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {ERC20BurnableUDS} from "UDS/tokens/extensions/ERC20BurnableUDS.sol";
import {AccessControlUDS} from "UDS/auth/AccessControlUDS.sol";

contract GangToken is UUPSUpgrade, OwnableUDS, ERC20BurnableUDS, AccessControlUDS {
    uint8 public constant override decimals = 18;

    bytes32 constant MINT_AUTHORITY = keccak256("MINT.AUTHORITY");
    bytes32 constant BURN_AUTHORITY = keccak256("BURN.AUTHORITY");

    function init(string calldata name_, string calldata symbol_) external initializer {
        __Ownable_init();
        __AccessControl_init();
        __ERC20_init(name_, symbol_, 18);
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

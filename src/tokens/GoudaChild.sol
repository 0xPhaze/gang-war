// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {s as erc20ds} from "UDS/tokens/ERC20UDS.sol";
import {ERC20BurnableUDS} from "UDS/tokens/extensions/ERC20BurnableUDS.sol";
import {AccessControlUDS} from "UDS/auth/AccessControlUDS.sol";

import {FxERC20ChildUDS} from "fx-contracts/FxERC20ChildUDS.sol";

contract GoudaChild is UUPSUpgrade, OwnableUDS, ERC20BurnableUDS, FxERC20ChildUDS, AccessControlUDS {
    string public constant override name = "Gouda";
    string public constant override symbol = "GOUDA";

    uint8 public constant override decimals = 18;

    bytes32 private constant MINT_AUTHORITY = keccak256("MINT_AUTHORITY");
    bytes32 private constant BURN_AUTHORITY = keccak256("BURN_AUTHORITY");

    constructor(address fxChild) FxERC20ChildUDS(fxChild) {}

    function init() public initializer {
        __Ownable_init();
        __AccessControl_init();
    }

    /* ------------- override ------------- */

    function _authorizeTunnelController() internal override onlyOwner {}

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

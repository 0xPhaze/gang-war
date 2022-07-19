// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {OwnableUDS} from "./lib/upgradeable/OwnableUDS.sol";
// import {FxERC20ChildUDS, FxBaseChildTunnelUDS} from "./lib/upgradeable/FxERC20ChildUDS.sol";
// // import {FxBaseChildTunnelUDS} from "./FxBaseChildTunnelUDS.sol";
// import {AccessControlUDS} from "./lib/upgradeable/AccessControlUDS.sol";
// import {UUPSUpgrade} from "./lib/upgradeable/proxy/UUPSUpgrade.sol";

// import {ds as erc20ds} from "./lib/upgradeable/ERC20UDS.sol";

// contract MiceChild is UUPSUpgrade(1), OwnableUDS, FxERC20ChildUDS, AccessControlUDS {
//     bytes32 private constant MINT_AUTHORITY = keccak256("MINT_AUTHORITY");
//     bytes32 private constant BURN_AUTHORITY = keccak256("BURN_AUTHORITY");

//     constructor(address _fxChild) FxBaseChildTunnelUDS(_fxChild) {}

//     function init() public initializer {
//         // __FxBaseChildTunnelUDS_init(_fxChild);
//         __ERC20UDS_init("MICE", "MICE", 18);

//         _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
//     }

//     /* ------------- UUPSVersioned ------------- */

//     // function proxiableVersion() public pure override returns (uint256) {
//     //     return 1;
//     // }

//     function _authorizeUpgrade() internal override onlyOwner {}

//     /* ------------- Restricted ------------- */

//     function mint(address user, uint256 amount) external payable onlyRole(MINT_AUTHORITY) {
//         _mint(user, amount);
//     }

//     /* ------------- ERC20Burnable ------------- */

//     function burnFrom(address user, uint256 amount) external payable {
//         if (msg.sender != user || !hasRole(BURN_AUTHORITY, msg.sender)) {
//             uint256 allowed = erc20ds().allowance[user][msg.sender];

//             if (allowed != type(uint256).max) erc20ds().allowance[user][msg.sender] = allowed - amount;
//         }

//         _burn(user, amount);
//     }

//     /* ------------- MultiCall ------------- */

//     function multiCall(bytes[] calldata data) external payable {
//         for (uint256 i; i < data.length; ++i) address(this).delegatecall(data[i]);
//     }
// }

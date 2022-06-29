// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/access/AccessControl.sol";
// import "@openzeppelin/contracts/interfaces/IERC721.sol";

// import {Ownable} from "./Ownable.sol";
// import "./lib/root/FxERC20Root.sol";

// contract MiceToken is AccessControl, FxERC20Root {
//     bytes32 private constant MINT_AUTHORITY = keccak256("MINT_AUTHORITY");
//     bytes32 private constant BURN_AUTHORITY = keccak256("BURN_AUTHORITY");

//     constructor(address _checkpointManager, address _fxRoot)
//         ERC20("MICE", "MICE", 18)
//         FxBaseRootTunnel(_checkpointManager, _fxRoot)
//     // @note make immutable
//     {
//         _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
//     }

//     /* ------------- Restricted ------------- */

//     function mint(address user, uint256 amount) external payable onlyRole(MINT_AUTHORITY) {
//         _mint(user, amount);
//     }

//     /* ------------- ERC20Burnable ------------- */

//     function burnFrom(address user, uint256 amount) external payable {
//         if (user != msg.sender || !hasRole(BURN_AUTHORITY, msg.sender)) {
//             uint256 allowed = allowance[user][msg.sender];
//             if (allowed != type(uint256).max) allowance[user][msg.sender] = allowed - amount;
//         }
//         _burn(user, amount);
//     }

//     /* ------------- MultiCall ------------- */

//     function multiCall(bytes[] calldata data) external payable {
//         unchecked {
//             for (uint256 i; i < data.length; ++i) address(this).delegatecall(data[i]); // solhint-disable-line
//         }
//     }

//     /* ------------- Owner ------------- */

//     function withdrawBalance() external payable onlyRole(DEFAULT_ADMIN_ROLE) {
//         uint256 balance = address(this).balance;
//         payable(msg.sender).transfer(balance);
//     }

//     function recoverToken(ERC20 token) external payable onlyRole(DEFAULT_ADMIN_ROLE) {
//         uint256 balance = token.balanceOf(address(this));
//         token.transfer(msg.sender, balance);
//     }

//     function recoverNFT(IERC721 token, uint256 id) external payable onlyRole(DEFAULT_ADMIN_ROLE) {
//         token.transferFrom(address(this), msg.sender, id);
//     }
// }

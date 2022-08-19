//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FxERC721MRootUDS} from "fx-contracts/extensions/FxERC721MRootUDS.sol";
import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {ERC20UDS as ERC20} from "UDS/tokens/ERC20UDS.sol";

import "./lib/LibString.sol";
import "./lib/LibECDSA.sol";

error ExceedsLimit();
error IncorrectValue();
error InvalidSignature();
error NonexistentToken();
error WhitelistNotActive();
error PublicSaleNotActive();
error SignatureExceedsLimit();
error ContractCallNotAllowed();

contract GMC is OwnableUDS, FxERC721MRootUDS {
    using LibString for uint256;
    using LibECDSA for bytes32;

    event SaleStateUpdate();

    bool public publicSaleActive;

    string public constant override name = "Gangsta Mice City";
    string public constant override symbol = "GMC";

    string private baseURI;
    string private unrevealedURI = "ipfs://QmRuQYxmdzqfVfy8ZhZNTvXsmbN9yLnBFPDeczFvWUS2HU/";

    uint256 private constant MAX_SUPPLY = 5555;
    uint256 private constant MAX_PER_WALLET = 20;

    uint256 private constant price = 0.02 ether;
    uint256 private constant whitelistPrice = 0.01 ether;
    uint256 private constant PURCHASE_LIMIT = 5;

    address private signer = 0x68442589f40E8Fc3a9679dE62884c85C6E524888;

    constructor(address checkpointManager, address fxRoot) FxERC721MRootUDS(checkpointManager, fxRoot) {}

    /* ------------- external ------------- */

    function mint(uint256 quantity, bool lock) external payable onlyEOA {
        if (!publicSaleActive) revert PublicSaleNotActive();
        if (PURCHASE_LIMIT < quantity) revert ExceedsLimit();
        if (msg.value != price * quantity) revert IncorrectValue();
        if (totalSupply() + quantity > MAX_SUPPLY) revert ExceedsLimit();
        if (numMinted(msg.sender) + quantity > MAX_PER_WALLET) revert ExceedsLimit();

        if (lock) _mintLockedAndTransmit(msg.sender, quantity);
        else _mint(msg.sender, quantity);
    }

    function whitelistMint(
        uint256 quantity,
        bool lock,
        uint256 limit,
        bytes calldata signature
    ) external payable onlyEOA {
        if (!validSignature(signature, limit)) revert InvalidSignature();
        if (msg.value != whitelistPrice * quantity) revert IncorrectValue();
        if (totalSupply() + quantity > MAX_SUPPLY) revert ExceedsLimit();
        if (numMinted(msg.sender) + quantity > MAX_PER_WALLET) revert ExceedsLimit();

        if (lock) _mintLockedAndTransmit(msg.sender, quantity);
        else _mint(msg.sender, quantity);
    }

    function lockAndTransmit(address from, uint256[] calldata tokenIds) external {
        _lockAndTransmit(from, tokenIds);
    }

    function unlockAndTransmit(address from, uint256[] calldata tokenIds) external {
        _unlockAndTransmit(from, tokenIds);
    }

    function transferOwnershipAndTransmit(address from, uint256[] calldata tokenIds) external {
        _unlockAndTransmit(from, tokenIds);
        _lockAndTransmit(from, tokenIds);
    }

    /* ------------- private ------------- */

    function validSignature(bytes calldata signature, uint256 limit) private view returns (bool) {
        bytes32 hash = keccak256(abi.encode(address(this), msg.sender, limit));
        return hash.toEthSignedMsgHash().isValidSignature(signature, signer);
    }

    /* ------------- owner ------------- */

    function setPublicSaleActive(bool active) external onlyOwner {
        publicSaleActive = active;
        emit SaleStateUpdate();
    }

    function setBaseURI(string calldata _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function setUnrevealedURI(string calldata _uri) external onlyOwner {
        unrevealedURI = _uri;
    }

    function setSigner(address signer_) external onlyOwner {
        signer = signer_;
    }

    function airdrop(
        address[] calldata users,
        uint256[] calldata amounts,
        bool locked
    ) external onlyOwner {
        if (locked) for (uint256 i; i < users.length; ++i) _mintLockedAndTransmit(users[i], amounts[i]);
        else for (uint256 i; i < users.length; ++i) _mint(users[i], amounts[i]);
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function recoverToken(ERC20 token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        token.transfer(msg.sender, balance);
    }

    function _authorizeTunnelController() internal override onlyOwner {}

    /* ------------- modifier ------------- */

    modifier onlyEOA() {
        if (tx.origin != msg.sender) revert ContractCallNotAllowed();
        _;
    }

    /* ------------- ERC721 ------------- */

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (!_exists(id)) revert NonexistentToken();

        return bytes(baseURI).length == 0 ? unrevealedURI : string.concat(baseURI, id.toString(), ".json");
    }
}

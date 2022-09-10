//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUDS} from "UDS/auth/OwnableUDS.sol";
import {FxERC721MRoot} from "fx-contracts/extensions/FxERC721MRoot.sol";
import {ERC20UDS as ERC20} from "UDS/tokens/ERC20UDS.sol";

import "solady/utils/ECDSA.sol";
import "solady/utils/LibString.sol";

error CallFailed();
error ExceedsLimit();
error IncorrectValue();
error MaxSupplyLocked();
error InvalidSignature();
error NonexistentToken();
error InvalidPriceUnits();
error WhitelistNotActive();
error PublicSaleNotActive();
error SignatureExceedsLimit();
error ContractCallNotAllowed();

contract GMC is OwnableUDS, FxERC721MRoot {
    using LibString for uint256;
    using ECDSA for bytes32;

    event SaleStateUpdate();

    string private baseURI;
    string private unrevealedURI = "ipfs://QmRuQYxmdzqfVfy8ZhZNTvXsmbN9yLnBFPDeczFvWUS2HU/";

    bool public publicSaleActive;

    uint16 private publicPriceUnits;
    uint16 private whitelistPriceUnits;

    uint16 public maxSupply = 5555;
    uint16 public constant MAX_PER_WALLET = 20;

    uint256 private constant PURCHASE_LIMIT = 5;
    uint256 private constant PRICE_UNIT = 0.001 ether;

    address private signer = 0x68442589f40E8Fc3a9679dE62884c85C6E524888;

    bool public maxSupplyLocked;

    constructor(address checkpointManager, address fxRoot)
        FxERC721MRoot("Gangsta Mice City", "GMC", checkpointManager, fxRoot)
    {
        __Ownable_init();

        publicPriceUnits = toPriceUnits(0.049 ether);
        whitelistPriceUnits = toPriceUnits(0.039 ether);
    }

    /* ------------- view ------------- */

    function publicPrice() public view returns (uint256) {
        return toPrice(publicPriceUnits);
    }

    function whitelistPrice() public view returns (uint256) {
        return toPrice(whitelistPriceUnits);
    }

    /* ------------- external ------------- */

    function mint(uint256 quantity, bool lock) external payable onlyEOA requireMintable(quantity) {
        if (!publicSaleActive) revert PublicSaleNotActive();
        if (msg.value != publicPrice() * quantity) revert IncorrectValue();

        if (lock) _mintLockedAndTransmit(msg.sender, quantity);
        else _mint(msg.sender, quantity);
    }

    function whitelistMint(
        uint256 quantity,
        bool lock,
        uint256 limit,
        bytes calldata signature
    ) external payable onlyEOA requireMintable(quantity) {
        if (!validSignature(signature, limit)) revert InvalidSignature();
        if (msg.value != whitelistPrice() * quantity) revert IncorrectValue();

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
        return hash.toEthSignedMessageHash().recover(signature) == signer;
    }

    function toPrice(uint16 priceUnits) private pure returns (uint256) {
        unchecked {
            return uint256(priceUnits) * PRICE_UNIT;
        }
    }

    function toPriceUnits(uint256 price) private pure returns (uint16) {
        unchecked {
            uint256 units;
            if (price % PRICE_UNIT != 0) revert InvalidPriceUnits();
            if ((units = price / PRICE_UNIT) > type(uint16).max) revert InvalidPriceUnits();
            return uint16(units);
        }
    }

    /* ------------- owner ------------- */

    function lockMaxSupply() external onlyOwner {
        maxSupplyLocked = true;
    }

    function setSigner(address addr) external onlyOwner {
        signer = addr;
    }

    function setMaxSupply(uint16 value) external onlyOwner {
        if (maxSupplyLocked) revert MaxSupplyLocked();
        maxSupply = value;
    }

    function setPublicPrice(uint256 value) external onlyOwner {
        publicPriceUnits = toPriceUnits(value);
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
    }

    function setPublicSaleActive(bool active) external onlyOwner {
        publicSaleActive = active;
        emit SaleStateUpdate();
    }

    function setWhitelistPrice(uint256 value) external onlyOwner {
        whitelistPriceUnits = toPriceUnits(value);
    }

    function setUnrevealedURI(string calldata uri) external onlyOwner {
        unrevealedURI = uri;
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
        (bool success, ) = msg.sender.call{value: balance}("");
        if (!success) revert CallFailed();
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

    modifier requireMintable(uint256 quantity) {
        unchecked {
            if (quantity > PURCHASE_LIMIT) revert ExceedsLimit();
            if (totalSupply() + quantity > maxSupply) revert ExceedsLimit();
            if (numMinted(msg.sender) + quantity > MAX_PER_WALLET) revert ExceedsLimit();
        }
        _;
    }

    /* ------------- ERC721 ------------- */

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (!_exists(id)) revert NonexistentToken();

        return bytes(baseURI).length == 0 ? unrevealedURI : string.concat(baseURI, id.toString(), ".json");
    }
}

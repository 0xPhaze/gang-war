// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "futils/futils.sol";
import "/tokens/GMCRoot.sol";
import {SetupRoot} from "../src/SetupRoot.sol";

contract TestGMCRoot is Test, SetupRoot {
    using futils for *;
    using ECDSA for bytes32;
    using LibString for *;

    address alice = makeAddr("alice");
    address self = address(this);
    address bob = makeAddr("bob");
    address eve = makeAddr("eve");

    uint256 price;
    uint256 signerPK;
    address signer;

    function setUp() public virtual {
        setUpContracts();

        vm.label(self, "self");

        gmcRoot.setSigner(self);
        gmcRoot.setMintStart(uint32(block.timestamp - 3600 * 2 - 1));

        price = gmcRoot.publicPrice();

        gmcRoot.setFxChildTunnel(address(123));

        signerPK = 0x133737;
        signer = vm.addr(signerPK);
    }

    function setUpUpgradeScripts() internal override {
        UPGRADE_SCRIPTS_BYPASS = true;
    }

    /* ------------- setup() ------------- */

    function test_setUp() public {
        assertEq(gmcRoot.maxSupply(), 6666);
        // assertEq(gmcRoot.mintStart(), block.timestamp);
        assertEq(gmcRoot.publicPrice(), 0.049 ether);
        assertEq(gmcRoot.whitelistPrice(), 0.039 ether);
    }

    /* ------------- mint() ------------- */

    function test_mint(uint256 quantity) public {
        self.balanceDiff();

        uint256 totalSupply = gmcRoot.totalSupply();
        uint256 numMinted = gmcRoot.numMinted(self);

        quantity = bound(quantity, 1, gmcRoot.PURCHASE_LIMIT());

        uint256 value = gmcRoot.publicPrice() * quantity;

        vm.prank(self, self);
        gmcRoot.mint{value: value}(quantity, false);

        if (quantity > 2 && totalSupply + quantity < 1500) quantity++;

        assertEq(self.balanceDiff(), -int256(value));
        assertEq(gmcRoot.totalSupply(), totalSupply + quantity);
        assertEq(gmcRoot.numMinted(self), numMinted + quantity);

        for (uint256 i; i < quantity; ++i) {
            assertEq(gmcRoot.ownerOf(1 + totalSupply + i), self);
        }
    }

    // function test_mint_full_supply() public {
    //     gmcRoot.airdrop([self].toMemory(), gmcRoot.maxSupply(), false);

    //     vm.expectRevert(ExceedsLimit.selector);
    //     vm.prank(self, self);

    //     gmcRoot.mint{value: price}(1, false);

    //     for (uint256 i; i < gmcRoot.maxSupply(); ++i) {
    //         assertEq(gmcRoot.ownerOf(1 + i), self);
    //     }
    // }

    function test_mint_revert_PublicSaleNotActive() public {
        gmcRoot.setMintStart(uint32(block.timestamp + 1 minutes));

        vm.expectRevert(PublicSaleNotActive.selector);
        vm.prank(self, self);

        gmcRoot.mint{value: price}(1, false);
    }

    function test_mint_revert_ExceedsLimit() public {
        uint256 quantity = gmcRoot.PURCHASE_LIMIT() + 1;
        uint256 value = gmcRoot.publicPrice() * quantity;

        vm.expectRevert(ExceedsLimit.selector);
        vm.prank(self, self);

        gmcRoot.mint{value: value}(quantity, false);
    }

    function test_mint_revert_ExceedsLimit2() public {
        // + 1 because of bonus
        test_mint(4);
        test_mint(4);
        test_mint(4);
        test_mint(4);

        assertEq(gmcRoot.numMinted(self), 20);

        vm.prank(self, self);
        vm.expectRevert(ExceedsLimit.selector);

        gmcRoot.mint{value: price}(1, false);
    }

    function test_mint_revert_ExceedsLimit3() public {
        gmcRoot.setMaxSupply(4);

        vm.expectRevert(ExceedsLimit.selector);
        vm.prank(self, self);

        gmcRoot.mint{value: price * 5}(5, false);
    }

    /* ------------- whitelistMint() ------------- */

    function whitelist(uint256 quantity) internal returns (bytes memory signature) {
        gmcRoot.setSigner(signer);

        bytes32 digest = keccak256(abi.encode(address(gmcRoot), self, quantity));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPK, digest.toEthSignedMessageHash());
        signature = abi.encodePacked(r, s, v);
    }

    function test_whitelistMint(uint256 quantity) public {
        gmcRoot.setMintStart(uint32(block.timestamp));

        self.balanceDiff();

        uint256 totalSupply = gmcRoot.totalSupply();
        uint256 numMinted = gmcRoot.numMinted(self);

        quantity = bound(quantity, 1, gmcRoot.PURCHASE_LIMIT());

        bytes memory signature = whitelist(quantity);

        uint256 value = gmcRoot.whitelistPrice() * quantity;

        vm.prank(self, self);
        gmcRoot.whitelistMint{value: value}(quantity, false, quantity, signature);

        if (quantity > 2 && totalSupply + quantity < 1500) quantity++;

        assertEq(self.balanceDiff(), -int256(value));
        assertEq(gmcRoot.totalSupply(), totalSupply + quantity);
        assertEq(gmcRoot.numMinted(self), numMinted + quantity);

        for (uint256 i; i < quantity; ++i) {
            assertEq(gmcRoot.ownerOf(1 + totalSupply + i), self);
        }
    }

    function test_whitelistMint_revert_ExceedsLimit() public {
        gmcRoot.setMintStart(uint32(block.timestamp));

        uint256 limit = 5;
        uint256 quantity = 3;

        bytes memory signature = whitelist(limit);

        uint256 value = gmcRoot.whitelistPrice() * quantity;

        vm.prank(self, self);
        gmcRoot.whitelistMint{value: value}(quantity, false, limit, signature);

        vm.expectRevert(ExceedsLimit.selector);

        vm.prank(self, self);
        gmcRoot.whitelistMint{value: value}(quantity, false, limit, signature);
    }

    function test_whitelistMint_revert_ExceedsLimit2() public {
        uint256 limit = 10;
        uint256 quantity = 10;

        bytes memory signature = whitelist(limit);

        uint256 value = gmcRoot.whitelistPrice() * quantity;

        vm.prank(self, self);
        vm.expectRevert(ExceedsLimit.selector);

        gmcRoot.whitelistMint{value: value}(quantity, false, limit, signature);
    }

    function test_whitelistMint_revert_ExceedsLimit3() public {
        gmcRoot.setMaxSupply(4);

        uint256 limit = 5;
        uint256 quantity = 5;

        bytes memory signature = whitelist(limit);

        uint256 value = gmcRoot.whitelistPrice() * quantity;

        vm.prank(self, self);
        vm.expectRevert(ExceedsLimit.selector);

        gmcRoot.whitelistMint{value: value}(quantity, false, limit, signature);
    }

    /* ------------- lock() ------------- */

    function test_mintAndLock() public {
        vm.prank(self, self);

        gmcRoot.mint{value: 4 * price}(4, true);

        for (uint256 i; i < 4; ++i) {
            assertEq(gmcRoot.ownerOf(1 + i), address(gmcRoot));
            assertEq(gmcRoot.trueOwnerOf(1 + i), self);
        }
    }

    function test_mintThenLock() public {
        uint256 startId = gmcRoot.totalSupply() + 1;

        test_mint(4);

        for (uint256 i; i < 4; ++i) {
            assertEq(gmcRoot.ownerOf(startId + i), self);
            assertEq(gmcRoot.trueOwnerOf(startId + i), self);
        }

        gmcRoot.lockAndTransmit(self, startId.range(startId + 5));
    }

    function test_mintAndLock_unlock() public {
        skip(10 hours);

        test_mintAndLock();
        test_mintThenLock();

        skip(gmcRoot.BRIDGE_RAFFLE_LOCK_DURATION());

        gmcRoot.unlockAndTransmit(self, 1.range(5));
        gmcRoot.unlockAndTransmit(self, 5.range(10));
    }

    function test_mintAndLock_unlock_revert_TimelockActive() public {
        test_mintAndLock();

        for (uint256 i; i < 4; ++i) {
            vm.expectRevert(TimelockActive.selector);

            gmcRoot.unlockAndTransmit(self, [i].toMemory());
        }
    }

    function test_mintThenLock_unlock_revert_TimelockActive() public {
        test_mintThenLock();

        for (uint256 i; i < 4; ++i) {
            vm.expectRevert(TimelockActive.selector);

            gmcRoot.unlockAndTransmit(self, [i].toMemory());
        }
    }

    /* ------------- set() ------------- */

    function test_setSigner() public {
        gmcRoot.setSigner(signer);
    }

    function test_setUnrevealedURI() public {
        string memory uri = "ipfs://1234/";

        gmcRoot.setUnrevealedURI(uri);

        assertEq(gmcRoot.tokenURI(3), uri);
    }

    function test_setURI() public {
        string memory uri = "ipfs://1234/";

        gmcRoot.setBaseURI(uri);

        assertEq(gmcRoot.tokenURI(1), string.concat(uri, uint256(1).toString(), ".json"));
    }

    function test_setMintStart() public {
        gmcRoot.setMintStart(uint32(block.timestamp));

        assertEq(gmcRoot.mintStart(), block.timestamp);
    }

    function test_setPublicPrice() public {
        gmcRoot.setPublicPrice(0.001 ether);

        assertEq(gmcRoot.publicPrice(), 0.001 ether);

        test_mint(2);

        gmcRoot.setPublicPrice(0.234 ether);

        assertEq(gmcRoot.publicPrice(), 0.234 ether);

        test_mint(3);
    }

    /* ------------- withdraw() ------------- */

    function test_withdraw() public {
        test_mint(4);

        self.balanceDiff();

        gmcRoot.withdraw();

        assertEq(self.balanceDiff(), 4 * int256(gmcRoot.publicPrice()));
    }

    receive() external payable {}
}

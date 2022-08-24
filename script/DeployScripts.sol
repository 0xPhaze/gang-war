// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {ERC1967Proxy, ERC1967_PROXY_STORAGE_SLOT} from "UDS/proxy/ERC1967Proxy.sol";

interface VmParseJson {
    function parseJson(string calldata, string calldata) external returns (bytes memory);

    function parseJson(string calldata) external returns (bytes memory);
}

contract ContractRegistryScript is Script {
    struct ContractData {
        string name;
        address addr;
    }

    ContractData[] registeredContracts;

    function registerContract(string memory name, address addr) internal {
        registeredContracts.push(ContractData({name: name, addr: addr}));
    }

    function generateRegisteredContractsJson() internal returns (string memory json) {
        if (registeredContracts.length == 0) return "";

        mkdir(getDeploymentsPath(""));

        json = "{\n";
        for (uint256 i; i < registeredContracts.length; i++) {
            json = string.concat(
                json,
                '  "',
                registeredContracts[i].name,
                '": "',
                vm.toString(registeredContracts[i].addr),
                i + 1 == registeredContracts.length ? '"\n' : '",\n'
            );
        }
        json = string.concat(json, "}");
    }

    function logRegisteredContracts() internal view {
        title("Registered Contracts");

        for (uint256 i; i < registeredContracts.length; i++) {
            console.log("%s=%s", registeredContracts[i].name, registeredContracts[i].addr);
        }
    }

    /* ------------- filePath ------------- */

    function getDeploymentsPath(string memory path) internal returns (string memory) {
        return string.concat("deployments/", vm.toString(block.chainid), "/", path);
    }

    function getDeploymentsDataPath(string memory path) internal returns (string memory) {
        return getDeploymentsPath(string.concat("data/", path));
    }

    function getCreationCodeHashFilePath(address addr) internal returns (string memory) {
        return getDeploymentsDataPath(string.concat(vm.toString(addr), ".creation-code-hash"));
    }

    function getStorageLayoutFilePath(address addr) internal returns (string memory) {
        return getDeploymentsDataPath(string.concat(vm.toString(addr), ".storage-layout"));
    }

    /* ------------- utils ------------- */

    function isFFIEnabled() internal returns (bool) {
        string[] memory script = new string[](1);
        script[0] = "echo";
        try vm.ffi(script) {
            return true;
        } catch {
            return false;
        }
    }

    // hacky until vm.parseBytes32 comes around
    function parseBytes32(string memory data) internal returns (bytes32) {
        vm.setEnv("_TMP", data);
        return vm.envBytes32("_TMP");
    }

    function mkdir(string memory path) internal {
        string[] memory script = new string[](3);
        script[0] = "mkdir";
        script[1] = "-p";
        script[2] = path;

        vm.ffi(script);
    }

    function eq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    /* ------------- prints ------------- */

    function title(string memory name) internal view {
        console.log("\n==========================");
        console.log("%s:\n", name);
    }

    function label(string memory contractName, address addr) internal returns (string memory) {
        return label(contractName, addr, "");
    }

    function label(
        string memory contractName,
        address addr,
        string memory key
    ) internal returns (string memory) {
        return
            string.concat(
                contractName,
                "(",
                vm.toString(addr),
                ")",
                bytes(key).length != 0 ? string.concat(" [", key, "]") : ""
            );
    }

    function proxyLabel(
        address proxy,
        string memory contractName,
        address implementation,
        string memory key
    ) internal returns (string memory) {
        return
            string.concat(
                "Proxy::",
                contractName,
                "(",
                vm.toString(proxy),
                " -> ",
                vm.toString(implementation),
                ")",
                bytes(key).length != 0 ? string.concat(" [", key, "]") : ""
            );
    }
}

contract DeployScripts is ContractRegistryScript {
    bool __DEPLOY_SCRIPTS_BYPASS; // bypasses fancy checks; still deploys contracts
    bool __DEPLOY_SCRIPTS_DRY_RUN; // doesn't log new deployments

    mapping(address => bool) firstTimeDeployed; // set to true for contracts that are just deployed; useful for inits
    mapping(address => bool) storageLayoutGenerated; // cache to not repeat layout generation
    mapping(address => mapping(address => bool)) isUpgradeSafe; // whether a contract => contract is deemed upgrade safe

    constructor() {
        if (!isFFIEnabled()) __DEPLOY_SCRIPTS_DRY_RUN = true;
    }

    /* ------------- setUp ------------- */

    function setUpContract(
        string memory key,
        string memory contractName,
        bytes memory creationCode
    ) internal returns (address implementation) {
        return setUpContract(key, contractName, creationCode, false);
    }

    function setUpContract(
        string memory key,
        string memory contractName,
        bytes memory creationCode,
        bool keepExisting
    ) internal returns (address implementation) {
        if (__DEPLOY_SCRIPTS_BYPASS) return deployCode(creationCode);

        implementation = loadLatestDeployedAddress(key);

        bool deployNew;

        if (implementation != address(0)) {
            if (implementation.code.length == 0) {
                console.log("Stored %s does not contain code.", label(contractName, implementation, key));
                console.log("Make sure '%s' contains all the latest deployments.", getDeploymentsPath("deploy-latest.json")); // prettier-ignore

                revert("Invalid contract address.");
            }

            if (creationCodeHashMatches(implementation, keccak256(creationCode))) {
                console.log("Stored %s up-to-date.", label(contractName, implementation, key));
            } else {
                console.log("Implementation for %s changed.", label(contractName, implementation, key));

                if (keepExisting) console.log("Keeping existing deployment.");
                else deployNew = true;
            }
        } else {
            console.log("Implementation for %s [%s] not found.", contractName, key);
            deployNew = true;
        }

        if (deployNew) {
            implementation = confirmDeployCode(creationCode);

            console.log("=> new %s.\n", label(contractName, implementation, key));

            saveCreationCodeHash(implementation, keccak256(creationCode));
        }

        registerContract(key, implementation);
    }

    function setUpProxy(
        string memory key,
        string memory contractName,
        address implementation,
        bytes memory initCall
    ) internal returns (address) {
        return setUpProxy(key, contractName, implementation, initCall, false);
    }

    function setUpProxy(
        string memory key,
        string memory contractName,
        address implementation,
        bytes memory initCall,
        bool keepExisting
    ) internal returns (address proxy) {
        if (__DEPLOY_SCRIPTS_BYPASS) return deployProxy(implementation, initCall);

        proxy = loadLatestDeployedAddress(key);

        if (proxy != address(0)) {
            address storedImplementation = loadProxyStoredImplementation(proxy);

            if (storedImplementation.codehash == implementation.codehash) {
                console.log("Stored %s up-to-date.", proxyLabel(proxy, contractName, implementation, key));
            } else {
                console.log("Existing %s needs upgrade.", proxyLabel(proxy, contractName, storedImplementation, key)); // prettier-ignore

                if (keepExisting) {
                    console.log("Keeping existing implementation.");
                } else {
                    upgradeSafetyChecks(contractName, storedImplementation, implementation);

                    console.log("Upgrading %s.\n", proxyLabel(proxy, contractName, implementation, key));

                    requireConfirmation("CONFIRM_UPGRADE");

                    UUPSUpgrade(proxy).upgradeToAndCall(implementation, "");
                }
            }
        } else {
            console.log("Existing Proxy::%s [%s] not found.", contractName, key);

            proxy = confirmDeployProxy(implementation, initCall);

            console.log("=> new %s.\n", proxyLabel(proxy, contractName, implementation, key));

            generateStorageLayoutFile(contractName, implementation);
        }

        registerContract(key, proxy);
    }

    function loadLatestDeployedAddress(string memory key) internal returns (address addr) {
        try vm.readFile(getDeploymentsPath("deploy-latest.json")) returns (string memory json) {
            // try vm.parseJson(json, string.concat(".", key)) returns (bytes memory data) {
            try VmParseJson(address(vm)).parseJson(json, string.concat(".", key)) returns (bytes memory data) {
                if (data.length == 32) return abi.decode(data, (address));
            } catch {}
        } catch {}
    }

    /* ------------- snippets ------------- */

    function generateStorageLayoutFile(string memory contractName, address implementation) internal {
        if (storageLayoutGenerated[implementation]) return;

        if (!isFFIEnabled()) {
            return console.log("SKIPPING storage layout mapping for %s (FFI=false).\n", label(contractName, implementation)); // prettier-ignore
        }

        console.log("Generating storage layout mapping for %s.\n", label(contractName, implementation));

        string[] memory script = new string[](4);
        script[0] = "forge";
        script[1] = "inspect";
        script[2] = contractName;
        script[3] = "storage-layout";

        bytes memory out = vm.ffi(script);

        vm.writeFile(getStorageLayoutFilePath(implementation), string(out));

        storageLayoutGenerated[implementation] = true;
    }

    function upgradeSafetyChecks(
        string memory contractName,
        address oldImplementation,
        address newImplementation
    ) internal {
        if (isUpgradeSafe[oldImplementation][newImplementation]) {
            return console.log("Storage layout compatibility check [%s <-> %s]: pass", oldImplementation, newImplementation); // prettier-ignore
        }
        if (!isFFIEnabled()) {
            return console.log("SKIPPING storage layout compatibility check [%s <-> %s] (FFI=false).", oldImplementation, newImplementation); // prettier-ignore
        }

        mkdir(getDeploymentsDataPath(""));

        generateStorageLayoutFile(contractName, newImplementation);

        string[] memory script = new string[](5);

        script[0] = "diff";
        script[1] = "-aw";
        script[2] = "--suppress-common-lines";
        script[3] = getStorageLayoutFilePath(oldImplementation);
        script[4] = getStorageLayoutFilePath(newImplementation);

        bytes memory diff = vm.ffi(script);

        if (diff.length == 0) {
            console.log("Storage layout compatibility check [%s <-> %s]: pass.", oldImplementation, newImplementation);
        } else {
            console.log("Storage layout compatibility check [%s <-> %s]: fail", oldImplementation, newImplementation);
            console.log("\nDiff:");
            console.log(string(diff));

            console.log("If you believe the storage layout is compatible,");
            console.log("add `isUpgradeSafe[%s][%s] = true;` to `run()` in your deploy script.", oldImplementation, newImplementation); // prettier-ignore

            revert("Contract storage layout changed and might not be compatible.");
        }

        isUpgradeSafe[oldImplementation][newImplementation] = true;
    }

    function saveCreationCodeHash(address addr, bytes32 creationCodeHash) internal {
        if (__DEPLOY_SCRIPTS_DRY_RUN) return;

        string memory path = getCreationCodeHashFilePath(addr);

        mkdir(getDeploymentsDataPath("")); // should check for ffi, though DRY_RUN should be true then

        // console.log(string.concat("Saving creation code hash for ", vm.toString(addr), "."));

        vm.writeFile(path, vm.toString(creationCodeHash));
    }

    // .codehash is an improper check for contracts that use immutables
    // deploy = implementation.codehash != getCodeHash(creationCode);
    function creationCodeHashMatches(address addr, bytes32 newCreationCodeHash) internal returns (bool) {
        string memory path = getCreationCodeHashFilePath(addr);

        // try vm.parseJson(path, ".creationCodeHash") returns (bytes memory data) {
        // bytes32 codehash = abi.decode(data, (bytes32));
        try vm.readFile(path) returns (string memory data) {
            bytes32 codehash = parseBytes32(data);

            if (codehash == newCreationCodeHash) {
                // console.log(string.concat("Found matching codehash (", vm.toString(codehash), ") for"), addr);

                return true;
            } else {
                // console.log(string.concat("Existing codehash (", vm.toString(codehash), "), does not match new codehash (", vm.toString(newCreationCodeHash), ") for"), addr); // prettier-ignore
            }
        } catch {
            // console.log("Could not find existing codehash for", addr);
        }
        return false;
    }

    /* ------------- utils ------------- */

    function loadProxyStoredImplementation(address proxy) internal returns (address implementation) {
        require(proxy.code.length != 0, string.concat("No code stored at ", vm.toString(proxy)));

        try vm.load(proxy, ERC1967_PROXY_STORAGE_SLOT) returns (bytes32 data) {
            implementation = address(uint160(uint256(data)));
            require(
                implementation != address(0),
                string.concat("Invalid existing implementation address (0) for proxy ", vm.toString(proxy))
            );
            require(
                UUPSUpgrade(implementation).proxiableUUID() == ERC1967_PROXY_STORAGE_SLOT,
                string.concat("Invalid proxiable UUID for implementation ", vm.toString(implementation))
            );
        } catch {
            console.log("Contract %s not identified as a proxy", proxy);
        }
    }

    function deployProxy(address implementation, bytes memory initCall) internal returns (address) {
        return deployCode(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, initCall)));
    }

    function deployCode(bytes memory code) internal returns (address addr) {
        assembly {
            addr := create(0, add(code, 0x20), mload(code))
        }

        firstTimeDeployed[addr] = true;

        require(addr.code.length != 0, "Failed to deploy code.");
    }

    function confirmDeployProxy(address implementation, bytes memory initCall) internal returns (address) {
        return
            confirmDeployCode(abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, initCall)));
    }

    function confirmDeployCode(bytes memory code) internal returns (address addr) {
        requireConfirmation("CONFIRM_DEPLOYMENT");

        addr = deployCode(code);
    }

    function requireConfirmation(string memory variable) internal {
        if (isTestnet() || __DEPLOY_SCRIPTS_DRY_RUN) return;

        try vm.envBool(variable) returns (bool confirmed) {
            if (!confirmed) {
                console.log("WARNING: `%s=true` must be set", variable);
                console.log("Disabling broadcasting transactions.");
                vm.stopBroadcast();
            }
        } catch {}
    }

    function hasCode(address addr) internal view returns (bool hasCode_) {
        assembly {
            hasCode_ := iszero(iszero(extcodesize(addr)))
        }
    }

    function isTestnet() internal view returns (bool) {
        if (block.chainid == 4) return true;
        if (block.chainid == 3_1337) return true;
        if (block.chainid == 80_001) return true;
        return false;
    }
}

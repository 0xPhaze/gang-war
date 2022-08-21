// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {UUPSUpgrade} from "UDS/proxy/UUPSUpgrade.sol";
import {ERC1967Proxy, ERC1967_PROXY_STORAGE_SLOT} from "UDS/proxy/ERC1967Proxy.sol";

contract DeployScripts is Script {
    /* ------------- setUp ------------- */

    function setUpContract(
        string memory envVar,
        string memory contractName,
        bytes memory creationCode
    ) internal returns (address implementation) {
        return setUpContract(envVar, contractName, creationCode, false);
    }

    function setUpContract(
        string memory envVar,
        string memory contractName,
        bytes memory creationCode,
        bool keepExisting
    ) internal returns (address implementation) {
        implementation = loadLatestDeployedAddress(envVar);

        bool deployNew;

        if (implementation != address(0)) {
            if (implementation.code.length == 0) {
                console.log("Stored contract %s does not contain code.", label(contractName, implementation, envVar));
                console.log("Make sure '%s' contains all the latest deployments.", getDeploymentsPath("deploy-latest.json")); // prettier-ignore

                revert("Invalid contract address.");
            }

            if (creationCodeHashMatches(implementation, keccak256(creationCode))) {
                console.log("Stored contract %s up-to-date.", label(contractName, implementation, envVar));
            } else {
                console.log("Implementation for %s changed.", label(contractName, implementation, envVar));

                if (keepExisting) console.log("Keeping existing contract.");
                else deployNew = true;
            }
        } else {
            console.log("Implementation for %s [%s] not found.", contractName, envVar);
            deployNew = true;
        }

        if (deployNew) {
            implementation = confirmDeployCode(creationCode);

            console.log("=> new %s.\n", label(contractName, implementation, envVar));

            saveCreationCodeHash(implementation, keccak256(creationCode));
        }

        registerContract(envVar, implementation);
    }

    function setUpProxy(
        string memory envVar,
        string memory contractName,
        address implementation,
        bytes memory initCall
    ) internal returns (address) {
        return setUpProxy(envVar, contractName, implementation, initCall, false);
    }

    function setUpProxy(
        string memory envVar,
        string memory contractName,
        address implementation,
        bytes memory initCall,
        bool keepExisting
    ) internal returns (address proxy) {
        proxy = loadLatestDeployedAddress(envVar);

        if (proxy != address(0)) {
            address storedImplementation = loadProxyStoredImplementation(proxy);

            if (storedImplementation.codehash == implementation.codehash) {
                console.log("Stored %s up-to-date.", proxyLabel(proxy, contractName, implementation, envVar));
            } else {
                console.log(
                    "Existing %s needs upgrade.",
                    proxyLabel(proxy, contractName, storedImplementation, envVar)
                );

                if (keepExisting) {
                    console.log("Keeping existing contract.");
                } else {
                    upgradeSafetyChecks(contractName, storedImplementation, implementation);

                    console.log("Upgrading %s.\n", proxyLabel(proxy, contractName, implementation, envVar));

                    if (!isTestnet()) requireConfirmation("CONFIRM_UPGRADE");

                    UUPSUpgrade(proxy).upgradeToAndCall(implementation, "");
                }
            }
        } else {
            console.log("Existing Proxy::%s [%s] not found.", contractName, envVar);

            bytes memory creationCode = abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(implementation, initCall)
            );

            proxy = confirmDeployCode(creationCode);

            console.log("=> new %s", proxyLabel(proxy, contractName, implementation, envVar));

            generateStorageLayoutFile(contractName, implementation);
        }

        registerContract(envVar, proxy);
    }

    /* ------------- snippets ------------- */

    function loadLatestDeployedAddress(string memory key) internal returns (address addr) {
        try vm.readFile(getDeploymentsPath("deploy-latest.json")) returns (string memory json) {
            try vm.parseJson(json, string.concat(".", key)) returns (bytes memory data) {
                if (data.length == 32) return abi.decode(data, (address));
            } catch {}
        } catch {}
    }

    struct ContractData {
        string name;
        address addr;
    }

    ContractData[] registeredContracts;

    function registerContract(string memory name, address addr) internal {
        registeredContracts.push(ContractData({name: name, addr: addr}));
    }

    function logRegisteredContracts() internal {
        title("Registered Contracts");

        for (uint256 i; i < registeredContracts.length; i++) {
            console.log("%s=%s", registeredContracts[i].name, registeredContracts[i].addr);
        }

        if (registeredContracts.length != 0) {
            mkdir(getDeploymentsPath(""));

            string memory json = "{\n";
            for (uint256 i; i < registeredContracts.length; i++) {
                json = string.concat(
                    json,
                    '    "',
                    registeredContracts[i].name,
                    '": "',
                    vm.toString(registeredContracts[i].addr),
                    i + 1 == registeredContracts.length ? '"\n' : '",\n'
                );
            }
            json = string.concat(json, "}");

            vm.writeFile(getDeploymentsPath(string.concat("deploy-latest.json")), json);
            vm.writeFile(getDeploymentsPath(string.concat("deploy-", vm.toString(block.timestamp), ".json")), json);
        }
    }

    mapping(address => mapping(address => bool)) isUpgradeSafe;
    mapping(address => bool) storageLayoutGenerated;

    function generateStorageLayoutFile(string memory contractName, address implementation) internal {
        if (storageLayoutGenerated[implementation]) return;

        console.log("Generating storage layout mapping for %s(%s).", contractName, implementation);

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
        mkdir(getDeploymentsDataPath(""));

        if (isUpgradeSafe[oldImplementation][newImplementation]) {
            console.log("storage layout compatibility check [%s <-> %s]: pass", oldImplementation, newImplementation);
            return;
        }

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

            revert("Contract storage layout changed and might not be compatible.");
        }

        isUpgradeSafe[oldImplementation][newImplementation] = true;
    }

    function saveCreationCodeHash(address addr, bytes32 creationCodeHash) internal {
        mkdir(getDeploymentsDataPath(""));

        string memory path = getCreationCodeHashFilePath(addr);

        // console.log(string.concat("Saving creation code hash for ", vm.toString(addr), "."));

        // note use json once parseJson is fully functional
        // vm.writeFile(path, string.concat('{\n    "creationCodeHash": "', vm.toString(creationCodeHash), '"\n}'));
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

                return false;
            }
        } catch {
            // console.log("Could not find existing codehash for", addr);

            return false;
        }
    }

    // hacky until vm.parseBytes32 comes around
    function parseBytes32(string memory data) internal returns (bytes32) {
        vm.setEnv("_TMP", data);
        return vm.envBytes32("_TMP");
    }

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

    function eq(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function tryLoadEnvString(string memory envVar) internal returns (string memory) {
        return tryLoadEnvString(envVar, "");
    }

    function tryLoadEnvString(string memory envVar, string memory defaultValue) internal returns (string memory) {
        try vm.envString(envVar) returns (string memory value) {
            return value;
        } catch {
            return defaultValue;
        }
    }

    function mkdir(string memory path) internal {
        string[] memory mkdirScript = new string[](3);
        mkdirScript[0] = "mkdir";
        mkdirScript[1] = "-p";
        mkdirScript[2] = path;

        vm.ffi(mkdirScript);
    }

    function deployCode(bytes memory code) internal returns (address addr) {
        assembly {
            addr := create(0, add(code, 0x20), mload(code))
        }
        require(addr.code.length != 0, "Failed to deploy code.");
    }

    function confirmDeployCode(bytes memory code) internal returns (address addr) {
        if (!isTestnet()) requireConfirmation("CONFIRM_DEPLOYMENT");

        return deployCode(code);
    }

    function requireConfirmation(string memory variable) internal {
        bool confirmed;
        try vm.envBool(variable) returns (bool confirmed_) {
            confirmed = confirmed_;
        } catch {}
        if (!confirmed) console.log("`%s=true` must be set", variable);
        require(confirmed, "Deployments/Upgrades require confirmation.");
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

    /* ------------- prints ------------- */

    function title(string memory name) internal view {
        console.log("\n==========================");
        console.log("%s:\n", name);
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

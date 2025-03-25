// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {DeterministicDeployerLib} from "./utils/DeterministicDeployerLib.sol";

contract DeployComposableExecutionModule is Script {

    uint256 deployed;
    uint256 total;

    address public constant MODULE_REGISTRY_ADDRESS = 0x000000000069E2a187AEFFb852bF3cCdC95151B2;
    address public constant EP_V07_ADDRESS = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    address constant ATTESTER_ADDRESS = 0xF9ff902Cdde729b47A4cDB55EF16DF3683a04EAB; // Biconomy Attester

    // COMPOSABLE EXECUTION MODULE DEPLOYMENT SALTS
    bytes32 constant COMPOSABLE_EXECUTION_MODULE_SALT = 0x000000000000000000000000000000000000000025ae50727a43b5038d080986; // => 0x000000009e165Fff03Ca11ddAb083e4429546581;
    bytes32 constant STORAGE_CONTRACT_SALT = 0x00000000000000000000000000000000000000000e67edf598940102c215065c;// => 0x0000000671eb337E12fe5dB0e788F32e1D71B183; 

    ModuleType[] moduleTypesToAttest;

    function setUp() public {}

    function run(bool check) public {
        if (check) {
            checkComposableExecutionModuleAddress();
        } else {
            deployComposableExecutionModule();
        }
    }   

    function checkComposableExecutionModuleAddress() internal {

        // ======== ComposableExecutionModule ========

        bytes32 salt = COMPOSABLE_EXECUTION_MODULE_SALT;
        bytes memory bytecode = vm.getCode("scripts/bash-deploy/artifacts/ComposableExecutionModule/ComposableExecutionModule.json");
        
        address composableExecutionModule = DeterministicDeployerLib.computeAddress(bytecode, salt);
        uint256 codeSize;

        assembly {
            codeSize := extcodesize(composableExecutionModule)
        }
        checkDeployed(codeSize);
        console2.log("ComposableExecutionModule Addr: ", composableExecutionModule, " || >> Code Size: ", codeSize);
        console2.logBytes32(keccak256(abi.encodePacked(bytecode)));

        // =========== Storage contract ===========

        salt = STORAGE_CONTRACT_SALT;
        bytes memory storageBytecode = vm.getCode("scripts/bash-deploy/artifacts/Storage/Storage.json");

        address storageContract = DeterministicDeployerLib.computeAddress(storageBytecode, salt);
        codeSize;
        assembly {
            codeSize := extcodesize(storageContract)
        }
        checkDeployed(codeSize);
        console2.log("StorageContract Addr: ", storageContract, " || >> Code Size: ", codeSize);
        console2.logBytes32(keccak256(abi.encodePacked(storageBytecode)));

    }


// #########################################################################################
// ################## DEPLOYMENT ##################
// #########################################################################################

    function deployComposableExecutionModule() internal {

        // ======== ComposableExecutionModule ========

        bytes32 salt = COMPOSABLE_EXECUTION_MODULE_SALT;
        bytes memory bytecode = vm.getCode("scripts/bash-deploy/artifacts/ComposableExecutionModule/ComposableExecutionModule.json");
        address composableExecutionModule = DeterministicDeployerLib.computeAddress(bytecode, salt);
        uint256 codeSize;

        assembly {
            codeSize := extcodesize(composableExecutionModule)
        }
        if (codeSize > 0) {
            console2.log("ComposableExecutionModule already deployed at: ", composableExecutionModule, " skipping deployment");
        } else {
            composableExecutionModule = DeterministicDeployerLib.broadcastDeploy(bytecode, salt);
            console2.log("ComposableExecutionModule deployed at: ", composableExecutionModule);
            console2.log("Registering ComposableExecutionModule on registry");
            
            // Register ComposableExecutionModule on registry and attest
            if (_registerModule(composableExecutionModule)) {
                _attestModule(composableExecutionModule);
            }
        }

        // =========== Storage contract ===========

        salt = STORAGE_CONTRACT_SALT;
        bytes memory storageBytecode = vm.getCode("scripts/bash-deploy/artifacts/Storage/Storage.json");
        address storageContract = DeterministicDeployerLib.computeAddress(storageBytecode, salt);

        assembly {
            codeSize := extcodesize(storageContract)
        }
        if (codeSize > 0) {
            console2.log("StorageContract already deployed at: ", storageContract, " skipping deployment");
        } else {
            storageContract = DeterministicDeployerLib.broadcastDeploy(storageBytecode, salt);
            console2.log("StorageContract deployed at: ", storageContract);
        }
    }

    function checkDeployed(uint256 codeSize) internal {
        if (codeSize > 0) {
            deployed++;
        }
        total++;
    }

    function _registerModule(address moduleAddress) internal returns (bool) {
        IRegistryModuleManager registry = IRegistryModuleManager(MODULE_REGISTRY_ADDRESS);

        uint256 codeSize;
        assembly {
            codeSize := extcodesize(MODULE_REGISTRY_ADDRESS)
        }
        if (codeSize == 0) {
            console2.log("Module registry not deployed => module not registered on registry");
            return false;
        }
        ResolverUID resolverUID = ResolverUID.wrap(0xdbca873b13c783c0c9c6ddfc4280e505580bf6cc3dac83f8a0f7b44acaafca4f);
        ModuleRecord memory moduleRecord = registry.findModule(moduleAddress);

        bool isRegistered = ResolverUID.unwrap(moduleRecord.resolverUID) != bytes32(0x0000000000000000000000000000000000000000000000000000000000000000);
        bool res;
        if (isRegistered) {
            console2.log("Module already registered on registry");
            return true;
        } else {
            vm.startBroadcast();
            try registry.registerModule(
                resolverUID,
                moduleAddress,
                hex"",
                hex""
            ) {
                console2.log("Module registered on registry");
                res = true;
            } catch (bytes memory reason) {
                console2.log("Module not registered on registry: registration failed");
                console2.logBytes(reason);
                res = false;
            }
            vm.stopBroadcast();
        }
        return res;
    }

    function _attestModule(address moduleAddress) internal returns (bool) {
        IRegistryModuleManager registry = IRegistryModuleManager(MODULE_REGISTRY_ADDRESS);

        address[] memory attesters = new address[](1);
        attesters[0] = ATTESTER_ADDRESS;
        
        ModuleType[] memory moduleTypes = new ModuleType[](2);
        moduleTypes[0] = ModuleType.wrap(uint256(2)); // executor
        moduleTypes[1] = ModuleType.wrap(uint256(3)); // fallback

        // check if module is already attested
        uint256 needToAttest = 0;
        for (uint256 i; i < moduleTypes.length; i++) {
            ModuleType moduleType = moduleTypes[i];
            try registry.check(moduleAddress, moduleType, attesters, 1) {
                console2.log("Attestation as type %s successful, check passed", ModuleType.unwrap(moduleType));
            } catch (bytes memory reason) {
                console2.log("Module not attested as type %s, attesting...", ModuleType.unwrap(moduleType));
                needToAttest++;
                moduleTypesToAttest.push(moduleType);
            }
        }

        if (needToAttest == 0) {
            console2.log("Module already attested, skipping attestation");
            return true;
        }

        if (moduleTypesToAttest.length != needToAttest) {
            revert("Module types to attest mismatch");
        }

        AttestationRequest memory meeK1ValidatorAttestationRequest = AttestationRequest({
            moduleAddress: moduleAddress,
            expirationTime: uint48(block.timestamp + 7130 days),
            data: bytes(""),
            moduleTypes: moduleTypesToAttest
        });

        bytes memory cd = abi.encodeWithSelector(
            // attest(bytes32, AttestationRequest) (0x945e3641) 
            bytes4(0x945e3641),
            bytes32(0x93d46fcca4ef7d66a413c7bde08bb1ff14bacbd04c4069bb24cd7c21729d7bf1), //schema UID <= need to be added by Rhinestone to the registry
            meeK1ValidatorAttestationRequest
        );
        //console.logBytes(cd);

        vm.startBroadcast();

        IAttester attester = IAttester(ATTESTER_ADDRESS);

        try attester.adminExecute(Execution({
            target: MODULE_REGISTRY_ADDRESS,
            value: 0,
            callData: cd
        })) {
            console2.log("Attestation successful, re-checking");
            for (uint256 i; i < moduleTypesToAttest.length; i++) {
                ModuleType moduleType = moduleTypesToAttest[i];
                console2.log("Checking attestations for module %s with type %s", moduleAddress, ModuleType.unwrap(moduleType));
                try registry.check(moduleAddress, moduleType, attesters, 1) {
                    console2.log("Attestation successful, check passed");
                } catch (bytes memory reason) {
                    console2.log("Check failed");
                    console2.logBytes(reason);
                }
            }
        } catch (bytes memory reason) {
            console2.log("Attestation failed");
            console2.logBytes(reason);
        }

        vm.stopBroadcast();
    }
}

type ResolverUID is bytes32;

struct ModuleRecord {
    ResolverUID resolverUID; // The unique identifier of the resolver.
    address sender; // The address of the sender who deployed the contract
    bytes metadata; // Additional data related to the contract deployment
}

struct Execution {
    address target;
    uint256 value;
    bytes callData;
}

type ModuleType is uint256;

struct AttestationRequest {
    address moduleAddress;
    uint48 expirationTime;
    bytes data;
    ModuleType[] moduleTypes;
}

interface IRegistryModuleManager {
    function registerModule(
        ResolverUID resolverUID,
        address moduleAddress,
        bytes calldata metadata,
        bytes calldata resolverContext
    ) external;

    function findModule(address moduleAddress) external view returns (ModuleRecord memory);

    function check(address module, ModuleType moduleType, address[] calldata attesters, uint256 threshold) external view;
}

interface IAttester {
    function adminExecute(Execution memory execution) external;
}
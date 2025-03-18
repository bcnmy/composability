// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IAccount} from "account-abstraction/interfaces/IAccount.sol";
import {PackedUserOperation} from "account-abstraction/core/UserOperationLib.sol";
import {IValidator, IFallback} from "erc7579/interfaces/IERC7579Module.sol";
import {IStatelessValidator} from "node_modules/@rhinestone/module-bases/src/interfaces/IStatelessValidator.sol";
import {EIP1271_SUCCESS, EIP1271_FAILED} from "contracts/types/Constants.sol";
import {ERC2771Lib} from "./lib/ERC2771Lib.sol";
import {ComposableExecutionBase} from "contracts/ComposableExecutionBase.sol";
import {ComposableExecution} from "contracts/types/ComposabilityDataTypes.sol";

import {console2} from "forge-std/console2.sol";

address constant ENTRY_POINT_V07 = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

contract MockAccount is ComposableExecutionBase, IAccount {
    event MockAccountValidateUserOp(PackedUserOperation userOp, bytes32 userOpHash, uint256 missingAccountFunds);
    event MockAccountExecute(address to, uint256 value, bytes data);
    event MockAccountReceive(uint256 value);
    event MockAccountFallback(bytes callData, uint256 value);

    error ExecutionFailed();
    error OnlyEntryPointOrSelf();

    IValidator public validator;
    IFallback public handler;

    constructor(address _validator, address _handler) {
        validator = IValidator(_validator);
        handler = IFallback(_handler);
    }

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        returns (uint256 vd)
    {
        if (address(validator) != address(0)) {
            vd = validator.validateUserOp(userOp, userOpHash);
        }
        // if validator is not set, return 0 = success
    }

    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4) {
        return
            IValidator(address(validator)).isValidSignatureWithSender({sender: msg.sender, hash: hash, data: signature});
    }

    function validateSignatureWithData(bytes32 signedHash, bytes calldata signature, bytes calldata signerData)
        external
        view
        returns (bool)
    {
        return IStatelessValidator(address(validator)).validateSignatureWithData({
            hash: signedHash,
            signature: signature,
            data: signerData
        });
    }

    function execute(address to, uint256 value, bytes calldata data)
        external
        returns (bool success, bytes memory result)
    {
        emit MockAccountExecute(to, value, data);
        (success, result) = to.call{value: value}(data);
    }

    function executeComposable(ComposableExecution[] calldata executions) external override {
        require(msg.sender == ENTRY_POINT_V07 || msg.sender == address(this), OnlyEntryPointOrSelf());
        _executeComposable(executions);
    }

    function _executeAction(address to, uint256 value, bytes memory data)
        internal
        override
        returns (bytes memory returnData)
    {
        bool success;
        (success, returnData) = to.call{value: value}(data);
        if (!success) {
            revert ExecutionFailed();
        }
    }

    receive() external payable {
        emit MockAccountReceive(msg.value);
    }

    fallback(bytes calldata callData) external payable returns (bytes memory) {
        (bool success, bytes memory result) =
            address(handler).call{value: msg.value}(ERC2771Lib.get2771CallData(callData));
        if (!success) {
            revert(string(result));
        }
        emit MockAccountFallback(callData, msg.value);
    }

    function eip712Domain()
        public
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (bytes1(0), "MockAccount", "1.0", block.chainid, address(this), bytes32(0), new uint256[](0));
    }
}

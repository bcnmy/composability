// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IAccount} from "account-abstraction/interfaces/IAccount.sol";
import {PackedUserOperation} from "account-abstraction/core/UserOperationLib.sol";
import {IValidator, IFallback, IExecutor} from "erc7579/interfaces/IERC7579Module.sol";
import {IStatelessValidator} from "node_modules/@rhinestone/module-bases/src/interfaces/IStatelessValidator.sol";
import {EIP1271_SUCCESS, EIP1271_FAILED} from "contracts/types/Constants.sol";
import {ERC2771Lib} from "./lib/ERC2771Lib.sol";
import {ExecutionLib} from "erc7579/lib/ExecutionLib.sol";
import {ModeLib, ModeCode as ExecutionMode, CallType, ExecType, CALLTYPE_SINGLE} from "erc7579/lib/ModeLib.sol";
import "contracts/interfaces/IComposableExecution.sol";

import {console2} from "forge-std/console2.sol";

contract MockAccountFallback is IAccount {
    event MockAccountValidateUserOp(PackedUserOperation userOp, bytes32 userOpHash, uint256 missingAccountFunds);
    event MockAccountExecute(address to, uint256 value, bytes data);
    event MockAccountReceive(uint256 value);
    event MockAccountFallback(bytes callData, uint256 value);

    error OnlyExecutor();
    error FallbackFailed(bytes result);
    IValidator public validator;
    IFallback public handler;
    IExecutor public executor;

    using ExecutionLib for bytes;
    using ModeLib for ExecutionMode;

    constructor(address _validator, address _executor, address _handler) {
        validator = IValidator(_validator);
        executor = IExecutor(_executor);
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

    function executeFromExecutor(ExecutionMode mode, bytes calldata executionCalldata)
        external
        payable
        returns (bytes[] memory returnData)
    {
        require(msg.sender == address(executor), OnlyExecutor());

        (CallType callType, ExecType execType,,) = mode.decode();
        if (callType == CALLTYPE_SINGLE) {
            returnData = new bytes[](1);
            // support for single execution only
            (address target, uint256 value, bytes calldata callData) = executionCalldata.decodeSingle();
            returnData[0] = _execute(target, value, callData);
        } else {
            revert("Unsupported call type");
        }
    }

    function _execute(address target, uint256 value, bytes calldata callData)
        internal
        virtual
        returns (bytes memory result)
    {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            calldatacopy(result, callData.offset, callData.length)
            if iszero(call(gas(), target, value, result, callData.length, codesize(), 0x00)) {
                // Bubble up the revert if the call reverts.
                returndatacopy(result, 0x00, returndatasize())
                revert(result, returndatasize())
            }
            mstore(result, returndatasize()) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, returndatasize()) // Copy the returndata.
            mstore(0x40, add(o, returndatasize())) // Allocate the memory.
        }
    }

    receive() external payable {
        emit MockAccountReceive(msg.value);
    }

    fallback(bytes calldata callData) external payable returns (bytes memory) {
        (bool success, bytes memory result) =
            address(handler).call{value: msg.value}(ERC2771Lib.get2771CallData(callData));
        if (!success) {
            revert FallbackFailed(result);
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

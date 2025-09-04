// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Storage} from "./Storage.sol";
import {InputParam, OutputParam, Constraint, ConstraintType, InputParamType, InputParamFetcherType, OutputParamFetcherType} from "./types/ComposabilityDataTypes.sol";
import {Execution} from "erc7579/interfaces/IERC7579Account.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Library for composable execution handling
library ComposableExecutionLib {

    error ConstraintNotMet(ConstraintType constraintType);
    error Output_StaticCallFailed();
    error InvalidParameterEncoding(string message);
    error InvalidOutputParamFetcherType();
    error ComposableExecutionFailed();
    error InvalidConstraintType();

    // Process the input parameters and return the composed calldata
    function processInputs(InputParam[] calldata inputParams, bytes4 functionSig)
        internal
        view
        returns (Execution memory)
    {
        address composedTarget;
        uint256 composedValue;
        bytes memory composedCalldata = abi.encodePacked(functionSig);
        uint256 length = inputParams.length;
        for (uint256 i; i < length; i++) {
            bytes memory processedInput = processInput(inputParams[i]);
            if (inputParams[i].paramType == InputParamType.TARGET) {
                if (inputParams[i].fetcherType == InputParamFetcherType.BALANCE) {
                   revert InvalidParameterEncoding("BALANCE fetcher type is not supported for TARGET param type");
                }
                composedTarget = abi.decode(processedInput, (address));
            } else if (inputParams[i].paramType == InputParamType.VALUE) {
                composedValue = abi.decode(processedInput, (uint256));
            } else if (inputParams[i].paramType == InputParamType.CALL_DATA) {
                composedCalldata = bytes.concat(composedCalldata, processedInput);
            } else {
                revert InvalidParameterEncoding("Invalid param type");
            }
        }
        return Execution({
            target: composedTarget,
            value: composedValue,
            callData: composedCalldata
        });
    }

    // Process a single input parameter and return the composed calldata
    function processInput(InputParam calldata param) internal view returns (bytes memory) {
        if (param.fetcherType == InputParamFetcherType.RAW_BYTES) {
            _validateConstraints(param.paramData, param.constraints);
            return param.paramData;
        } else if (param.fetcherType == InputParamFetcherType.STATIC_CALL) {
            address contractAddr;
            bytes calldata callData;
            bytes calldata paramData = param.paramData;
            assembly {
                contractAddr := calldataload(paramData.offset)
                let s := calldataload(add(paramData.offset, 0x20))
                let u := add(paramData.offset, s)
                callData.offset := add(u, 0x20)
                callData.length := calldataload(u)
            }
            (bool success, bytes memory returnData) = contractAddr.staticcall(callData);
            if (!success) {
                revert ComposableExecutionFailed();
            }
            _validateConstraints(returnData, param.constraints);
            return returnData;
        } else if (param.fetcherType == InputParamFetcherType.BALANCE) {
            address contractAddr;
            address account;
            bytes calldata paramData = param.paramData;
            assembly {
                contractAddr := shr(96, calldataload(paramData.offset))
                account := shr(96, calldataload(add(paramData.offset, 0x14)))
            }
            uint256 balance;
            if (contractAddr == address(0)) {
                balance = account.balance;
            } else {
                balance = IERC20(contractAddr).balanceOf(account);
            }
            _validateConstraints(abi.encode(balance), param.constraints);
            return abi.encode(balance);
        } else {
            revert InvalidParameterEncoding("Invalid param fetcher type");
        }
    }

    // Process the output parameters
    function processOutputs(OutputParam[] calldata outputParams, bytes memory returnData, address account) internal {
        uint256 length = outputParams.length;
        for (uint256 i; i < length; i++) {
            processOutput(outputParams[i], returnData, account);
        }
    }

    // Process a single output parameter and write to storage
    function processOutput(OutputParam calldata param, bytes memory returnData, address account) internal {
        // only static types are supported for now as return values
        // can also process all the static return values which are before the first dynamic return value in the returnData
        if (param.fetcherType == OutputParamFetcherType.EXEC_RESULT) {
            uint256 returnValues;
            address targetStorageContract;
            bytes32 targetStorageSlot;
            bytes calldata paramData = param.paramData;
            assembly {
                returnValues := calldataload(paramData.offset)
                targetStorageContract := calldataload(add(paramData.offset, 0x20))
                targetStorageSlot := calldataload(add(paramData.offset, 0x40))
            }
            _parseReturnDataAndWriteToStorage(returnValues, returnData, targetStorageContract, targetStorageSlot, account);
        // same for static calls
        } else if (param.fetcherType == OutputParamFetcherType.STATIC_CALL) {
            uint256 returnValues;
            address sourceContract;
            bytes calldata sourceCallData;
            address targetStorageContract;
            bytes32 targetStorageSlot;
            bytes calldata paramData = param.paramData;
            assembly {
                returnValues := calldataload(paramData.offset)
                sourceContract := calldataload(add(paramData.offset, 0x20))
                let s := calldataload(add(paramData.offset, 0x40))
                let u := add(paramData.offset, s)
                sourceCallData.offset := add(u, 0x20)
                sourceCallData.length := calldataload(u)
                targetStorageContract := calldataload(add(paramData.offset, 0x60))
                targetStorageSlot := calldataload(add(paramData.offset, 0x80))
            }
            (bool outputSuccess, bytes memory outputReturnData) = sourceContract.staticcall(sourceCallData);
            if (!outputSuccess) {
                revert Output_StaticCallFailed();
            }
            _parseReturnDataAndWriteToStorage(returnValues, outputReturnData, targetStorageContract, targetStorageSlot, account);
        } else {
            revert InvalidOutputParamFetcherType();
        }
    }

    /// @dev Validate the constraints => compare the value with the reference data
    function _validateConstraints(bytes memory rawValue, Constraint[] calldata constraints)
        private
        pure
    {
        if (constraints.length > 0) {
            for (uint256 i; i < constraints.length; i++) {
                Constraint memory constraint = constraints[i];
                bytes32 returnValue;
                assembly {
                    returnValue := mload(add(rawValue, add(0x20, mul(i, 0x20))))
                }
                if (constraint.constraintType == ConstraintType.EQ) {
                    require(returnValue == bytes32(constraint.referenceData), ConstraintNotMet(ConstraintType.EQ));
                } else if (constraint.constraintType == ConstraintType.GTE) {
                    require(returnValue >= bytes32(constraint.referenceData), ConstraintNotMet(ConstraintType.GTE));
                } else if (constraint.constraintType == ConstraintType.LTE) {
                    require(returnValue <= bytes32(constraint.referenceData), ConstraintNotMet(ConstraintType.LTE));
                } else if (constraint.constraintType == ConstraintType.IN) {
                    (bytes32 lowerBound, bytes32 upperBound) = abi.decode(constraint.referenceData, (bytes32, bytes32));
                    require(returnValue >= lowerBound && returnValue <= upperBound, ConstraintNotMet(ConstraintType.IN));
                } else {
                    revert InvalidConstraintType();
                }
            }
        }
    }

    /// @dev Parse the return data and write to the appropriate storage contract
    function _parseReturnDataAndWriteToStorage(uint256 returnValues, bytes memory returnData, address targetStorageContract, bytes32 targetStorageSlot, address account) internal {
        for (uint256 i; i < returnValues; i++) {
            bytes32 value;
            assembly {
                value := mload(add(returnData, add(0x20, mul(i, 0x20))))
            }
            Storage(targetStorageContract).writeStorage({
                slot: keccak256(abi.encodePacked(targetStorageSlot, i)),
                value: value,
                account: account
            });
        }
    }
}

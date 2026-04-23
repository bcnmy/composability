// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Storage } from "./Storage.sol";
import {
    InputParam,
    OutputParam,
    Constraint,
    ConstraintType,
    InputParamType,
    InputParamFetcherType,
    OutputParamFetcherType
} from "./types/ComposabilityDataTypes.sol";
import { Execution } from "erc7579/interfaces/IERC7579Account.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Library for composable execution handling
library ComposableExecutionLib {
    error ConstraintNotMet(ConstraintType constraintType);
    error Output_StaticCallFailed();
    error InvalidParameterEncoding(string message);
    error InvalidOutputParamFetcherType();
    error ComposableExecutionFailed();
    error InvalidConstraintType();
    error InvalidSetOfInputParams(string message);

    // Process the input parameters and return the composed calldata
    function processInputs(InputParam[] calldata inputParams, bytes4 functionSig) internal view returns (Execution memory) {
        address composedTarget;
        uint256 composedValue;
        bytes memory composedCalldata = abi.encodePacked(functionSig);
        uint256 length = inputParams.length;

        // Bit 0: TARGET param type set, Bit 1: VALUE param type set
        uint256 paramTypeFlags = 0;
        for (uint256 i; i < length; i++) {
            bytes memory processedInput = processInput(inputParams[i]);
            if (inputParams[i].paramType == InputParamType.TARGET) {
                if (inputParams[i].fetcherType == InputParamFetcherType.BALANCE) {
                    revert InvalidParameterEncoding("BALANCE fetcher type is not supported for TARGET param type");
                }
                // Check if TARGET has already been set (bit 0)
                if (paramTypeFlags & 1 != 0) {
                    revert InvalidSetOfInputParams("TARGET param type can only be set once");
                }
                paramTypeFlags |= 1; // Set bit 0
                composedTarget = abi.decode(processedInput, (address));
            } else if (inputParams[i].paramType == InputParamType.VALUE) {
                // Check if VALUE has already been set (bit 1)
                if (paramTypeFlags & 2 != 0) {
                    revert InvalidSetOfInputParams("VALUE param type can only be set once");
                }
                paramTypeFlags |= 2; // Set bit 1
                composedValue = abi.decode(processedInput, (uint256));
            } else if (inputParams[i].paramType == InputParamType.CALL_DATA) {
                composedCalldata = bytes.concat(composedCalldata, processedInput);
            } else {
                revert InvalidParameterEncoding("Invalid param type");
            }
        }
        // if a param with TARGET type was not provided, it will be address(0)
        // we don't restrict it since some calls may want to call address(0)
        // if a param with VALUE type was not provided, it will be 0
        // this is even more often case, as many calls happen with 0 value
        return Execution({ target: composedTarget, value: composedValue, callData: composedCalldata });
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
            // expect paramData to be abi.encode(address contractAddr, bytes callData)
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
            address tokenAddr;
            address account;
            bytes calldata paramData = param.paramData;

            // expect paramData to be abi.encodePacked(address token, address account)
            // Validate exact length requirement
            require(paramData.length == 40, InvalidParameterEncoding("Invalid paramData length"));
            assembly {
                tokenAddr := shr(96, calldataload(paramData.offset))
                account := shr(96, calldataload(add(paramData.offset, 0x14)))
            }

            uint256 balance;
            if (tokenAddr == address(0)) {
                balance = account.balance;
            } else {
                balance = IERC20(tokenAddr).balanceOf(account);
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

    /// @dev Validate the constraints => compare each 32-byte word of rawValue against constraints[i].
    /// Each constraints[i] is checked against the i-th 32-byte word of rawValue (AND semantics across
    /// the array). Use ConstraintType.OR to express OR semantics within a single word position.
    ///
    /// AND vs OR encoding:
    /// - AND is implicit across the top-level `Constraint[]`. Every non-OR entry has a static
    ///   32-byte reference (EQ/GTE/LTE/GTE_SIGNED/LTE_SIGNED) or a fixed 64-byte (lower, upper)
    ///   payload (IN) — predictable layout, predictable gas.
    /// - OR is a single entry whose `referenceData` is a dynamic `abi.encode(Constraint[])`. It is
    ///   decoded once here and evaluated against the *same* 32-byte word as the outer entry. The
    ///   sub-constraints inside the OR must be leaf constraints only — nesting OR inside OR is
    ///   intentionally rejected (see `_checkConstraint`) to keep what the user signs flat and
    ///   easy to display. Example:
    ///
    ///     Constraint[] memory subs = new Constraint[](2);
    ///     subs[0] = Constraint({ constraintType: ConstraintType.EQ,  referenceData: abi.encode(bytes32(uint256(0))) });
    ///     subs[1] = Constraint({ constraintType: ConstraintType.GTE, referenceData: abi.encode(bytes32(uint256(100))) });
    ///     Constraint memory orC = Constraint({ constraintType: ConstraintType.OR, referenceData: abi.encode(subs) });
    ///     // attach orC to the InputParam; passes iff value == 0 OR value >= 100
    function _validateConstraints(bytes memory rawValue, Constraint[] calldata constraints) private pure {
        uint256 len = constraints.length;
        for (uint256 i; i < len;) {
            Constraint memory c = constraints[i];
            bytes32 value;
            assembly {
                value := mload(add(rawValue, add(0x20, mul(i, 0x20))))
            }
            if (c.constraintType == ConstraintType.OR) {
                Constraint[] memory subs = abi.decode(c.referenceData, (Constraint[]));
                uint256 subsLen = subs.length;
                bool anyMet;
                for (uint256 j; j < subsLen;) {
                    if (_checkConstraint(value, subs[j])) {
                        anyMet = true;
                        break;
                    }
                    unchecked {
                        ++j;
                    }
                }
                if (!anyMet) revert ConstraintNotMet(c.constraintType);
            } else {
                if (!_checkConstraint(value, c)) revert ConstraintNotMet(c.constraintType);
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Returns true if value satisfies constraint c. OR is rejected here: nested OR is not
    /// supported, so only leaf constraints may appear inside an OR's sub-array.
    function _checkConstraint(bytes32 value, Constraint memory c) private pure returns (bool) {
        ConstraintType ct = c.constraintType;
        if (ct == ConstraintType.EQ) {
            return value == bytes32(c.referenceData);
        } else if (ct == ConstraintType.GTE) {
            return value >= bytes32(c.referenceData);
        } else if (ct == ConstraintType.LTE) {
            return value <= bytes32(c.referenceData);
        } else if (ct == ConstraintType.IN) {
            (bytes32 lower, bytes32 upper) = abi.decode(c.referenceData, (bytes32, bytes32));
            return value >= lower && value <= upper;
        } else if (ct == ConstraintType.GTE_SIGNED) {
            return int256(uint256(value)) >= int256(uint256(bytes32(c.referenceData)));
        } else if (ct == ConstraintType.LTE_SIGNED) {
            return int256(uint256(value)) <= int256(uint256(bytes32(c.referenceData)));
        } else {
            revert InvalidConstraintType();
        }
    }

    /// @dev Parse the return data and write to the appropriate storage contract
    function _parseReturnDataAndWriteToStorage(
        uint256 returnValues,
        bytes memory returnData,
        address targetStorageContract,
        bytes32 targetStorageSlot,
        address account
    )
        internal
    {
        for (uint256 i; i < returnValues; i++) {
            bytes32 value;
            assembly {
                value := mload(add(returnData, add(0x20, mul(i, 0x20))))
            }
            Storage(targetStorageContract).writeStorage({ slot: keccak256(abi.encodePacked(targetStorageSlot, i)), value: value, account: account });
        }
    }
}

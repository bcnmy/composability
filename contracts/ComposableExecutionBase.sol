// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ComposableExecutionLib} from "./ComposableExecutionLib.sol";
import {InputParam, OutputParam, ComposableExecution, Constraint, ConstraintType, InputParamFetcherType, InputParamType, OutputParamFetcherType} from "./types/ComposabilityDataTypes.sol";
import {IComposableExecution} from "./interfaces/IComposableExecution.sol";
import {Execution} from "erc7579/interfaces/IERC7579Account.sol";

abstract contract ComposableExecutionBase is IComposableExecution {
    using ComposableExecutionLib for InputParam[];
    using ComposableExecutionLib for OutputParam[];

    /// @dev Override it in the account and introduce additional access control or other checks
    function executeComposable(ComposableExecution[] calldata cExecutions) external payable virtual;

    /// @dev internal function to execute the composable execution flow
    /// First, processes the input parameters and returns the composed calldata
    /// Then, executes the action
    /// Then, processes the output parameters
    function _executeComposable(ComposableExecution[] calldata cExecutions) internal {
        uint256 length = cExecutions.length;
        for (uint256 i; i < length; i++) {
            ComposableExecution calldata cExecution = cExecutions[i];
            Execution memory execution = cExecution.inputParams.processInputs(cExecution.functionSig);
            bytes memory returnData;
            if (execution.target != address(0)) {
                returnData = _executeAction(execution.target, execution.value, execution.callData);
            } else {
                returnData = new bytes(0);
            }
            // TODO: add early sanity check that output params length is > 0
            // so if it is 0, we can not even call processOutputs
            cExecution.outputParams.processOutputs(returnData, address(this));
        }
    }

    /// @dev Override this in the account
    /// using account's native execution approach
    /// we do not use Execution struct as an argument to be as less opinionated as possible
    /// instead we just use standard types
    function _executeAction(address to, uint256 value, bytes memory data)
        internal
        virtual
        returns (bytes memory returnData);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IExecutor} from "erc7579/interfaces/IERC7579Module.sol";
import {IERC7579Account} from "erc7579/interfaces/IERC7579Account.sol";
import {ModeLib} from "erc7579/lib/ModeLib.sol";
import {ExecutionLib} from "erc7579/lib/ExecutionLib.sol";
import {ERC7579FallbackBase} from "module-bases/ERC7579FallbackBase.sol";
import {IComposableExecutionModule} from "./interfaces/IComposableExecution.sol";
import {ComposableExecutionLib} from "./ComposableExecutionLib.sol";
import {InputParam, OutputParam, ComposableExecution, Constraint, ConstraintType, InputParamFetcherType, OutputParamFetcherType} from "./types/ComposabilityDataTypes.sol";

/**
 * @title Composable Execution Module: Executor and Fallback
 * @dev A module for ERC-7579 accounts that enables composable transactions execution
 */
contract ComposableExecutionModule is IComposableExecutionModule, IExecutor, ERC7579FallbackBase {

    address public constant ENTRY_POINT_V07_ADDRESS = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    address private immutable THIS_ADDRESS;

    using ComposableExecutionLib for InputParam[];
    using ComposableExecutionLib for OutputParam[];

    error OnlyEntryPointOrAccount();
    error ZeroAddressNotAllowed();
    error FailedToReturnMsgValue();
    error DelegateCallOnly();

    /// @notice Mapping of smart account addresses to the EP address
    mapping(address => address) private entryPoints;

    constructor() {
        THIS_ADDRESS = address(this);
    }

    /**
     * @notice Executes a composable transaction with dynamic parameter composition and return value handling
     * @dev To be used via fallback() from the account
     * @dev As per ERC-7579 account MUST append original msg.sender address to the calldata in a way specified by ERC-2771
     * @dev Returns the msg.value back to the sender (account) if any. This is done because in most cases the SA.fallback
     * forwards value to this module. This allows SA receiving value along with the composable execution call processed via fallback.
     */
    function executeComposable(ComposableExecution[] calldata executions) external payable {
        // access control
        address sender = _msgSender();
        // in most cases, only first condition (against constant) will be checked
        // so no extra sloads
        require(sender == ENTRY_POINT_V07_ADDRESS || 
                sender == entryPoints[msg.sender] || 
                sender == msg.sender, OnlyEntryPointOrAccount());
        _returnMsgValue();
        _executeComposable(executions, msg.sender, _executeExecutionCall);
    }

    /// @notice It doesn't require access control as it is expected to be called by the account itself via .execute()
    /// @dev !!! Attention !!! This function should NEVER be installed to be used via fallback() as it doesn't implement access control
    /// thus it will be callable by any address account.executeComposableCall => fallback() => this.executeComposableCall
    function executeComposableCall(ComposableExecution[] calldata executions) external { 
        _executeComposable(executions, msg.sender, _executeExecutionCall);
    }

    /// @notice It doesn't require access control as it is expected to be called by the account itself via .execute(mode = delegatecall)
    function executeComposableDelegateCall(ComposableExecution[] calldata executions) external {
        require(THIS_ADDRESS != address(this), DelegateCallOnly());
        _executeComposable(executions, address(this), _executeExecutionDelegatecall);
    }

    /// @dev internal function to execute the composable execution flow
    /// @param executions - the composable executions to execute
    /// @param account - the account to execute the composable executions on
    /// @param executeExecutionFunction - the function to execute the composable executions
    function _executeComposable(
        ComposableExecution[] calldata executions,
        address account,
        function(ComposableExecution calldata execution, bytes memory composedCalldata) internal returns(bytes[] memory) executeExecutionFunction
    ) internal {
        // we can not use erc-7579 batch mode here because we may need to compose
        // the next call in the batch based on the execution result of the previous call
        uint256 length = executions.length;
        for (uint256 i; i < length; i++) {
            ComposableExecution calldata execution = executions[i];
            bytes memory composedCalldata = execution.inputParams.processInputs(execution.functionSig);
            bytes[] memory returnData; 
            if (execution.to != address(0)) {
                returnData = executeExecutionFunction(execution, composedCalldata);
            } else {
                returnData = new bytes[](1);
                returnData[0] = "";
            }
            execution.outputParams.processOutputs(returnData[0], account);
        }
    }

    /// @dev function to be used as an argument for _executeComposable in case of regular call
    function _executeExecutionCall(ComposableExecution calldata execution, bytes memory composedCalldata) internal returns (bytes[] memory) {
        return IERC7579Account(msg.sender).executeFromExecutor({
                    mode: ModeLib.encodeSimpleSingle(),
                    executionCalldata: ExecutionLib.encodeSingle(execution.to, execution.value, composedCalldata)
                });
    }

    /// @dev function to be used as an argument for _executeComposable in case of delegatecall
    function _executeExecutionDelegatecall(ComposableExecution calldata execution, bytes memory composedCalldata) internal returns (bytes[] memory returnData) {
        returnData = new bytes[](1);
        returnData[0] = _execute(execution.to, execution.value, composedCalldata);
    }

    /// @dev sets the entry point for the account
    function setEntryPoint(address _entryPoint) external {
        require(_entryPoint != address(0), ZeroAddressNotAllowed());
        entryPoints[msg.sender] = _entryPoint;
    }
        
    /// @dev returns the entry point address
    function getEntryPoint(address account) external view returns (address) {
        return entryPoints[account] == address(0) ? ENTRY_POINT_V07_ADDRESS : entryPoints[account];
    }

    /// @dev called when the module is installed
    /// @dev expected behavior: reverts if tried to initialize the module for the same account more than once
    /// inner require checks if some account just sends same data for both fallback and executor
    function onInstall(bytes calldata data) external override {
        if (data.length >= 20) {
            if (entryPoints[msg.sender] != address(0)) {
                require(entryPoints[msg.sender] == address(bytes20(data[0:20])), AlreadyInitialized(msg.sender));
                return;
            }
            entryPoints[msg.sender] = address(bytes20(data[0:20]));
        }
    }

    /// @dev returns true if the module is initialized for the given account
    function isInitialized(address account) external view returns (bool) {
        return entryPoints[account] != address(0);
    }

    /// @dev called when the module is uninstalled
    function onUninstall(bytes calldata data) external override {
        delete entryPoints[msg.sender];
    }

    /// @dev Reports that this module is an executor and a fallback module
    function isModuleType(uint256 moduleTypeId) external pure override returns (bool) {
        return moduleTypeId == TYPE_EXECUTOR || moduleTypeId == TYPE_FALLBACK;
    }

    /// @notice Executes a call to a target address with specified value and data.
    /// @notice calls to an EOA should be counted as successful.
    /// @param target The address to execute the call on.
    /// @param value The amount of wei to send with the call.
    /// @param callData The calldata to send.
    /// @return result The bytes returned from the execution, which contains the returned data from the target address.
    function _execute(address target, uint256 value, bytes memory callData) internal virtual returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            if iszero(call(gas(), target, value, add(callData, 0x20), mload(callData), codesize(), 0x00)) {
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

    // Returns the msg.value back to the sender (account)
    function _returnMsgValue() internal {
        if (msg.value > 0) {
            (bool success, ) = payable(msg.sender).call{value: msg.value}("");
            require(success, FailedToReturnMsgValue());
        }
    }
}

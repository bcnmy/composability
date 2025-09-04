// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "test/ComposabilityBase.t.sol";
import {ComposableExecutionModule} from "contracts/ComposableExecutionModule.sol";
import {IComposableExecution} from "contracts/interfaces/IComposableExecution.sol";
import "contracts/ComposableExecutionLib.sol";
import "contracts/types/ComposabilityDataTypes.sol";

contract ComposableExecutionTestConstraintsAndReverts is ComposabilityTestBase {

    function setUp() public override {
        super.setUp();
    }

    function test_inputs_With_Gte_Constraints() public {
        _inputParamUsingGteConstraints(address(mockAccount), address(mockAccount));     
        _inputParamUsingGteConstraints(address(mockAccountFallback), address(composabilityHandler));
        _inputParamUsingGteConstraints(address(mockAccountCaller), address(composabilityHandler));
        _inputParamUsingGteConstraints(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_inputs_With_Lte_Constraints() public {
        _inputParamUsingLteConstraints(address(mockAccount), address(mockAccount));
        _inputParamUsingLteConstraints(address(mockAccountFallback), address(composabilityHandler));
        _inputParamUsingLteConstraints(address(mockAccountCaller), address(composabilityHandler));
        _inputParamUsingLteConstraints(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_inputs_With_In_Constraints() public {
        _inputParamUsingInConstraints(address(mockAccount), address(mockAccount));
        _inputParamUsingInConstraints(address(mockAccountFallback), address(composabilityHandler));
        _inputParamUsingInConstraints(address(mockAccountCaller), address(composabilityHandler));
        _inputParamUsingInConstraints(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_inputs_With_Eq_Constraints() public {
        _inputParamUsingEqConstraints(address(mockAccount), address(mockAccount));
        _inputParamUsingEqConstraints(address(mockAccountFallback), address(composabilityHandler));
        _inputParamUsingEqConstraints(address(mockAccountCaller), address(composabilityHandler));
        _inputParamUsingEqConstraints(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }  

    function test_read_From_Storage_Reverts_if_the_expected_slot_is_not_initialized() public {
        _read_From_Storage_Reverts_if_the_expected_slot_is_not_initialized(address(mockAccountFallback), address(composabilityHandler));        
        _read_From_Storage_Reverts_if_the_expected_slot_is_not_initialized(address(mockAccount), address(mockAccount));
        _read_From_Storage_Reverts_if_the_expected_slot_is_not_initialized(address(mockAccountCaller), address(composabilityHandler));
        _read_From_Storage_Reverts_if_the_expected_slot_is_not_initialized(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }
    
    // if the account does not revert on unsuccessful execution,
    // the revert reason is saved in the storage
    function test_save_Revert_Reason_in_Storage() public {
        _save_Revert_Reason_in_Storage(address(mockAccountNonRevert), address(mockAccountNonRevert));
    }
    
    // =================================================================================
    // ================================ TEST SCENARIOS ================================
    // =================================================================================

    function _inputParamUsingGteConstraints(address account, address caller) internal {
        Constraint[] memory constraints = new Constraint[](1);
        constraints[0] = Constraint({
            constraintType: ConstraintType.GTE,
            referenceData: abi.encode(bytes32(uint256(43)))
        });

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        // Prepare invalid input param - call should revert
        InputParam[] memory invalidInputParams = new InputParam[](3);
        invalidInputParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(42),
            constraints: constraints
        });
        invalidInputParams[1] = _createRawTargetInputParam(address(0));
        invalidInputParams[2] = _createRawValueInputParam(0);

        // Prepare valid input param - call should succeed
        InputParam[] memory validInputParams = new InputParam[](3);
        validInputParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(43),
            constraints: constraints
        });
        validInputParams[1] = _createRawTargetInputParam(address(0));
        validInputParams[2] = _createRawValueInputParam(0);

        OutputParam[] memory outputParams = new OutputParam[](0);

        // Call empty function and it should revert because dynamic param value doesnt meet constraints
        ComposableExecution[] memory failingExecutions = new ComposableExecution[](1);
        failingExecutions[0] = ComposableExecution({
            functionSig: "", // no calldata encoded
            inputParams: invalidInputParams, // use constrainted input parameter that's going to fail
            outputParams: outputParams
        });
        bytes memory expectedRevertData; 
        if (address(account) == address(mockAccountFallback)) {
            expectedRevertData = abi.encodeWithSelector(MockAccountFallback.FallbackFailed.selector, abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.GTE));
        } else {
            expectedRevertData = abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.GTE);
        }
        vm.expectRevert(expectedRevertData);
        IComposableExecution(address(account)).executeComposable(failingExecutions);

        // Call empty function and it should NOT revert because dynamic param value meets constraints
        ComposableExecution[] memory validExecutions = new ComposableExecution[](1);
        validExecutions[0] = ComposableExecution({
            functionSig: "", // no calldata encoded
            inputParams: validInputParams, // use valid input params
            outputParams: outputParams
        });
        IComposableExecution(address(account)).executeComposable(validExecutions);
    }

    function _inputParamUsingLteConstraints(address account, address caller) internal {
        Constraint[] memory constraints = new Constraint[](1);
        constraints[0] = Constraint({
            constraintType: ConstraintType.LTE,
            referenceData: abi.encode(bytes32(uint256(41)))
        });
        
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        // Prepare invalid input param - call should revert
        InputParam[] memory invalidInputParams = new InputParam[](3);
        invalidInputParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(42),
            //constraints: abi.encodePacked(ConstraintType.LTE, bytes32(uint256(41))) // value must be <= 41 but 42 provided
            constraints: constraints
        });
        invalidInputParams[1] = _createRawTargetInputParam(address(0));
        invalidInputParams[2] = _createRawValueInputParam(0);

        // Prepare valid input param - call should succeed
        InputParam[] memory validInputParams = new InputParam[](3);
        validInputParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(41),
            //constraints: abi.encodePacked(ConstraintType.LTE, bytes32(uint256(41))) // value must be <= 41
            constraints: constraints
        });
        validInputParams[1] = _createRawTargetInputParam(address(0));
        validInputParams[2] = _createRawValueInputParam(0);

        OutputParam[] memory outputParams = new OutputParam[](0);

        // Call empty function and it should revert because dynamic param value doesnt meet constraints
        ComposableExecution[] memory failingExecutions = new ComposableExecution[](1);
        failingExecutions[0] = ComposableExecution({
            functionSig: "", // no calldata encoded
            inputParams: invalidInputParams, // use constrainted input parameter that's going to fail
            outputParams: outputParams
        });
        bytes memory expectedRevertReason; 
        if (address(account) == address(mockAccountFallback)) {
            expectedRevertReason = abi.encodeWithSelector(MockAccountFallback.FallbackFailed.selector, abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.LTE));
        } else {
            expectedRevertReason = abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.LTE);
        }
        vm.expectRevert(expectedRevertReason);
        IComposableExecution(address(account)).executeComposable(failingExecutions);

        // Call empty function and it should NOT revert because dynamic param value meets constraints
        ComposableExecution[] memory validExecutions = new ComposableExecution[](1);
        validExecutions[0] = ComposableExecution({
            functionSig: "", // no calldata encoded
            inputParams: validInputParams, // use valid input params
            outputParams: outputParams
        });
        IComposableExecution(address(account)).executeComposable(validExecutions);
    }

    function _inputParamUsingInConstraints(address account, address caller) internal {
        Constraint[] memory constraints = new Constraint[](1);
        constraints[0] = Constraint({
            constraintType: ConstraintType.IN,
            referenceData: abi.encode(bytes32(uint256(41)), bytes32(uint256(43)))
        });

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        // Prepare invalid input param - call should revert (param value below lowerBound)
        InputParam[] memory invalidInputParamsA = new InputParam[](3);
        invalidInputParamsA[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(40),
            //constraints: abi.encodePacked(ConstraintType.IN, abi.encode(bytes32(uint256(41)), bytes32(uint256(43)))) // value must be between 41 & 43
            constraints: constraints
        });
        invalidInputParamsA[1] = _createRawTargetInputParam(address(0));
        invalidInputParamsA[2] = _createRawValueInputParam(0);

        // Prepare invalid input param - call should revert (param value above upperBound)
        InputParam[] memory invalidInputParamsB = new InputParam[](3);
        invalidInputParamsB[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(44),
            //constraints: abi.encodePacked(ConstraintType.IN, abi.encode(bytes32(uint256(41)), bytes32(uint256(43)))) // value must be between 41 & 43
            constraints: constraints
        });
        invalidInputParamsB[1] = _createRawTargetInputParam(address(0));
        invalidInputParamsB[2] = _createRawValueInputParam(0);

        // Prepare valid input param - call should succeed (param value in bounds)
        InputParam[] memory validInputParams = new InputParam[](3);
        validInputParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(42),
            //constraints: abi.encodePacked(ConstraintType.IN, abi.encode(bytes32(uint256(41)), bytes32(uint256(43)))) // value must be between 41 & 43
            constraints: constraints
        });
        validInputParams[1] = _createRawTargetInputParam(address(0));
        validInputParams[2] = _createRawValueInputParam(0);

        OutputParam[] memory outputParams = new OutputParam[](0);

        // Call empty function and it should revert because dynamic param value doesnt meet constraints (value below lower bound)
        ComposableExecution[] memory failingExecutionsA = new ComposableExecution[](1);
        failingExecutionsA[0] = ComposableExecution({
            functionSig: "", // no calldata encoded
            inputParams: invalidInputParamsA, // use constrainted input parameter that's going to fail
            outputParams: outputParams
        });
        bytes memory expectedRevertReason; 
        if (address(account) == address(mockAccountFallback)) {
            expectedRevertReason = abi.encodeWithSelector(MockAccountFallback.FallbackFailed.selector, abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.IN));
        } else {
            expectedRevertReason = abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.IN);
        }
        vm.expectRevert(expectedRevertReason);
        IComposableExecution(address(account)).executeComposable(failingExecutionsA);

        // Call empty function and it should revert because dynamic param value doesnt meet constraints (value below lower bound)
        ComposableExecution[] memory failingExecutionsB = new ComposableExecution[](1);
        failingExecutionsB[0] = ComposableExecution({
            functionSig: "", // no calldata encoded
            inputParams: invalidInputParamsB, // use constrainted input parameter that's going to fail
            outputParams: outputParams
        });
        
        if (address(account) == address(mockAccountFallback)) {
            expectedRevertReason = abi.encodeWithSelector(MockAccountFallback.FallbackFailed.selector, abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.IN));
        } else {
            expectedRevertReason = abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.IN);
        }
        vm.expectRevert(expectedRevertReason);
        IComposableExecution(address(account)).executeComposable(failingExecutionsB);

        // Call empty function and it should NOT revert because dynamic param value meets constraints
        ComposableExecution[] memory validExecutions = new ComposableExecution[](1);
        validExecutions[0] = ComposableExecution({
            functionSig: "", // no calldata encoded
            inputParams: validInputParams, // use valid input params
            outputParams: outputParams
        });
        IComposableExecution(address(account)).executeComposable(validExecutions);
    }

    function _inputParamUsingEqConstraints(address account, address caller) internal {
        Constraint[] memory constraints = new Constraint[](1);
        constraints[0] = Constraint({
            constraintType: ConstraintType.EQ,
            referenceData: abi.encode(bytes32(uint256(42)))
        });

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        // Prepare invalid input param - call should revert
        InputParam[] memory invalidInputParams = new InputParam[](3);
        invalidInputParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(43),
            //constraints: abi.encodePacked(ConstraintType.EQ, bytes32(uint256(42))) // value must be exactly 42
            constraints: constraints
        });
        invalidInputParams[1] = _createRawTargetInputParam(address(0));
        invalidInputParams[2] = _createRawValueInputParam(0);   

        // Prepare valid input param - call should succeed
        InputParam[] memory validInputParams = new InputParam[](3);
        validInputParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(42),
            //constraints: abi.encodePacked(ConstraintType.EQ, bytes32(uint256(42))) // value must be exactly 42
            constraints: constraints
        });
        validInputParams[1] = _createRawTargetInputParam(address(0));
        validInputParams[2] = _createRawValueInputParam(0);

        OutputParam[] memory outputParams = new OutputParam[](0);

        // Call empty function and it should revert because dynamic param value doesnt meet constraints
        ComposableExecution[] memory failingExecutions = new ComposableExecution[](1);
        failingExecutions[0] = ComposableExecution({
            functionSig: "", // no calldata encoded
            inputParams: invalidInputParams, // use constrainted input parameter that's going to fail
            outputParams: outputParams
        });
        bytes memory expectedRevertReason; 
        if (address(account) == address(mockAccountFallback)) {
            expectedRevertReason = abi.encodeWithSelector(MockAccountFallback.FallbackFailed.selector, abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.EQ));
        } else {
            expectedRevertReason = abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.EQ);
        }
        vm.expectRevert(expectedRevertReason);
        IComposableExecution(address(account)).executeComposable(failingExecutions);

        // Call empty function and it should NOT revert because dynamic param value meets constraints
        ComposableExecution[] memory validExecutions = new ComposableExecution[](1);
        validExecutions[0] = ComposableExecution({
            functionSig: "", // no calldata encoded
            inputParams: validInputParams, // use valid input params
            outputParams: outputParams
        });
        IComposableExecution(address(account)).executeComposable(validExecutions);
    }

    // It can happen when the previous call, that creates the output params, fail. 
    // In this case, the composable execution should revert when reading this from storage
    function _read_From_Storage_Reverts_if_the_expected_slot_is_not_initialized(address account, address caller) internal {        
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        bytes32 namespace = storageContract.getNamespace(address(account), address(caller));

        assertFalse(storageContract.isSlotInitialized(namespace, SLOT_A), "Slot should not be initialized");

        InputParam[] memory inputParams = new InputParam[](3);
        inputParams[0] = _createRawTargetInputParam(address(dummyContract));
        inputParams[1] = _createRawValueInputParam(0);
        inputParams[2] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.STATIC_CALL,
            paramData: abi.encode(storageContract, abi.encodeCall(Storage.readStorage, (namespace, SLOT_A))),
            constraints: emptyConstraints
        });

        OutputParam[] memory outputParams = new OutputParam[](0);

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.B.selector,
            inputParams: inputParams,
            outputParams: outputParams
        });

        bytes memory expectedRevertReason; 
        if (address(account) == address(mockAccountFallback)) {
            expectedRevertReason = abi.encodeWithSelector(MockAccountFallback.FallbackFailed.selector, abi.encodePacked(ComposableExecutionLib.ComposableExecutionFailed.selector));
        } else {
            expectedRevertReason = abi.encodePacked(ComposableExecutionLib.ComposableExecutionFailed.selector);
        }
        vm.expectRevert(expectedRevertReason);
        IComposableExecution(address(account)).executeComposable(executions);
        vm.stopPrank();
    }

    // use some account that does not revert when one of the execution fails
    // and saves the revert reason in the storage
    function _save_Revert_Reason_in_Storage(address account, address caller) internal {
        uint256 someStaticValue = 2517;

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        InputParam[] memory inputParamsExecA = new InputParam[](3);
        inputParamsExecA[0] = _createRawTargetInputParam(address(dummyContract));
        inputParamsExecA[1] = _createRawValueInputParam(0);
        inputParamsExecA[2] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(someStaticValue),
            constraints: emptyConstraints
        });

        OutputParam[] memory outputParamsExecA = new OutputParam[](1);
        outputParamsExecA[0] = OutputParam({
            fetcherType: OutputParamFetcherType.EXEC_RESULT,
            paramData: abi.encode(
                1,
                address(storageContract),
                SLOT_B
            )
        });

        ComposableExecution[] memory executionsA = new ComposableExecution[](1);
        executionsA[0] = ComposableExecution({
            functionSig: DummyContract.revertWithReason.selector,
            inputParams: inputParamsExecA,
            outputParams: outputParamsExecA
        });

        IComposableExecution(address(account)).executeComposable(executionsA);

        bytes32 namespace = storageContract.getNamespace(address(account), address(caller));
        bytes32 SLOT_B_0 = keccak256(abi.encodePacked(SLOT_B, uint256(0)));
        bytes32 storedValue0 = storageContract.readStorage(namespace, SLOT_B_0);
        
        bytes32 expectedValue = bytes32(DummyRevert.selector);
        assertEq(storedValue0, expectedValue, "Value 0 not stored correctly in the composability storage");

        vm.stopPrank();
    }
}


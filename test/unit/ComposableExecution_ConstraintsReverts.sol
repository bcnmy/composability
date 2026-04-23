// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "test/ComposabilityBase.t.sol";
import { ComposableExecutionModule } from "contracts/ComposableExecutionModule.sol";
import { IComposableExecution } from "contracts/interfaces/IComposableExecution.sol";
import "contracts/ComposableExecutionLib.sol";
import "contracts/types/ComposabilityDataTypes.sol";

contract ComposableExecutionTestConstraintsAndReverts is ComposabilityTestBase {
    error FallbackFailed(bytes result);
    error InvalidParameterEncoding(string message);

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

    function test_Balance_Fetcher_Reverts_If_Used_For_TARGET_Param() public {
        _balance_Fetcher_Reverts_If_Used_For_TARGET_Param(address(mockAccountFallback), address(composabilityHandler));
        _balance_Fetcher_Reverts_If_Used_For_TARGET_Param(address(mockAccount), address(mockAccount));
        _balance_Fetcher_Reverts_If_Used_For_TARGET_Param(address(mockAccountCaller), address(composabilityHandler));
        _balance_Fetcher_Reverts_If_Used_For_TARGET_Param(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    // =================================================================================
    // ================================ TEST SCENARIOS ================================
    // =================================================================================

    function _inputParamUsingGteConstraints(address account, address caller) internal {
        Constraint[] memory constraints = new Constraint[](1);
        constraints[0] = Constraint({ constraintType: ConstraintType.GTE, referenceData: abi.encode(bytes32(uint256(43))) });

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        // Prepare invalid input param - call should revert
        InputParam[] memory invalidInputParams = new InputParam[](3);
        invalidInputParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(42), constraints: constraints
        });
        invalidInputParams[1] = _createRawTargetInputParam(address(0));
        invalidInputParams[2] = _createRawValueInputParam(0);

        // Prepare valid input param - call should succeed
        InputParam[] memory validInputParams = new InputParam[](3);
        validInputParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(43), constraints: constraints
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
            expectedRevertData = abi.encodeWithSelector(
                MockAccountFallback.FallbackFailed.selector, abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.GTE)
            );
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
        constraints[0] = Constraint({ constraintType: ConstraintType.LTE, referenceData: abi.encode(bytes32(uint256(41))) });

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
            expectedRevertReason = abi.encodeWithSelector(
                MockAccountFallback.FallbackFailed.selector, abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.LTE)
            );
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
        constraints[0] = Constraint({ constraintType: ConstraintType.IN, referenceData: abi.encode(bytes32(uint256(41)), bytes32(uint256(43))) });

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
            expectedRevertReason = abi.encodeWithSelector(
                MockAccountFallback.FallbackFailed.selector, abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.IN)
            );
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
            expectedRevertReason = abi.encodeWithSelector(
                MockAccountFallback.FallbackFailed.selector, abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.IN)
            );
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
        constraints[0] = Constraint({ constraintType: ConstraintType.EQ, referenceData: abi.encode(bytes32(uint256(42))) });

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        // Prepare invalid input param - call should revert
        InputParam[] memory invalidInputParams = new InputParam[](3);
        invalidInputParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(43), // value must be exactly 42
            constraints: constraints
        });
        invalidInputParams[1] = _createRawTargetInputParam(address(0));
        invalidInputParams[2] = _createRawValueInputParam(0);

        // Prepare valid input param - call should succeed
        InputParam[] memory validInputParams = new InputParam[](3);
        validInputParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(42), constraints: constraints
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
            expectedRevertReason = abi.encodeWithSelector(
                MockAccountFallback.FallbackFailed.selector, abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.EQ)
            );
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
        executions[0] = ComposableExecution({ functionSig: DummyContract.B.selector, inputParams: inputParams, outputParams: outputParams });

        bytes memory expectedRevertReason;
        if (address(account) == address(mockAccountFallback)) {
            expectedRevertReason = abi.encodeWithSelector(
                MockAccountFallback.FallbackFailed.selector, abi.encodePacked(ComposableExecutionLib.ComposableExecutionFailed.selector)
            );
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
        outputParamsExecA[0] = OutputParam({ fetcherType: OutputParamFetcherType.EXEC_RESULT, paramData: abi.encode(1, address(storageContract), SLOT_B) });

        ComposableExecution[] memory executionsA = new ComposableExecution[](1);
        executionsA[0] =
            ComposableExecution({ functionSig: DummyContract.revertWithReason.selector, inputParams: inputParamsExecA, outputParams: outputParamsExecA });

        IComposableExecution(address(account)).executeComposable(executionsA);

        bytes32 namespace = storageContract.getNamespace(address(account), address(caller));
        bytes32 SLOT_B_0 = keccak256(abi.encodePacked(SLOT_B, uint256(0)));
        bytes32 storedValue0 = storageContract.readStorage(namespace, SLOT_B_0);

        bytes32 expectedValue = bytes32(DummyRevert.selector);
        assertEq(storedValue0, expectedValue, "Value 0 not stored correctly in the composability storage");

        vm.stopPrank();
    }

    function _balance_Fetcher_Reverts_If_Used_For_TARGET_Param(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        InputParam[] memory inputParams = new InputParam[](2);

        inputParams[0] = _createRawValueInputParam(0);

        inputParams[1] = InputParam({
            paramType: InputParamType.TARGET,
            fetcherType: InputParamFetcherType.BALANCE,
            paramData: abi.encodePacked(address(0), address(0xa11ce)),
            constraints: emptyConstraints
        });

        OutputParam[] memory outputParams = new OutputParam[](0);

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({ functionSig: "", inputParams: inputParams, outputParams: outputParams });

        if (address(account) == address(mockAccountFallback)) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    MockAccountFallback.FallbackFailed.selector,
                    abi.encodeWithSelector(InvalidParameterEncoding.selector, "BALANCE fetcher type is not supported for TARGET param type")
                )
            );
        } else {
            vm.expectRevert(abi.encodeWithSelector(InvalidParameterEncoding.selector, "BALANCE fetcher type is not supported for TARGET param type"));
        }
        IComposableExecution(address(account)).executeComposable(executions);

        vm.stopPrank();
    }

    // =================================================================================
    // ========================= SIGNED CONSTRAINT TESTS ==============================
    // =================================================================================

    function test_inputs_With_GteSigned_Constraints() public {
        _inputParamUsingGteSignedConstraints(address(mockAccount), address(mockAccount));
        _inputParamUsingGteSignedConstraints(address(mockAccountFallback), address(composabilityHandler));
        _inputParamUsingGteSignedConstraints(address(mockAccountCaller), address(composabilityHandler));
        _inputParamUsingGteSignedConstraints(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_inputs_With_LteSigned_Constraints() public {
        _inputParamUsingLteSignedConstraints(address(mockAccount), address(mockAccount));
        _inputParamUsingLteSignedConstraints(address(mockAccountFallback), address(composabilityHandler));
        _inputParamUsingLteSignedConstraints(address(mockAccountCaller), address(composabilityHandler));
        _inputParamUsingLteSignedConstraints(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_inputs_With_GteSigned_StaticCall_Constraints() public {
        _inputParamUsingGteSignedConstraintsViaStaticCall(address(mockAccount), address(mockAccount));
        _inputParamUsingGteSignedConstraintsViaStaticCall(address(mockAccountFallback), address(composabilityHandler));
        _inputParamUsingGteSignedConstraintsViaStaticCall(address(mockAccountCaller), address(composabilityHandler));
        _inputParamUsingGteSignedConstraintsViaStaticCall(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_inputs_With_Or_Constraints() public {
        _inputParamUsingOrConstraints(address(mockAccount), address(mockAccount));
        _inputParamUsingOrConstraints(address(mockAccountFallback), address(composabilityHandler));
        _inputParamUsingOrConstraints(address(mockAccountCaller), address(composabilityHandler));
        _inputParamUsingOrConstraints(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_inputs_With_Or_Signed_Constraints() public {
        _inputParamUsingOrWithSignedConstraints(address(mockAccount), address(mockAccount));
        _inputParamUsingOrWithSignedConstraints(address(mockAccountFallback), address(composabilityHandler));
        _inputParamUsingOrWithSignedConstraints(address(mockAccountCaller), address(composabilityHandler));
        _inputParamUsingOrWithSignedConstraints(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_Nested_Or_Reverts_With_InvalidConstraintType() public {
        _nestedOrReverts(address(mockAccount), address(mockAccount));
        _nestedOrReverts(address(mockAccountFallback), address(composabilityHandler));
        _nestedOrReverts(address(mockAccountCaller), address(composabilityHandler));
        _nestedOrReverts(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    // -----------------------------------------------------------------------
    // GTE_SIGNED: checks that int256(-5) is the lower bound.
    // value = int256(-10) => fails (below bound)
    // value = int256(-5)  => passes (equal to bound)
    // value = int256(0)   => passes (positive is always above negative bound)
    // -----------------------------------------------------------------------
    function _inputParamUsingGteSignedConstraints(address account, address caller) internal {
        // Reference: value must be >= int256(-5)
        Constraint[] memory constraints = new Constraint[](1);
        constraints[0] = Constraint({ constraintType: ConstraintType.GTE_SIGNED, referenceData: abi.encode(int256(-5)) });

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        OutputParam[] memory outputParams = new OutputParam[](0);

        // int256(-10) < int256(-5) => should revert
        {
            InputParam[] memory invalidInputParams = new InputParam[](3);
            invalidInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(int256(-10)), constraints: constraints
            });
            invalidInputParams[1] = _createRawTargetInputParam(address(0));
            invalidInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory failingExecutions = new ComposableExecution[](1);
            failingExecutions[0] = ComposableExecution({ functionSig: "", inputParams: invalidInputParams, outputParams: outputParams });

            bytes memory expectedRevert;
            if (address(account) == address(mockAccountFallback)) {
                expectedRevert = abi.encodeWithSelector(
                    MockAccountFallback.FallbackFailed.selector,
                    abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.GTE_SIGNED)
                );
            } else {
                expectedRevert = abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.GTE_SIGNED);
            }
            vm.expectRevert(expectedRevert);
            IComposableExecution(address(account)).executeComposable(failingExecutions);
        }

        // Demonstrate why GTE_SIGNED is needed: int256(-1) is encoded as 0xffff...ff, which as
        // uint256 is type(uint256).max, so plain GTE incorrectly treats -1 as >= any positive value.
        // GTE_SIGNED correctly identifies -1 < 0 and rejects it.
        {
            Constraint[] memory unsignedConstraints = new Constraint[](1);
            // plain GTE: require value >= 0 (as raw bytes32)
            unsignedConstraints[0] = Constraint({ constraintType: ConstraintType.GTE, referenceData: abi.encode(bytes32(uint256(0))) });

            InputParam[] memory unsignedInputParams = new InputParam[](3);
            unsignedInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA,
                fetcherType: InputParamFetcherType.RAW_BYTES,
                paramData: abi.encode(int256(-1)), // -1 as bytes32 = 0xffff...ff > 0 (unsigned)
                constraints: unsignedConstraints
            });
            unsignedInputParams[1] = _createRawTargetInputParam(address(0));
            unsignedInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory unsignedExecutions = new ComposableExecution[](1);
            unsignedExecutions[0] = ComposableExecution({ functionSig: "", inputParams: unsignedInputParams, outputParams: outputParams });

            // Unsigned GTE passes (wrongly treats -1 as >= 0 because bytes32(-1) is max uint256)
            IComposableExecution(address(account)).executeComposable(unsignedExecutions);
        }

        // Verify GTE_SIGNED rejects -1 >= 0 correctly
        {
            Constraint[] memory signedZeroConstraints = new Constraint[](1);
            signedZeroConstraints[0] = Constraint({ constraintType: ConstraintType.GTE_SIGNED, referenceData: abi.encode(int256(0)) });

            InputParam[] memory signedZeroInputParams = new InputParam[](3);
            signedZeroInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA,
                fetcherType: InputParamFetcherType.RAW_BYTES,
                paramData: abi.encode(int256(-1)),
                constraints: signedZeroConstraints
            });
            signedZeroInputParams[1] = _createRawTargetInputParam(address(0));
            signedZeroInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory signedZeroExecutions = new ComposableExecution[](1);
            signedZeroExecutions[0] = ComposableExecution({ functionSig: "", inputParams: signedZeroInputParams, outputParams: outputParams });

            bytes memory expectedRevert;
            if (address(account) == address(mockAccountFallback)) {
                expectedRevert = abi.encodeWithSelector(
                    MockAccountFallback.FallbackFailed.selector,
                    abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.GTE_SIGNED)
                );
            } else {
                expectedRevert = abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.GTE_SIGNED);
            }
            vm.expectRevert(expectedRevert);
            IComposableExecution(address(account)).executeComposable(signedZeroExecutions);
        }

        // int256(-5) >= int256(-5) => passes
        {
            InputParam[] memory validInputParams = new InputParam[](3);
            validInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(int256(-5)), constraints: constraints
            });
            validInputParams[1] = _createRawTargetInputParam(address(0));
            validInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory validExecutions = new ComposableExecution[](1);
            validExecutions[0] = ComposableExecution({ functionSig: "", inputParams: validInputParams, outputParams: outputParams });
            IComposableExecution(address(account)).executeComposable(validExecutions);
        }

        // int256(0) >= int256(-5) => passes (positive is always above negative)
        {
            InputParam[] memory positiveInputParams = new InputParam[](3);
            positiveInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(int256(0)), constraints: constraints
            });
            positiveInputParams[1] = _createRawTargetInputParam(address(0));
            positiveInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory positiveExecutions = new ComposableExecution[](1);
            positiveExecutions[0] = ComposableExecution({ functionSig: "", inputParams: positiveInputParams, outputParams: outputParams });
            IComposableExecution(address(account)).executeComposable(positiveExecutions);
        }

        vm.stopPrank();
    }

    // -----------------------------------------------------------------------
    // LTE_SIGNED: checks that int256(-5) is the upper bound.
    // value = int256(-3)  => fails (above bound)
    // value = int256(-5)  => passes (equal to bound)
    // value = int256(-10) => passes (below bound)
    // value = int256(1)   => fails (positive above negative bound)
    // -----------------------------------------------------------------------
    function _inputParamUsingLteSignedConstraints(address account, address caller) internal {
        // Reference: value must be <= int256(-5)
        Constraint[] memory constraints = new Constraint[](1);
        constraints[0] = Constraint({ constraintType: ConstraintType.LTE_SIGNED, referenceData: abi.encode(int256(-5)) });

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        OutputParam[] memory outputParams = new OutputParam[](0);

        // int256(-3) > int256(-5) => should revert
        {
            InputParam[] memory invalidInputParams = new InputParam[](3);
            invalidInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(int256(-3)), constraints: constraints
            });
            invalidInputParams[1] = _createRawTargetInputParam(address(0));
            invalidInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory failingExecutions = new ComposableExecution[](1);
            failingExecutions[0] = ComposableExecution({ functionSig: "", inputParams: invalidInputParams, outputParams: outputParams });

            bytes memory expectedRevert;
            if (address(account) == address(mockAccountFallback)) {
                expectedRevert = abi.encodeWithSelector(
                    MockAccountFallback.FallbackFailed.selector,
                    abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.LTE_SIGNED)
                );
            } else {
                expectedRevert = abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.LTE_SIGNED);
            }
            vm.expectRevert(expectedRevert);
            IComposableExecution(address(account)).executeComposable(failingExecutions);
        }

        // int256(1) > int256(-5) => should revert (positive is always above negative bound)
        {
            InputParam[] memory positiveInvalidInputParams = new InputParam[](3);
            positiveInvalidInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(int256(1)), constraints: constraints
            });
            positiveInvalidInputParams[1] = _createRawTargetInputParam(address(0));
            positiveInvalidInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory positiveFailingExecutions = new ComposableExecution[](1);
            positiveFailingExecutions[0] = ComposableExecution({ functionSig: "", inputParams: positiveInvalidInputParams, outputParams: outputParams });

            bytes memory expectedRevert;
            if (address(account) == address(mockAccountFallback)) {
                expectedRevert = abi.encodeWithSelector(
                    MockAccountFallback.FallbackFailed.selector,
                    abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.LTE_SIGNED)
                );
            } else {
                expectedRevert = abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.LTE_SIGNED);
            }
            vm.expectRevert(expectedRevert);
            IComposableExecution(address(account)).executeComposable(positiveFailingExecutions);
        }

        // int256(-5) <= int256(-5) => passes
        {
            InputParam[] memory validInputParams = new InputParam[](3);
            validInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(int256(-5)), constraints: constraints
            });
            validInputParams[1] = _createRawTargetInputParam(address(0));
            validInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory validExecutions = new ComposableExecution[](1);
            validExecutions[0] = ComposableExecution({ functionSig: "", inputParams: validInputParams, outputParams: outputParams });
            IComposableExecution(address(account)).executeComposable(validExecutions);
        }

        // int256(-10) <= int256(-5) => passes
        {
            InputParam[] memory belowInputParams = new InputParam[](3);
            belowInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(int256(-10)), constraints: constraints
            });
            belowInputParams[1] = _createRawTargetInputParam(address(0));
            belowInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory belowExecutions = new ComposableExecution[](1);
            belowExecutions[0] = ComposableExecution({ functionSig: "", inputParams: belowInputParams, outputParams: outputParams });
            IComposableExecution(address(account)).executeComposable(belowExecutions);
        }

        vm.stopPrank();
    }

    // -----------------------------------------------------------------------
    // GTE_SIGNED via STATIC_CALL: the return value comes from dummyContract.getSignedValue()
    // which returns int256(-42). Constraint: value must be >= int256(-50) (passes)
    //                             and       value must be >= int256(-10) (fails)
    // -----------------------------------------------------------------------
    function _inputParamUsingGteSignedConstraintsViaStaticCall(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        OutputParam[] memory outputParams = new OutputParam[](0);

        // getSignedValue() returns -42; require >= -50 => passes
        {
            Constraint[] memory passingConstraints = new Constraint[](1);
            passingConstraints[0] = Constraint({ constraintType: ConstraintType.GTE_SIGNED, referenceData: abi.encode(int256(-50)) });

            InputParam[] memory validInputParams = new InputParam[](3);
            validInputParams[0] = _createRawTargetInputParam(address(0));
            validInputParams[1] = _createRawValueInputParam(0);
            validInputParams[2] = InputParam({
                paramType: InputParamType.CALL_DATA,
                fetcherType: InputParamFetcherType.STATIC_CALL,
                paramData: abi.encode(address(dummyContract), abi.encodeWithSelector(DummyContract.getSignedValue.selector)),
                constraints: passingConstraints
            });

            ComposableExecution[] memory validExecutions = new ComposableExecution[](1);
            validExecutions[0] = ComposableExecution({ functionSig: "", inputParams: validInputParams, outputParams: outputParams });
            IComposableExecution(address(account)).executeComposable(validExecutions);
        }

        // getSignedValue() returns -42; require >= -10 => fails (-42 < -10)
        {
            Constraint[] memory failingConstraints = new Constraint[](1);
            failingConstraints[0] = Constraint({ constraintType: ConstraintType.GTE_SIGNED, referenceData: abi.encode(int256(-10)) });

            InputParam[] memory invalidInputParams = new InputParam[](3);
            invalidInputParams[0] = _createRawTargetInputParam(address(0));
            invalidInputParams[1] = _createRawValueInputParam(0);
            invalidInputParams[2] = InputParam({
                paramType: InputParamType.CALL_DATA,
                fetcherType: InputParamFetcherType.STATIC_CALL,
                paramData: abi.encode(address(dummyContract), abi.encodeWithSelector(DummyContract.getSignedValue.selector)),
                constraints: failingConstraints
            });

            ComposableExecution[] memory failingExecutions = new ComposableExecution[](1);
            failingExecutions[0] = ComposableExecution({ functionSig: "", inputParams: invalidInputParams, outputParams: outputParams });

            bytes memory expectedRevert;
            if (address(account) == address(mockAccountFallback)) {
                expectedRevert = abi.encodeWithSelector(
                    MockAccountFallback.FallbackFailed.selector,
                    abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.GTE_SIGNED)
                );
            } else {
                expectedRevert = abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.GTE_SIGNED);
            }
            vm.expectRevert(expectedRevert);
            IComposableExecution(address(account)).executeComposable(failingExecutions);
        }

        vm.stopPrank();
    }

    // -----------------------------------------------------------------------
    // OR constraint: value must be == 0 OR >= 100 (i.e. "free or large enough")
    // value = 0   => passes (EQ branch)
    // value = 150 => passes (GTE branch)
    // value = 50  => fails (neither branch)
    // -----------------------------------------------------------------------
    function _inputParamUsingOrConstraints(address account, address caller) internal {
        Constraint[] memory subConstraints = new Constraint[](2);
        subConstraints[0] = Constraint({ constraintType: ConstraintType.EQ, referenceData: abi.encode(bytes32(uint256(0))) });
        subConstraints[1] = Constraint({ constraintType: ConstraintType.GTE, referenceData: abi.encode(bytes32(uint256(100))) });

        Constraint[] memory constraints = new Constraint[](1);
        constraints[0] = Constraint({ constraintType: ConstraintType.OR, referenceData: abi.encode(subConstraints) });

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        OutputParam[] memory outputParams = new OutputParam[](0);

        // value = 50: neither EQ(0) nor GTE(100) => should revert
        {
            InputParam[] memory invalidInputParams = new InputParam[](3);
            invalidInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(uint256(50)), constraints: constraints
            });
            invalidInputParams[1] = _createRawTargetInputParam(address(0));
            invalidInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory failingExecutions = new ComposableExecution[](1);
            failingExecutions[0] = ComposableExecution({ functionSig: "", inputParams: invalidInputParams, outputParams: outputParams });

            bytes memory expectedRevert;
            if (address(account) == address(mockAccountFallback)) {
                expectedRevert = abi.encodeWithSelector(
                    MockAccountFallback.FallbackFailed.selector, abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.OR)
                );
            } else {
                expectedRevert = abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.OR);
            }
            vm.expectRevert(expectedRevert);
            IComposableExecution(address(account)).executeComposable(failingExecutions);
        }

        // value = 0: EQ(0) passes => OR passes
        {
            InputParam[] memory zeroInputParams = new InputParam[](3);
            zeroInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(uint256(0)), constraints: constraints
            });
            zeroInputParams[1] = _createRawTargetInputParam(address(0));
            zeroInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory zeroExecutions = new ComposableExecution[](1);
            zeroExecutions[0] = ComposableExecution({ functionSig: "", inputParams: zeroInputParams, outputParams: outputParams });
            IComposableExecution(address(account)).executeComposable(zeroExecutions);
        }

        // value = 150: GTE(100) passes => OR passes
        {
            InputParam[] memory largeInputParams = new InputParam[](3);
            largeInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(uint256(150)), constraints: constraints
            });
            largeInputParams[1] = _createRawTargetInputParam(address(0));
            largeInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory largeExecutions = new ComposableExecution[](1);
            largeExecutions[0] = ComposableExecution({ functionSig: "", inputParams: largeInputParams, outputParams: outputParams });
            IComposableExecution(address(account)).executeComposable(largeExecutions);
        }

        // value = 100: GTE(100) passes (boundary) => OR passes
        {
            InputParam[] memory boundaryInputParams = new InputParam[](3);
            boundaryInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(uint256(100)), constraints: constraints
            });
            boundaryInputParams[1] = _createRawTargetInputParam(address(0));
            boundaryInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory boundaryExecutions = new ComposableExecution[](1);
            boundaryExecutions[0] = ComposableExecution({ functionSig: "", inputParams: boundaryInputParams, outputParams: outputParams });
            IComposableExecution(address(account)).executeComposable(boundaryExecutions);
        }

        vm.stopPrank();
    }

    // -----------------------------------------------------------------------
    // OR with signed sub-constraints: value must be LTE_SIGNED(-100) OR GTE_SIGNED(0)
    // Useful for: "price delta must be at most -100 (big drop) or at least 0 (no loss)"
    // value = int256(-50)  => fails (between -100 and 0, neither branch)
    // value = int256(-100) => passes (LTE_SIGNED branch)
    // value = int256(-200) => passes (LTE_SIGNED branch, further below)
    // value = int256(0)    => passes (GTE_SIGNED branch)
    // value = int256(10)   => passes (GTE_SIGNED branch)
    // -----------------------------------------------------------------------
    function _inputParamUsingOrWithSignedConstraints(address account, address caller) internal {
        Constraint[] memory subConstraints = new Constraint[](2);
        subConstraints[0] = Constraint({ constraintType: ConstraintType.LTE_SIGNED, referenceData: abi.encode(int256(-100)) });
        subConstraints[1] = Constraint({ constraintType: ConstraintType.GTE_SIGNED, referenceData: abi.encode(int256(0)) });

        Constraint[] memory constraints = new Constraint[](1);
        constraints[0] = Constraint({ constraintType: ConstraintType.OR, referenceData: abi.encode(subConstraints) });

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        OutputParam[] memory outputParams = new OutputParam[](0);

        // value = int256(-50): -50 > -100 (LTE fails) and -50 < 0 (GTE fails) => OR fails
        {
            InputParam[] memory invalidInputParams = new InputParam[](3);
            invalidInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(int256(-50)), constraints: constraints
            });
            invalidInputParams[1] = _createRawTargetInputParam(address(0));
            invalidInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory failingExecutions = new ComposableExecution[](1);
            failingExecutions[0] = ComposableExecution({ functionSig: "", inputParams: invalidInputParams, outputParams: outputParams });

            bytes memory expectedRevert;
            if (address(account) == address(mockAccountFallback)) {
                expectedRevert = abi.encodeWithSelector(
                    MockAccountFallback.FallbackFailed.selector, abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.OR)
                );
            } else {
                expectedRevert = abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.OR);
            }
            vm.expectRevert(expectedRevert);
            IComposableExecution(address(account)).executeComposable(failingExecutions);
        }

        // value = int256(-100): LTE_SIGNED(-100) passes => OR passes
        {
            InputParam[] memory lteInputParams = new InputParam[](3);
            lteInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(int256(-100)), constraints: constraints
            });
            lteInputParams[1] = _createRawTargetInputParam(address(0));
            lteInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory lteExecutions = new ComposableExecution[](1);
            lteExecutions[0] = ComposableExecution({ functionSig: "", inputParams: lteInputParams, outputParams: outputParams });
            IComposableExecution(address(account)).executeComposable(lteExecutions);
        }

        // value = int256(-200): LTE_SIGNED(-100) passes => OR passes
        {
            InputParam[] memory deepNegInputParams = new InputParam[](3);
            deepNegInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(int256(-200)), constraints: constraints
            });
            deepNegInputParams[1] = _createRawTargetInputParam(address(0));
            deepNegInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory deepNegExecutions = new ComposableExecution[](1);
            deepNegExecutions[0] = ComposableExecution({ functionSig: "", inputParams: deepNegInputParams, outputParams: outputParams });
            IComposableExecution(address(account)).executeComposable(deepNegExecutions);
        }

        // value = int256(0): GTE_SIGNED(0) passes => OR passes
        {
            InputParam[] memory zeroInputParams = new InputParam[](3);
            zeroInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(int256(0)), constraints: constraints
            });
            zeroInputParams[1] = _createRawTargetInputParam(address(0));
            zeroInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory zeroExecutions = new ComposableExecution[](1);
            zeroExecutions[0] = ComposableExecution({ functionSig: "", inputParams: zeroInputParams, outputParams: outputParams });
            IComposableExecution(address(account)).executeComposable(zeroExecutions);
        }

        // value = int256(10): GTE_SIGNED(0) passes => OR passes
        {
            InputParam[] memory posInputParams = new InputParam[](3);
            posInputParams[0] = InputParam({
                paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(int256(10)), constraints: constraints
            });
            posInputParams[1] = _createRawTargetInputParam(address(0));
            posInputParams[2] = _createRawValueInputParam(0);

            ComposableExecution[] memory posExecutions = new ComposableExecution[](1);
            posExecutions[0] = ComposableExecution({ functionSig: "", inputParams: posInputParams, outputParams: outputParams });
            IComposableExecution(address(account)).executeComposable(posExecutions);
        }

        vm.stopPrank();
    }

    // -----------------------------------------------------------------------
    // Nested OR is intentionally rejected to keep the signed payload flat and
    // easy to display. An OR whose sub-array contains another OR must revert
    // with InvalidConstraintType when _checkConstraint encounters the inner OR.
    // -----------------------------------------------------------------------
    function _nestedOrReverts(address account, address caller) internal {
        // Inner OR with two leaf alternatives
        Constraint[] memory innerSubs = new Constraint[](2);
        innerSubs[0] = Constraint({ constraintType: ConstraintType.EQ, referenceData: abi.encode(bytes32(uint256(1))) });
        innerSubs[1] = Constraint({ constraintType: ConstraintType.EQ, referenceData: abi.encode(bytes32(uint256(2))) });

        // Outer OR whose second alternative is the inner OR (nesting)
        Constraint[] memory outerSubs = new Constraint[](2);
        outerSubs[0] = Constraint({ constraintType: ConstraintType.EQ, referenceData: abi.encode(bytes32(uint256(0))) });
        outerSubs[1] = Constraint({ constraintType: ConstraintType.OR, referenceData: abi.encode(innerSubs) });

        Constraint[] memory constraints = new Constraint[](1);
        constraints[0] = Constraint({ constraintType: ConstraintType.OR, referenceData: abi.encode(outerSubs) });

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        // value = 7: outer OR's first alternative (EQ(0)) fails for value=7, so it reaches the
        // nested inner OR, which triggers InvalidConstraintType inside _checkConstraint.
        InputParam[] memory inputParams = new InputParam[](3);
        inputParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA, fetcherType: InputParamFetcherType.RAW_BYTES, paramData: abi.encode(uint256(7)), constraints: constraints
        });
        inputParams[1] = _createRawTargetInputParam(address(0));
        inputParams[2] = _createRawValueInputParam(0);

        OutputParam[] memory outputParams = new OutputParam[](0);
        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({ functionSig: "", inputParams: inputParams, outputParams: outputParams });

        bytes memory expectedRevert;
        if (address(account) == address(mockAccountFallback)) {
            expectedRevert = abi.encodeWithSelector(
                MockAccountFallback.FallbackFailed.selector, abi.encodeWithSelector(ComposableExecutionLib.InvalidConstraintType.selector)
            );
        } else {
            expectedRevert = abi.encodeWithSelector(ComposableExecutionLib.InvalidConstraintType.selector);
        }
        vm.expectRevert(expectedRevert);
        IComposableExecution(address(account)).executeComposable(executions);

        vm.stopPrank();
    }
}

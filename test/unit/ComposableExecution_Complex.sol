// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "test/ComposabilityBase.t.sol";
import {ComposableExecutionModule} from "contracts/ComposableExecutionModule.sol";
import {IComposableExecution} from "contracts/interfaces/IComposableExecution.sol";
import "contracts/ComposableExecutionLib.sol";
import "contracts/types/ComposabilityDataTypes.sol";

contract ComposableExecutionTestComplexCases is ComposabilityTestBase {

    function setUp() public override {
        super.setUp();
    }

    function test_outputExecResultMultipleValues_Success() public {
        _outputExecResultMultipleValues(address(mockAccountFallback), address(composabilityHandler));
        _outputExecResultMultipleValues(address(mockAccount), address(mockAccount));
        _outputExecResultMultipleValues(address(mockAccountCaller), address(composabilityHandler));
        _outputExecResultMultipleValues(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_outputStaticCallMultipleValues_Success() public {
        _outputStaticCallMultipleValues(address(mockAccountFallback), address(composabilityHandler));
        _outputStaticCallMultipleValues(address(mockAccount), address(mockAccount));
        _outputStaticCallMultipleValues(address(mockAccountCaller), address(composabilityHandler));
        _outputStaticCallMultipleValues(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_inputStaticCallMultipleValues_Success() public {
        _inputStaticCallMultipleValues(address(mockAccountFallback), address(composabilityHandler));
        _inputStaticCallMultipleValues(address(mockAccount), address(mockAccount));
        _inputStaticCallMultipleValues(address(mockAccountCaller), address(composabilityHandler));
        _inputStaticCallMultipleValues(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_inputDynamicBytesArrayAsRawBytes_Success() public {
        _inputDynamicBytesArrayAsRawBytes(address(mockAccountFallback), address(composabilityHandler));
        _inputDynamicBytesArrayAsRawBytes(address(mockAccount), address(mockAccount));
        _inputDynamicBytesArrayAsRawBytes(address(mockAccountCaller), address(composabilityHandler));
        _inputDynamicBytesArrayAsRawBytes(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_structInjection_Success() public {
        _structInjection(address(mockAccountFallback), address(composabilityHandler));
        _structInjection(address(mockAccount), address(mockAccount));
        _structInjection(address(mockAccountCaller), address(composabilityHandler));
        _structInjection(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }
    
    // =================================================================================
    // ================================ TEST SCENARIOS ================================
    // =================================================================================

    function _outputExecResultMultipleValues(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        InputParam[] memory inputParams = new InputParam[](2);
        inputParams[0] = _createRawTargetInputParam(address(dummyContract));
        inputParams[1] = _createRawValueInputParam(0);
        
        OutputParam[] memory outputParams = new OutputParam[](1);
        outputParams[0] = OutputParam({
            fetcherType: OutputParamFetcherType.EXEC_RESULT,
            paramData: abi.encode(4, address(storageContract), SLOT_A)
        });

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.returnMultipleValues.selector,
            inputParams: inputParams,
            outputParams: outputParams
        });

        IComposableExecution(address(account)).executeComposable(executions);
        vm.stopPrank();

        bytes32 namespace = storageContract.getNamespace(address(account), address(caller));
        bytes32 SLOT_A_0 = keccak256(abi.encodePacked(SLOT_A, uint256(0)));
        bytes32 SLOT_A_1 = keccak256(abi.encodePacked(SLOT_A, uint256(1)));
        bytes32 SLOT_A_2 = keccak256(abi.encodePacked(SLOT_A, uint256(2)));
        bytes32 SLOT_A_3 = keccak256(abi.encodePacked(SLOT_A, uint256(3)));
        bytes32 storedValue0 = storageContract.readStorage(namespace, SLOT_A_0);
        bytes32 storedValue1 = storageContract.readStorage(namespace, SLOT_A_1);
        bytes32 storedValue2 = storageContract.readStorage(namespace, SLOT_A_2);
        bytes32 storedValue3 = storageContract.readStorage(namespace, SLOT_A_3);
        assertEq(uint256(storedValue0), 2517, "Value 0 not stored correctly in the composability storage");
        assertEq(address(uint160(uint256(storedValue1))), address(dummyContract), "Value 1 not stored correctly in the composability storage");
        assertEq(storedValue2, keccak256("DUMMY"), "Value 2 not stored correctly in the composability storage");
        assertEq(uint8(uint256(storedValue3)), 1, "Value 3 not stored correctly in the composability storage");
    }

    // test outputStaticCall with multiple return values
    function _outputStaticCallMultipleValues(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        InputParam[] memory inputParams = new InputParam[](2);
        inputParams[0] = _createRawTargetInputParam(address(dummyContract));
        inputParams[1] = _createRawValueInputParam(0);

        OutputParam[] memory outputParams = new OutputParam[](1);
        outputParams[0] = OutputParam({
            fetcherType: OutputParamFetcherType.STATIC_CALL,
            paramData: abi.encode(4, address(dummyContract), abi.encodeWithSelector(DummyContract.returnMultipleValues.selector), address(storageContract), SLOT_A)
        });

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.A.selector, // can be any function here in fact
            inputParams: inputParams,
            outputParams: outputParams
        });

        IComposableExecution(address(account)).executeComposable(executions);
        vm.stopPrank();

        bytes32 namespace = storageContract.getNamespace(address(account), address(caller));
        bytes32 SLOT_A_0 = keccak256(abi.encodePacked(SLOT_A, uint256(0)));
        bytes32 SLOT_A_1 = keccak256(abi.encodePacked(SLOT_A, uint256(1)));
        bytes32 SLOT_A_2 = keccak256(abi.encodePacked(SLOT_A, uint256(2)));
        bytes32 SLOT_A_3 = keccak256(abi.encodePacked(SLOT_A, uint256(3)));
        bytes32 storedValue0 = storageContract.readStorage(namespace, SLOT_A_0);
        bytes32 storedValue1 = storageContract.readStorage(namespace, SLOT_A_1);
        bytes32 storedValue2 = storageContract.readStorage(namespace, SLOT_A_2);
        bytes32 storedValue3 = storageContract.readStorage(namespace, SLOT_A_3);
        assertEq(uint256(storedValue0), 2517, "Value 0 not stored correctly in the composability storage");
        assertEq(address(uint160(uint256(storedValue1))), address(dummyContract), "Value 1 not stored correctly in the composability storage");
        assertEq(storedValue2, keccak256("DUMMY"), "Value 2 not stored correctly in the composability storage");
        assertEq(uint8(uint256(storedValue3)), 1, "Value 3 not stored correctly in the composability storage");
    }

    // test inputStaticCall with multiple return values
    function _inputStaticCallMultipleValues(address account, address caller) internal {
        Constraint[] memory constraints = new Constraint[](4);
        constraints[0] = Constraint({
            constraintType: ConstraintType.EQ,
            referenceData: abi.encode(bytes32(uint256(2517)))
        });
        constraints[1] = Constraint({
            constraintType: ConstraintType.EQ,
            referenceData: abi.encode(bytes32(uint256(uint160(address(dummyContract)))))
        });
        constraints[2] = Constraint({
            constraintType: ConstraintType.EQ,
            referenceData: abi.encode(bytes32(uint256(keccak256("DUMMY"))))
        });
        constraints[3] = Constraint({
            constraintType: ConstraintType.EQ,
            referenceData: abi.encode(bytes32(uint256(1)))
        });

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        InputParam[] memory inputParams = new InputParam[](3);
        inputParams[0] = _createRawTargetInputParam(address(dummyContract));
        inputParams[1] = _createRawValueInputParam(0);
        inputParams[2] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.STATIC_CALL,
            paramData: abi.encode(address(dummyContract), abi.encodeWithSelector(DummyContract.returnMultipleValues.selector)),
            constraints: constraints
        });

        OutputParam[] memory outputParams = new OutputParam[](0);

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.acceptMultipleValues.selector,
            inputParams: inputParams,
            outputParams: outputParams
        });

        vm.expectEmit(address(dummyContract));
        emit Uint256Emitted(2517);
        vm.expectEmit(address(dummyContract));
        emit AddressEmitted(address(dummyContract));
        vm.expectEmit(address(dummyContract));
        emit Bytes32Emitted(keccak256("DUMMY"));
        vm.expectEmit(address(dummyContract));
        emit BoolEmitted(true);

        IComposableExecution(address(account)).executeComposable(executions);
        vm.stopPrank();
    }

    function _inputDynamicBytesArrayAsRawBytes(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        uint256 someStaticValue = 2517;
        uint256 expectedUint256 = 2517*2;
        bytes memory expectedBytes = bytes("Hello, world!");
        address expectedAddress = address(0xa11cedecaf);

        // encode function call as per https://docs.soliditylang.org/en/develop/abi-spec.html 
        // function is : function acceptStaticAndDynamicValues(uint256 staticValue, bytes calldata dynamicValue, address addr)

        // static arg
        InputParam[] memory inputParams = new InputParam[](6);
        inputParams[0] = _createRawTargetInputParam(address(dummyContract));
        inputParams[1] = _createRawValueInputParam(0);
        inputParams[2] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.STATIC_CALL,
            paramData: abi.encode(address(dummyContract), abi.encodeWithSelector(DummyContract.B.selector, someStaticValue)),
            constraints: emptyConstraints
        });

        // dynamic arg => here only offset is pasted
        inputParams[3] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(uint256(0x60)),
            constraints: emptyConstraints
        });

        // static arg
        inputParams[4] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(expectedAddress),
            constraints: emptyConstraints
        });
        
        // the payload  of the dynamic arg
        inputParams[5] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encodePacked(expectedBytes.length, expectedBytes),
            constraints: emptyConstraints
        });

        // Prepare return value config for function B
        OutputParam[] memory outputParams = new OutputParam[](0);

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.acceptStaticAndDynamicValues.selector,
            inputParams: inputParams,
            outputParams: outputParams
        });

        vm.expectEmit(address(dummyContract));
        emit Uint256Emitted(expectedUint256);
        vm.expectEmit(address(dummyContract));
        emit AddressEmitted(expectedAddress);
        vm.expectEmit(address(dummyContract));
        emit BytesEmitted(expectedBytes);
        IComposableExecution(address(account)).executeComposable(executions);

        vm.stopPrank();
    }

    function _structInjection(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        uint256 someStaticValue = 2517;

        address tokenIn = address(0xa11ce70c3170);
        address tokenOut = address(0xb0b70c3170);
        uint256 amountOutMin = 999;
        uint256 deadline = block.timestamp + 1000;
        uint256 fee = 500;

        Constraint[] memory constraints = new Constraint[](1);
        constraints[0] = Constraint({
            constraintType: ConstraintType.LTE,
            referenceData: abi.encode(bytes32(uint256(10_000)))
        });

        // represent the encoded call to acceptStruct() 
        // as per abi encoding rules
        InputParam[] memory inputParams = new InputParam[](9);

        // TARGET and VALUE parameters
        inputParams[0] = _createRawTargetInputParam(address(dummyContract));
        inputParams[1] = _createRawValueInputParam(0);

        // static param
        inputParams[2] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(someStaticValue),
            constraints: emptyConstraints
        });

        // === start struct ==

        // tokenIn
        inputParams[3] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(tokenIn),
            constraints: emptyConstraints
        });

        // tokenOut
        inputParams[4] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(tokenOut),
            constraints: emptyConstraints
        });

        // amountIn
        inputParams[5] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.STATIC_CALL,
            paramData: abi.encode(address(dummyContract), abi.encodeWithSelector(DummyContract.B.selector, someStaticValue)),
            constraints: constraints
        });

        // amountOutMin
        inputParams[6] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(amountOutMin),
            constraints: emptyConstraints
        });


        // deadline
        inputParams[7] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(deadline),
            constraints: emptyConstraints
        });

        // fee
        inputParams[8] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(fee),
            constraints: emptyConstraints
        });

        // === end struct ==

        OutputParam[] memory outputParams = new OutputParam[](0);

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.acceptStruct.selector,
            inputParams: inputParams,
            outputParams: outputParams
        });

        vm.expectEmit(address(dummyContract));
        emit Uint256Emitted(someStaticValue); // someValue
        vm.expectEmit(address(dummyContract));
        emit Uint256Emitted(someStaticValue*2); //amountIn
        vm.expectEmit(address(dummyContract));
        emit Uint256Emitted(amountOutMin); //amountOutMin
        vm.expectEmit(address(dummyContract));
        emit Uint256Emitted(deadline);
        vm.expectEmit(address(dummyContract));
        emit Uint256Emitted(fee);
        vm.expectEmit(address(dummyContract));
        emit AddressEmitted(tokenIn);
        vm.expectEmit(address(dummyContract));
        emit AddressEmitted(tokenOut);
        IComposableExecution(address(account)).executeComposable(executions);

        vm.stopPrank();
    }
}


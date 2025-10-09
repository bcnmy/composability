// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "test/ComposabilityBase.t.sol";
import {ComposableExecutionModule} from "contracts/ComposableExecutionModule.sol";
import {IComposableExecution} from "contracts/interfaces/IComposableExecution.sol";
import "contracts/ComposableExecutionLib.sol";
import "contracts/types/ComposabilityDataTypes.sol";

contract ComposableExecutionTestSimpleCases is ComposabilityTestBase {

    function setUp() public override {
        super.setUp();
    }

    function test_inputStaticCall_OutputExecResult_Success() public {
        // via composability module
        _inputStaticCallOutputExecResult(address(mockAccountFallback), address(composabilityHandler));

        // via native executeComposable
        _inputStaticCallOutputExecResult(address(mockAccount), address(mockAccount));

        // via regular call
        _inputStaticCallOutputExecResult(address(mockAccountCaller),  address(composabilityHandler));

        // via delegatecall
        _inputStaticCallOutputExecResult(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_inputRawBytes_Success() public {
        _inputRawBytes(address(mockAccountFallback), address(composabilityHandler));        
        _inputRawBytes(address(mockAccount), address(mockAccount));
        _inputRawBytes(address(mockAccountCaller), address(composabilityHandler));
        _inputRawBytes(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_outputStaticCall_Success() public {
        _outputStaticCall(address(mockAccountFallback), address(composabilityHandler));
        _outputStaticCall(address(mockAccount), address(mockAccount));
        _outputStaticCall(address(mockAccountCaller), address(composabilityHandler));
        _outputStaticCall(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    // test actual composability => call executeComposable with multiple executions
    function test_useOutputAsInput_Success() public {
        _useOutputAsInput(address(mockAccountFallback), address(composabilityHandler));
        _useOutputAsInput(address(mockAccount), address(mockAccount));
        _useOutputAsInput(address(mockAccountCaller), address(composabilityHandler));
        _useOutputAsInput(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_outputExecResultAddress_Success() public {
        _outputExecResultAddress(address(mockAccountFallback), address(composabilityHandler));
        _outputExecResultAddress(address(mockAccount), address(mockAccount));
        _outputExecResultAddress(address(mockAccountCaller), address(composabilityHandler));
        _outputExecResultAddress(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_outputExecResultBool_Success() public {
        _outputExecResultBool(address(mockAccountFallback), address(composabilityHandler));
        _outputExecResultBool(address(mockAccount), address(mockAccount));
        _outputExecResultBool(address(mockAccountCaller), address(composabilityHandler));
        _outputExecResultBool(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_Runtime_Value_Injection_Success() public {
        _runtime_Value_Injection(address(mockAccountFallback), address(composabilityHandler));
        _runtime_Value_Injection(address(mockAccount), address(mockAccount));
        _runtime_Value_Injection(address(mockAccountCaller), address(composabilityHandler));
        _runtime_Value_Injection(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_Runtime_Target_Injection_Success() public {
        _runtime_Target_Injection(address(mockAccountFallback), address(composabilityHandler));
        _runtime_Target_Injection(address(mockAccount), address(mockAccount));
        _runtime_Target_Injection(address(mockAccountCaller), address(composabilityHandler));
        _runtime_Target_Injection(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_ERC20_Balance_Fetcher_Success() public {
        _erc20_Balance_Fetcher(address(mockAccountFallback), address(composabilityHandler));
        _erc20_Balance_Fetcher(address(mockAccount), address(mockAccount));
        _erc20_Balance_Fetcher(address(mockAccountCaller), address(composabilityHandler));
        _erc20_Balance_Fetcher(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    function test_Native_Balance_Fetcher_Success() public {
        _native_Balance_Fetcher(address(mockAccountFallback), address(composabilityHandler));
        _native_Balance_Fetcher(address(mockAccount), address(mockAccount));
        _native_Balance_Fetcher(address(mockAccountCaller), address(composabilityHandler));
        _native_Balance_Fetcher(address(mockAccountDelegateCaller), address(mockAccountDelegateCaller));
    }

    // =================================================================================
    // ================================ TEST SCENARIOS ================================
    // =================================================================================

    function _inputStaticCallOutputExecResult(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        // Step 1: Call function A and store its result
        // Prepare return value config for function A
        InputParam[] memory inputParamsA = new InputParam[](2);
        inputParamsA[0] = _createRawTargetInputParam(address(dummyContract));
        inputParamsA[1] = _createRawValueInputParam(0);

        OutputParam[] memory outputParamsA = new OutputParam[](1);
        outputParamsA[0] = OutputParam({
            fetcherType: OutputParamFetcherType.EXEC_RESULT,
            paramData: abi.encode(1, storageContract, SLOT_A)
        });

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.A.selector,
            inputParams: inputParamsA, // TARGET and VALUE parameters only
            outputParams: outputParamsA // store output of the function A() to the storage
        });

        // Call function A
        IComposableExecution(address(account)).executeComposable(executions);

        // Verify the result (42) was stored correctly
        bytes32 namespace = storageContract.getNamespace(address(account), address(caller));
        bytes32 SLOT_A_0 = keccak256(abi.encodePacked(SLOT_A, uint256(0)));
        bytes32 storedValueA = storageContract.readStorage(namespace, SLOT_A_0);
        assertEq(uint256(storedValueA), 42, "Function A result not stored correctly");

        // Step 2: Call function B using the stored value from A
        InputParam[] memory inputParamsB = new InputParam[](3);
        inputParamsB[0] = _createRawTargetInputParam(address(dummyContract));
        inputParamsB[1] = _createRawValueInputParam(0);
        inputParamsB[2] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.STATIC_CALL,
            paramData: abi.encode(storageContract, abi.encodeCall(Storage.readStorage, (namespace, SLOT_A_0))),
            constraints: emptyConstraints
        });

        // Prepare return value config for function B
        OutputParam[] memory outputParamsB = new OutputParam[](1);
        outputParamsB[0] = OutputParam({
            fetcherType: OutputParamFetcherType.EXEC_RESULT,
            paramData: abi.encode(1, storageContract, SLOT_B)
        });

        ComposableExecution[] memory executionsB = new ComposableExecution[](1);
        executionsB[0] = ComposableExecution({
            functionSig: DummyContract.B.selector,
            inputParams: inputParamsB,
            outputParams: outputParamsB
        });
        // Call function B
        IComposableExecution(address(account)).executeComposable(executionsB);

        // Verify the result (84 = 42 * 2) was stored correctly
        bytes32 SLOT_B_0 = keccak256(abi.encodePacked(SLOT_B, uint256(0)));
        bytes32 storedValueB = storageContract.readStorage(namespace, SLOT_B_0);
        assertEq(uint256(storedValueB), 84, "Function B result not stored correctly");

        vm.stopPrank();
    }

    // use 1 as input for emitUint256
    // so 1 should be emitted
    function _inputRawBytes(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        uint256 valueToSendExecution;
        if (address(account) == address(mockAccountFallback)) {
            valueToSendExecution = 1e15; // make sure value is successfully sent back by compos module
        }

        InputParam[] memory inputParams = new InputParam[](3);
        // call data
        inputParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(1),
            constraints: emptyConstraints
        });

        inputParams[1] = _createRawTargetInputParam(address(dummyContract));
        inputParams[2] = _createRawValueInputParam(valueToSendExecution);

        OutputParam[] memory outputParams = new OutputParam[](0);

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.emitUint256.selector,
            inputParams: inputParams,
            outputParams: outputParams
        });

        vm.expectEmit(address(dummyContract));
        emit Uint256Emitted(1);
        if (address(account) == address(mockAccountFallback)) {
            vm.expectEmit(address(dummyContract));
            emit Received(valueToSendExecution);
        }
        IComposableExecution(address(account)).executeComposable(executions);

        vm.stopPrank();
    }

    // test static call output fetcher.
    // call getFoo() on dummyContract
    // store the result in the composability storage
    // and check that the result is stored correctly
    function _outputStaticCall(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        InputParam[] memory inputParams = new InputParam[](2);
        inputParams[0] = _createRawTargetInputParam(address(dummyContract));
        inputParams[1] = _createRawValueInputParam(0);

        OutputParam[] memory outputParams = new OutputParam[](1);
        outputParams[0] = OutputParam({
            fetcherType: OutputParamFetcherType.STATIC_CALL,
            paramData: abi.encode(
                1,
                address(dummyContract),
                abi.encodeWithSelector(DummyContract.getFoo.selector),
                address(storageContract),
                SLOT_B
            )            
        });

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.getFoo.selector,
            inputParams: inputParams,
            outputParams: outputParams
        });

        uint256 expectedValue = 2517;
        dummyContract.setFoo(expectedValue);
        assertEq(dummyContract.getFoo(), expectedValue, "Value not stored correctly in the contract itself");

        IComposableExecution(address(account)).executeComposable(executions);
        vm.stopPrank();

        bytes32 namespace = storageContract.getNamespace(address(account), address(caller));
        bytes32 SLOT_B_0 = keccak256(abi.encodePacked(SLOT_B, uint256(0)));
        bytes32 storedValue = storageContract.readStorage(namespace, SLOT_B_0);
        assertEq(uint256(storedValue), expectedValue, "Value not stored correctly in the composability storage");
    }

    function _useOutputAsInput(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        uint256 input1 = 2517;
        uint256 input2 = 7579;
        uint256 valueToSend = 1e15;
        dummyContract.setFoo(input1);

        // first execution => call swap and store the result in the composability storage
        InputParam[] memory inputParams_execution1 = new InputParam[](4);
        inputParams_execution1[0] = _createRawTargetInputParam(address(dummyContract));
        inputParams_execution1[1] = _createRawValueInputParam(valueToSend);
        inputParams_execution1[2] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(input1),
            constraints: emptyConstraints
        });
        inputParams_execution1[3] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(input2),
            constraints: emptyConstraints
        });

        OutputParam[] memory outputParams_execution1 = new OutputParam[](2);
        outputParams_execution1[0] = OutputParam({
            fetcherType: OutputParamFetcherType.EXEC_RESULT,
            paramData: abi.encode(1, address(storageContract), SLOT_A)
        });
        outputParams_execution1[1] = OutputParam({
            fetcherType: OutputParamFetcherType.STATIC_CALL,
            paramData: abi.encode(
                1,
                address(dummyContract),
                abi.encodeWithSelector(DummyContract.getFoo.selector),
                address(storageContract),
                SLOT_B
            )
        });

        bytes32 namespace = storageContract.getNamespace(address(account), address(caller));

        bytes32 SLOT_A_0 = keccak256(abi.encodePacked(SLOT_A, uint256(0)));
        bytes32 SLOT_B_0 = keccak256(abi.encodePacked(SLOT_B, uint256(0)));
        // second execution => call stake with the result of the first execution
        InputParam[] memory inputParams_execution2 = new InputParam[](4);
        inputParams_execution2[0] = _createRawTargetInputParam(address(dummyContract));
        inputParams_execution2[1] = _createRawValueInputParam(valueToSend);
        inputParams_execution2[2] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.STATIC_CALL,
            paramData: abi.encode(storageContract, abi.encodeCall(Storage.readStorage, (namespace, SLOT_A_0))),
            constraints: emptyConstraints
        });
        inputParams_execution2[3] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.STATIC_CALL,
            paramData: abi.encode(storageContract, abi.encodeCall(Storage.readStorage, (namespace, SLOT_B_0))),
            constraints: emptyConstraints
        });
        OutputParam[] memory outputParams_execution2 = new OutputParam[](0);

        ComposableExecution[] memory executions = new ComposableExecution[](2);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.swap.selector,
            inputParams: inputParams_execution1,
            outputParams: outputParams_execution1
        });
        executions[1] = ComposableExecution({
            functionSig: DummyContract.stake.selector,
            inputParams: inputParams_execution2,
            outputParams: outputParams_execution2
        });

        uint256 expectedToStake = input1 + 1;
        uint256 messageValue;

        if (address(account) == address(mockAccountFallback)) {
            messageValue = valueToSend;
            vm.expectEmit(address(mockAccountFallback));
            emit MockAccountReceive(messageValue);
        }

        // swap emits input params
        vm.expectEmit(address(dummyContract));
        emit Uint256Emitted2(input1, input2);
        // swap emits output param
        vm.expectEmit(address(dummyContract));
        emit Uint256Emitted(expectedToStake);
        // stake emits input params: first param is from swap, second param is from getFoo which is just input1
        vm.expectEmit(address(dummyContract));
        emit Uint256Emitted2(expectedToStake, input1);
        
        vm.expectEmit(address(dummyContract));
        emit Received(valueToSend);

        IComposableExecution(address(account)).executeComposable{value: messageValue}(executions);

        //check storage slots
        bytes32 storedValueA = storageContract.readStorage(namespace, SLOT_A_0);
        assertEq(uint256(storedValueA), expectedToStake, "Value not stored correctly in the composability storage");
        bytes32 storedValueB = storageContract.readStorage(namespace, SLOT_B_0);
        assertEq(uint256(storedValueB), input1, "Value not stored correctly in the composability storage");

        vm.stopPrank();
    }

    // test that outputExecResultAddress works correctly with address
    // call getAddress() on dummyContract
    // store the result in the composability storage
    // and check that the result is stored correctly
    function _outputExecResultAddress(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        InputParam[] memory inputParams = new InputParam[](2);
        inputParams[0] = _createRawTargetInputParam(address(dummyContract));
        inputParams[1] = _createRawValueInputParam(0);

        OutputParam[] memory outputParams = new OutputParam[](1);
        outputParams[0] = OutputParam({
            fetcherType: OutputParamFetcherType.EXEC_RESULT,
            paramData: abi.encode(1, address(storageContract), SLOT_A)
        });

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.getAddress.selector,
            inputParams: inputParams,
            outputParams: outputParams
        });

        IComposableExecution(address(account)).executeComposable(executions);
        vm.stopPrank();

        bytes32 namespace = storageContract.getNamespace(address(account), address(caller));
        bytes32 SLOT_A_0 = keccak256(abi.encodePacked(SLOT_A, uint256(0)));
        bytes32 storedValue = storageContract.readStorage(namespace, SLOT_A_0);
        assertEq(address(uint160(uint256(storedValue))), address(dummyContract), "Value not stored correctly in the composability storage");
    }

    function _outputExecResultBool(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        InputParam[] memory inputParams = new InputParam[](2);
        inputParams[0] = _createRawTargetInputParam(address(dummyContract));
        inputParams[1] = _createRawValueInputParam(0);

        OutputParam[] memory outputParams = new OutputParam[](1);
        outputParams[0] = OutputParam({
            fetcherType: OutputParamFetcherType.EXEC_RESULT,
            paramData: abi.encode(1, address(storageContract), SLOT_A)
        });

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.getBool.selector,
            inputParams: inputParams,
            outputParams: outputParams
        });

        IComposableExecution(address(account)).executeComposable(executions);
        vm.stopPrank();

        bytes32 namespace = storageContract.getNamespace(address(account), address(caller));
        bytes32 SLOT_A_0 = keccak256(abi.encodePacked(SLOT_A, uint256(0)));
        bytes32 storedValue = storageContract.readStorage(namespace, SLOT_A_0);
        assertTrue(uint8(uint256(storedValue)) == 1, "Value not stored correctly in the composability storage");
    }

    function _runtime_Value_Injection(address account, address caller) internal {
        
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        InputParam[] memory inputParams = new InputParam[](2);

        inputParams[0] = _createRawTargetInputParam(address(dummyContract));
        inputParams[1] = InputParam({
            paramType: InputParamType.VALUE,
            fetcherType: InputParamFetcherType.STATIC_CALL,
            paramData: abi.encode(address(dummyContract), abi.encodeWithSelector(DummyContract.getNativeValue.selector)),
            constraints: emptyConstraints
        });

        OutputParam[] memory outputParams = new OutputParam[](0);

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.payableEmit.selector,
            inputParams: inputParams,
            outputParams: outputParams
        });

        uint256 expectedValue = dummyContract.getNativeValue();
        vm.expectEmit(address(dummyContract));
        emit Received(expectedValue);
        IComposableExecution(address(account)).executeComposable(executions);
        
        vm.stopPrank();
    }

    function _runtime_Target_Injection(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        uint256 uintToEmit = 1823920923;

        InputParam[] memory inputParams = new InputParam[](3);
        inputParams[0] = InputParam({
            paramType: InputParamType.TARGET,
            fetcherType: InputParamFetcherType.STATIC_CALL,
            paramData: abi.encode(address(dummyContract), abi.encodeWithSelector(DummyContract.getAddress.selector)),
            constraints: emptyConstraints
        });
        inputParams[1] = _createRawValueInputParam(0);
        inputParams[2] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(uintToEmit),
            constraints: emptyConstraints
        });

        OutputParam[] memory outputParams = new OutputParam[](0);

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.emitUint256.selector,
            inputParams: inputParams,
            outputParams: outputParams
        });

        vm.expectEmit(address(dummyContract));
        emit Uint256Emitted(uintToEmit);
        IComposableExecution(address(account)).executeComposable(executions);
        
        vm.stopPrank();
    }

    function _erc20_Balance_Fetcher(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        uint256 balanceToSet = 139122330912355;
        mockERC20Balance.setBalance(address(0xa11ce), balanceToSet);

        InputParam[] memory inputParams = new InputParam[](2);
        inputParams[0] = _createRawTargetInputParam(address(dummyContract));
        inputParams[1] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.BALANCE,
            paramData: abi.encodePacked(address(mockERC20Balance), address(0xa11ce)),
            constraints: emptyConstraints
        });

        // since this is commented out, this test case also 
        // makes sure that the value = 0 is used if the VALUE param is not provided
        // inputParams[2] = _createRawValueInputParam(0);

        OutputParam[] memory outputParams = new OutputParam[](0);

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.emitUint256.selector,
            inputParams: inputParams,
            outputParams: outputParams
        });

        // balance is used as param to the emitUint256 function
        vm.expectEmit(address(dummyContract));
        emit Uint256Emitted(balanceToSet);
        IComposableExecution(address(account)).executeComposable(executions);

        vm.stopPrank();
    }

    function _native_Balance_Fetcher(address account, address caller) internal {
        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        uint256 balanceToSet = 139122330912355;
        vm.deal(address(0xa11ce), balanceToSet);
        assertEq(address(0xa11ce).balance, balanceToSet);

        InputParam[] memory inputParams = new InputParam[](3);
        inputParams[0] = _createRawTargetInputParam(address(dummyContract));
        inputParams[1] = _createRawValueInputParam(0);
        
        inputParams[2] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.BALANCE,
            paramData: abi.encodePacked(address(0), address(0xa11ce)),
            constraints: emptyConstraints
        });

        OutputParam[] memory outputParams = new OutputParam[](0);

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: DummyContract.emitUint256.selector,
            inputParams: inputParams,
            outputParams: outputParams
        });
        
        vm.expectEmit(address(dummyContract));
        emit Uint256Emitted(balanceToSet);
        IComposableExecution(address(account)).executeComposable(executions);

        vm.stopPrank();
    }
    

    

    /*

    runtime address injection

    test fetcher type BALANCE


    */
}
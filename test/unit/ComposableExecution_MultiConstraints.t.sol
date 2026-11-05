// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "test/ComposabilityBase.t.sol";
import { ComposableExecutionModule } from "contracts/ComposableExecutionModule.sol";
import { IComposableExecution } from "contracts/interfaces/IComposableExecution.sol";
import "contracts/ComposableExecutionLib.sol";
import "contracts/types/ComposabilityDataTypes.sol";

contract ComposableExecutionTestMultiConstraints is ComposabilityTestBase {
    function setUp() public override {
        super.setUp();
    }

    /// @notice Proves that multiple constraints on a single input parameter must ALL validate the parameter value
    function test_inputs_With_Multiple_And_Constraints() public {
        _testMultipleConstraints(address(mockAccount));
    }

    function _testMultipleConstraints(address account) internal {
        // Enforce both GTE(40) AND LTE(50) on the same parameter
        Constraint[] memory constraints = new Constraint[](2);
        constraints[0] = Constraint({ constraintType: ConstraintType.GTE, referenceData: abi.encode(bytes32(uint256(40))) });
        constraints[1] = Constraint({ constraintType: ConstraintType.LTE, referenceData: abi.encode(bytes32(uint256(50))) });

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        // Value 45 is between 40 and 50 -> must SUCCEED
        InputParam[] memory validParams = new InputParam[](3);
        validParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(uint256(45)),
            constraints: constraints
        });
        validParams[1] = _createRawTargetInputParam(address(0));
        validParams[2] = _createRawValueInputParam(0);

        ComposableExecution[] memory validExecutions = new ComposableExecution[](1);
        validExecutions[0] = ComposableExecution({
            functionSig: "",
            inputParams: validParams,
            outputParams: new OutputParam[](0)
        });

        IComposableExecution(account).executeComposable(validExecutions);

        // Value 55 violates LTE(50) -> must REVERT with ConstraintNotMet(LTE)
        InputParam[] memory invalidParams = new InputParam[](3);
        invalidParams[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(uint256(55)),
            constraints: constraints
        });
        invalidParams[1] = _createRawTargetInputParam(address(0));
        invalidParams[2] = _createRawValueInputParam(0);

        ComposableExecution[] memory invalidExecutions = new ComposableExecution[](1);
        invalidExecutions[0] = ComposableExecution({
            functionSig: "",
            inputParams: invalidParams,
            outputParams: new OutputParam[](0)
        });

        vm.expectRevert(abi.encodeWithSelector(ComposableExecutionLib.ConstraintNotMet.selector, ConstraintType.LTE));
        IComposableExecution(account).executeComposable(invalidExecutions);

        vm.stopPrank();
    }

    /// @notice Proves that passing more constraints than available return words reverts safely instead of reading OOB memory
    function test_constraints_Exceed_Return_Words_Reverts() public {
        address account = address(mockAccount);
        // Create 3 constraints for a 2-word input
        Constraint[] memory constraints = new Constraint[](3);
        constraints[0] = Constraint({ constraintType: ConstraintType.EQ, referenceData: abi.encode(bytes32(uint256(1))) });
        constraints[1] = Constraint({ constraintType: ConstraintType.EQ, referenceData: abi.encode(bytes32(uint256(2))) });
        constraints[2] = Constraint({ constraintType: ConstraintType.EQ, referenceData: abi.encode(bytes32(uint256(3))) });

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        InputParam[] memory params = new InputParam[](3);
        params[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(uint256(1), uint256(2)), // 64 bytes = 2 words
            constraints: constraints
        });
        params[1] = _createRawTargetInputParam(address(0));
        params[2] = _createRawValueInputParam(0);

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: "",
            inputParams: params,
            outputParams: new OutputParam[](0)
        });

        vm.expectRevert(abi.encodeWithSelector(ComposableExecutionLib.InvalidParameterEncoding.selector, "Constraints exceed return values"));
        IComposableExecution(account).executeComposable(executions);

        vm.stopPrank();
    }

    /// @notice Proves that validating constraints on values shorter than 32 bytes reverts cleanly
    function test_constraints_Short_Value_Reverts() public {
        address account = address(mockAccount);
        Constraint[] memory constraints = new Constraint[](1);
        constraints[0] = Constraint({ constraintType: ConstraintType.EQ, referenceData: abi.encode(bytes32(uint256(1))) });

        vm.startPrank(ENTRYPOINT_V07_ADDRESS);

        InputParam[] memory params = new InputParam[](3);
        params[0] = InputParam({
            paramType: InputParamType.CALL_DATA,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: hex"1234", // 2 bytes < 32 bytes
            constraints: constraints
        });
        params[1] = _createRawTargetInputParam(address(0));
        params[2] = _createRawValueInputParam(0);

        ComposableExecution[] memory executions = new ComposableExecution[](1);
        executions[0] = ComposableExecution({
            functionSig: "",
            inputParams: params,
            outputParams: new OutputParam[](0)
        });

        vm.expectRevert(abi.encodeWithSelector(ComposableExecutionLib.InvalidParameterEncoding.selector, "Value too short for constraint validation"));
        IComposableExecution(account).executeComposable(executions);

        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

contract ComposableMath {
    
    struct FunctionCall {
        address contractAddress;
        bytes4 functionSelector;
    }
    
    uint256 private constant VAR_MASK = 0x40000000;
    uint256 private constant OP_MASK = 0x80000000;
    uint256 private constant INDEX_MASK = 0x3FFFFFFF;
    
    uint256 private constant OP_ADD = 0x80000001;
    uint256 private constant OP_SUB = 0x80000002;
    uint256 private constant OP_MUL = 0x80000003;
    uint256 private constant OP_DIV = 0x80000004;
    uint256 private constant OP_MOD = 0x80000005;
    uint256 private constant OP_POW = 0x80000006;
    uint256 private constant OP_MAX = 0x80000007;
    uint256 private constant OP_MIN = 0x80000008;
    // TODO: add percentage operator
    
    error CallFailed(uint256 index);
    error StackUnderflow();
    error InvalidInstruction();
    error DivisionByZero();
    
    event CalculationExecuted(uint256[] callResults, uint256 finalResult);
    
    function calculateWithCalls(
        FunctionCall[] calldata calls,
        bytes[] calldata callParams,
        uint256[] calldata postfix
    ) external view returns (uint256 result) {
        uint256[] memory callResults = executeCalls(calls, callParams);
        result = evaluatePostfix(postfix, callResults);
        emit CalculationExecuted(callResults, result);
        return result;
    }

    // accept raw arguments , not function calls
    function calculateRaw(
        uint256[] calldata postfix,
        uint256[] calldata mockValues
    ) external pure returns (uint256 result) {
        return evaluatePostfix(postfix, mockValues);
    }

    // TODO: add a function that accepts mix of function calls and raw arguments
    // it is needed because someone may want and will definitely want something like
    // balanceOf(user) * 100 / totalSupply()
    // so some variables will be function calls, some will be raw arguments
    function calculate(
        // ??
    ) external view returns (uint256 result) {
        // TODO: implement
    }
    
    // TODO: is it even needed? this contract is going to be called from the composable execution contract
    // which doesn't expect an array of results, but a single result
    // we can maybe save it for future use, however I think we can add it later if we see the need for it
    function batchCalculate(
        FunctionCall[] calldata calls,
        bytes[] calldata callParams,
        uint256[][] calldata expressions
    ) external view returns (uint256[] memory results) {
        uint256[] memory callResults = executeCalls(calls, callParams);
        
        results = new uint256[](expressions.length);
        for (uint256 i = 0; i < expressions.length; i++) {
            results[i] = evaluatePostfix(expressions[i], callResults);
        }
    }
    
    function _executeCalls(
        FunctionCall[] calldata calls,
        bytes[] calldata callParams
    ) internal view returns (uint256[] memory results) {
        uint256 callCount = calls.length;
        results = new uint256[](callCount);
        
        for (uint256 i = 0; i < callCount; i++) {
            bytes memory callData = abi.encodePacked(calls[i].functionSelector, callParams[i]);
            (bool success, bytes memory returnData) = calls[i].contractAddress.staticcall(callData);
            
            if (!success) revert CallFailed(i);
            results[i] = abi.decode(returnData, (uint256));
        }
    }
    
    function _evaluatePostfix(
        uint256[] calldata postfix,
        uint256[] memory values
    ) internal pure returns (uint256) {
        uint256[] memory stack = new uint256[](postfix.length);
        uint256 stackTop = 0;
        
        for (uint256 i = 0; i < postfix.length; i++) {
            uint256 instruction = postfix[i];
            
            if (instruction & VAR_MASK == VAR_MASK) {
                uint256 varIndex = instruction & INDEX_MASK;
                if (varIndex == 0 || varIndex > values.length) revert InvalidInstruction();
                stack[stackTop] = values[varIndex - 1];
                stackTop++;
            }
            else if (instruction & OP_MASK == OP_MASK) {
                if (stackTop < 2) revert StackUnderflow();
                
                stackTop--;
                uint256 b = stack[stackTop];
                stackTop--;
                uint256 a = stack[stackTop];
                
                uint256 result;
                
                if (instruction == OP_ADD) {
                    result = a + b;
                } else if (instruction == OP_SUB) {
                    result = a - b;
                } else if (instruction == OP_MUL) {
                    result = a * b;
                } else if (instruction == OP_DIV) {
                    if (b == 0) revert DivisionByZero();
                    result = a / b;
                } else if (instruction == OP_MOD) {
                    if (b == 0) revert DivisionByZero();
                    result = a % b;
                } else if (instruction == OP_POW) {
                    result = a ** b;
                } else if (instruction == OP_MAX) {
                    result = a > b ? a : b;
                } else if (instruction == OP_MIN) {
                    result = a < b ? a : b;
                } else {
                    revert InvalidInstruction();
                }
                
                stack[stackTop] = result;
                stackTop++;
            }
            else {
                stack[stackTop] = instruction;
                stackTop++;
            }
        }
        
        if (stackTop != 1) revert InvalidInstruction();
        return stack[0];
    }
    
    function validatePostfix(uint256[] calldata postfix) external pure returns (bool valid) {
        uint256 stackDepth = 0;
        
        for (uint256 i = 0; i < postfix.length; i++) {
            uint256 instruction = postfix[i];
            
            if (instruction & VAR_MASK == VAR_MASK || (instruction & OP_MASK) == 0) {
                stackDepth++;
            } 
            else if (instruction & OP_MASK == OP_MASK) {
                if (stackDepth < 2) return false;
                stackDepth--;
            } 
            else {
                return false;
            }
        }
        
        return stackDepth == 1;
    }
    
    // TODO: what is this used for?
    // seems to be not needed. first of all, the same can be done off-chain
    // second, seems to be incorrect, as the variable is compared to the index, not the value
    function getMaxVariable(uint256[] calldata postfix) external pure returns (uint256 maxVariable) {
        for (uint256 i = 0; i < postfix.length; i++) {
            uint256 instruction = postfix[i];
            
            if (instruction & VAR_MASK == VAR_MASK) {
                uint256 varIndex = instruction & INDEX_MASK;
                if (varIndex > maxVariable) {
                    maxVariable = varIndex;
                }
            }
        }
    }
    
    function countOperations(uint256[] calldata postfix) external pure returns (uint256 operationCount) {
        for (uint256 i = 0; i < postfix.length; i++) {
            if (postfix[i] & OP_MASK == OP_MASK) {
                operationCount++;
            }
        }
    }
}

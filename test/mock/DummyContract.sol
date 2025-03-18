// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

event Uint256Emitted(uint256 value);
event Uint256Emitted2(uint256 value1, uint256 value2);
event AddressEmitted(address addr);
event Bytes32Emitted(bytes32 slot);
event BoolEmitted(bool flag);
event BytesEmitted(bytes data);
event Received(uint256 amount);

error DummyRevert(uint256 value);

struct MockSwapStruct {
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 amountOutMin;
    uint256 deadline;
    uint256 fee;
}

contract DummyContract {

    uint256 internal foo;

    function A() external pure returns (uint256) {
        return 42;
    }

    function B(uint256 value) external pure returns (uint256) {
        // Return the input value multiplied by 2
        return value * 2;
    }

    function getFoo() external view returns (uint256) {
        return foo;
    }

    function setFoo(uint256 value) external {
        foo = value;
    }

    function emitUint256(uint256 value) external payable {
        emit Uint256Emitted(value);
        emit Received(msg.value);
    }

    function swap(uint256 exactInput, uint256 minOutput) external payable returns (uint256 output1) {
        emit Uint256Emitted2(exactInput, minOutput);
        output1 = exactInput + 1;
        emit Uint256Emitted(output1);
        emit Received(msg.value);
    }

    function stake(uint256 toStake, uint256 param2) external payable {
        emit Uint256Emitted2(toStake, param2);
        emit Received(msg.value);
    }

    function getAddress() external view returns (address) {
        return address(this);
    }

    function getBool() external pure returns (bool) {
        return true;
    }

    function returnMultipleValues() external view returns (uint256, address, bytes32, bool) {
        return (2517, address(this), keccak256("DUMMY"), true);
    }

    function acceptMultipleValues(uint256 value1, address addr, bytes32 slot, bool flag) external {
        emit Uint256Emitted(value1);
        emit AddressEmitted(addr);
        emit Bytes32Emitted(slot);
        emit BoolEmitted(flag);
    }

    function acceptStaticAndDynamicValues(uint256 staticValue, bytes calldata dynamicValue, address addr) external {
        emit Uint256Emitted(staticValue);
        emit AddressEmitted(addr);
        emit BytesEmitted(dynamicValue);
    }

    function acceptStruct(MockSwapStruct memory swapStruct) external {
        emit Uint256Emitted(swapStruct.amountIn);
        emit Uint256Emitted(swapStruct.amountOutMin);
        emit Uint256Emitted(swapStruct.deadline);
        emit Uint256Emitted(swapStruct.fee);
        emit AddressEmitted(swapStruct.tokenIn);
        emit AddressEmitted(swapStruct.tokenOut);
    }

    function revertWithReason(uint256 value) external pure {
        revert DummyRevert(value);
    }
}
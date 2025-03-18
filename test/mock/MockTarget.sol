// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract MockTarget {
    uint256 public value;
    uint256 public counter;

    function setValue(uint256 _value) public returns (uint256) {
        value = _value;
        return _value;
    }

    function incrementCounter() public returns (uint256) {
        counter++;
        return counter;
    }
}

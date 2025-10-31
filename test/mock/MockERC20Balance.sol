// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract MockERC20Balance {
    mapping(address => uint256) public balanceOf;

    function setBalance(address account, uint256 balance) public {
        balanceOf[account] = balance;
    }
}

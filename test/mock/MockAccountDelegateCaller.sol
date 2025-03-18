// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "contracts/interfaces/IComposableExecution.sol";

contract MockAccountDelegateCaller {

    address composableModule;
    event MockAccountDelegateCall(bytes returnData);

    constructor(address _composableModule) {
        composableModule = _composableModule;
    }

    function executeComposable(ComposableExecution[] calldata executions) external {
        // delegatecall to the composableModule
        (bool success, bytes memory returnData) = composableModule.delegatecall(abi.encodeWithSelector(IComposableExecutionModule.executeComposableDelegateCall.selector, executions));
        emit MockAccountDelegateCall(returnData);
        assembly {
            if iszero(success) {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
    }
}

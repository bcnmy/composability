// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.23;

import { ComposableExecution } from "../types/ComposabilityDataTypes.sol";

interface IComposableExecution {
    function executeComposable(ComposableExecution[] calldata cExecutions) external payable;
}

interface IComposableExecutionModule is IComposableExecution {
    function executeComposableCall(ComposableExecution[] calldata cExecutions) external;
    function executeComposableDelegateCall(ComposableExecution[] calldata cExecutions) external;
}

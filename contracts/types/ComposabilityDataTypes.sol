// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// Type of the input parameter
enum InputParamType {
    TARGET, // The target address
    VALUE, // The value
    CALL_DATA // The call data
}

// Parameter type for composition
enum InputParamFetcherType {
    RAW_BYTES, // Already encoded bytes
    STATIC_CALL, // Perform a static call
    BALANCE // Get the balance of an address
}

enum OutputParamFetcherType {
    EXEC_RESULT, // The return of the execution call
    STATIC_CALL // Call to some other function
}

// Constraint type for parameter validation
enum ConstraintType {
    EQ, // Equal to
    GTE, // Greater than or equal to
    LTE, // Less than or equal to
    IN // In range
}

// Constraint for parameter validation
struct Constraint {
    ConstraintType constraintType;
    bytes referenceData;
}

// Structure to define parameter composition
struct InputParam {
    InputParamType paramType;
    InputParamFetcherType fetcherType; // How to fetch the parameter
    bytes paramData;
    Constraint[] constraints;
}

// Structure to define return value handling
struct OutputParam {
    OutputParamFetcherType fetcherType; // How to fetch the parameter
    bytes paramData;
}

// Structure to define a composable execution
struct ComposableExecution {
    bytes4 functionSig;
    InputParam[] inputParams;
    OutputParam[] outputParams;
}

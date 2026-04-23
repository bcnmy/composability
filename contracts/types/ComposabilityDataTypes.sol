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
    EQ, // Equal to (bitwise equality; suitable for signed, unsigned, addresses, bytes32)
    GTE, // Greater than or equal to (unsigned)
    LTE, // Less than or equal to (unsigned)
    IN, // In range [lower, upper] (bytes32 comparison; suitable for unsigned ranges and same-sign signed ranges)
    GTE_SIGNED, // Greater than or equal to (signed int256)
    LTE_SIGNED, // Less than or equal to (signed int256)
    OR // At least one sub-constraint must pass; referenceData = abi.encode(Constraint[]); sub-constraints must be leaf types (no nested OR)
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

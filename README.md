## Composability Stack || Smart Contracts

**Smart contracts to unlock composable execution.**

The composability stack solves this by allowing developers to create dynamic, multi-step transactions entirely from frontend code.
The smart contracts in this repo handle the composable execution logic allowing developers to avoid any on-chain development and just use SDK to build composable operations.

Features: 
-   **Single-chain composability**: Use outputs of one action as inputs for another.
For example, `swap()` method returns the amount of tokens received as a result of a swap. 
This exact amount can be used as input for `approve()` method to allow a `stake()` method to execute.
-   **Static types handling**: Inject any static types into the abi.encoded function call.
-   **Several return values handling**: If function returns multiple values, you can use any amount of them as input for another function.
-   **Constraints handling**: Validate any constraints on the input parameters.

Contracts included:

-   **Composable Execution Module**: ERC-7579 module, that allows Smart Accounts to execute composable transactions without changing the account implementation.
-   **Composable Execution Base**: Base contract, that Smart Accounts can inherit from to enable composable execution natively.
-   **Composable Execution Lib**: Library that provides methods to process input and output parameters of a composable execution.

## About Composability
[Biconomy Documentation](https://docs.biconomy.io/composability)

## On storage slots for ComposableExecutionModule
As can be seen in the Storage.sol file, the actual storage slot used depends on both the `account` address and the `caller` 
address.

Thus, if the ComposableExecutionModule is used via 'call' flows (as a Fallback and/or Executor module), the storage slot is different compared to the case when the module is used via 'delegatecall' flow.

It is however recommended that the SA is consistent in terms of which flow - `call` or `delegatecall` - it uses.

## Usage

### Install

```shell
$ pnpm i
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

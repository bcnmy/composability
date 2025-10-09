// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test, Vm, console2 } from "forge-std/Test.sol";
import { MockAccountFallback } from "./mock/MockAccountFallback.sol";
import { MockAccountNonRevert } from "./mock/MockAccountNonRevert.sol";
import { ComposableExecutionModule } from "contracts/ComposableExecutionModule.sol";
import { MockAccountDelegateCaller } from "./mock/MockAccountDelegateCaller.sol";
import { MockAccountCaller } from "./mock/MockAccountCaller.sol";
import { MockAccount } from "test/mock/MockAccount.sol";
import { Storage } from "../contracts/Storage.sol";
import { InputParam, Constraint, InputParamType, InputParamFetcherType } from "contracts/types/ComposabilityDataTypes.sol";
import "./mock/DummyContract.sol";
import "./mock/MockERC20Balance.sol";

address constant ENTRYPOINT_V07_ADDRESS = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

contract ComposabilityTestBase is Test {
    ComposableExecutionModule internal composabilityHandler;
    MockAccountFallback internal mockAccountFallback;
    MockAccountDelegateCaller internal mockAccountDelegateCaller;
    MockAccountCaller internal mockAccountCaller;
    MockAccountNonRevert internal mockAccountNonRevert;
    MockAccount internal mockAccount;
    MockERC20Balance internal mockERC20Balance;

    event MockAccountReceive(uint256 amount);

    Storage public storageContract;
    DummyContract public dummyContract;

    bytes32 public constant SLOT_A = keccak256("SLOT_A");
    bytes32 public constant SLOT_B = keccak256("SLOT_B");

    Constraint[] internal emptyConstraints = new Constraint[](0);

    function setUp() public virtual {
        composabilityHandler = new ComposableExecutionModule(ENTRYPOINT_V07_ADDRESS);
        mockAccountFallback =
            new MockAccountFallback({ _validator: address(0), _executor: address(composabilityHandler), _handler: address(composabilityHandler) });
        mockAccountCaller = new MockAccountCaller({ _validator: address(0), _executor: address(composabilityHandler), _handler: address(composabilityHandler) });
        mockAccountDelegateCaller = new MockAccountDelegateCaller({ _composableModule: address(composabilityHandler) });

        vm.prank(address(mockAccountFallback));
        composabilityHandler.onInstall(abi.encodePacked(ENTRYPOINT_V07_ADDRESS));

        mockAccount = new MockAccount({ _validator: address(0), _handler: address(0xa11ce) });
        mockAccountNonRevert = new MockAccountNonRevert({ _validator: address(0), _handler: address(0xa11ce) });
        mockERC20Balance = new MockERC20Balance();

        // fund accounts
        vm.deal(address(mockAccountFallback), 100 ether);
        vm.deal(address(mockAccountDelegateCaller), 100 ether);
        vm.deal(address(mockAccountCaller), 100 ether);
        vm.deal(address(mockAccountNonRevert), 100 ether);
        vm.deal(address(mockAccount), 100 ether);
        vm.deal(address(ENTRYPOINT_V07_ADDRESS), 100 ether);

        // Deploy contracts
        storageContract = new Storage();
        dummyContract = new DummyContract();
    }

    function _createRawTargetInputParam(address target) internal returns (InputParam memory) {
        return InputParam({
            paramType: InputParamType.TARGET,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(target),
            constraints: emptyConstraints
        });
    }

    function _createRawValueInputParam(uint256 value) internal returns (InputParam memory) {
        return InputParam({
            paramType: InputParamType.VALUE,
            fetcherType: InputParamFetcherType.RAW_BYTES,
            paramData: abi.encode(value),
            constraints: emptyConstraints
        });
    }
}

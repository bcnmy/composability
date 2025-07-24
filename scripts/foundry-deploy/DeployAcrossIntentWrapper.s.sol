// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AcrossIntentWrapper} from "../../contracts/wrappers/AcrossIntentWrapper.sol";
import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

contract DeployAcrossIntentWrapper is Script {

    function setUp() public {
        
    }

    function run() public {
        vm.startBroadcast();
        
        AcrossIntentWrapper acrossIntentWrapper = new AcrossIntentWrapper();
        
        vm.stopBroadcast();
    }
}

// OP mainnet: 0xB9F82b52Afde09D0E2CC0748a66D1Df76C18A1c7 (with emit)
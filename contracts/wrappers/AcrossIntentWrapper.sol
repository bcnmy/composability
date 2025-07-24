pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface AcrossV3SpokePool {
  function depositV3(
    address depositor,
    address recipient,
    address inputToken,
    address outputToken,
    uint256 inputAmount,
    uint256 outputAmount,
    uint256 destinationChainId,
    address exclusiveRelayer,
    uint32 quoteTimestamp,
    uint32 fillDeadline,
    uint32 exclusivityDeadline,
    bytes calldata message
  ) external payable;
}

contract AcrossIntentWrapper {
    error InputAmountMismatch(uint256 balance, uint256 inputAmount);
    
    function depositV3Composable (
        address pool, // pool to call
        address depositor,
        address recipient,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputRatioPacked, // MS 128bytes: output ratio = (quotedInputAmount * OUTPUT_RATIO_PRECISION) / quotedOutputAmount ; LS 128bytes: OUTPUT_RATIO_PRECISION
        uint256 destinationChainId,
        address exclusiveRelayer,
        uint32 quoteTimestamp,
        uint32 fillDeadline,
        uint32 exclusivityDeadline,
        bytes calldata message
    ) external payable {
        // 1. Approve input amount to the pool
        uint256 balance = IERC20(inputToken).balanceOf(address(this));
        require (balance == inputAmount, InputAmountMismatch(balance, inputAmount));
        IERC20(inputToken).approve(pool, inputAmount);

        // 2. Unpack the output ratio
        uint256 outputRatio = outputRatioPacked >> 128;
        uint256 outputRatioPrecision = outputRatioPacked & 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;

        // 3. Get the output amount
        uint256 outputAmount = inputAmount * outputRatio / outputRatioPrecision;

        // 4. Call the pool with the runtime amount
        AcrossV3SpokePool(pool).depositV3{value: msg.value}(
            depositor,
            recipient,
            inputToken,
            outputToken,
            inputAmount,
            outputAmount,
            destinationChainId,
            exclusiveRelayer,
            quoteTimestamp,
            fillDeadline,
            exclusivityDeadline,
            message
        );
    }
}
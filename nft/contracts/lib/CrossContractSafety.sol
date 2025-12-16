// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CrossContractSafety
 * @dev Provides safe cross-contract interaction patterns with fallbacks
 * @notice Prevents failures from dependency contracts
 */
library CrossContractSafety {
    // =============================================================================
    // ERRORS
    // =============================================================================
    error ExternalCallFailed();
    error InvalidContractAddress();

    // =============================================================================
    // EVENTS
    // =============================================================================
    event FallbackActivated(address indexed contract_, string reason);
    event ExternalCallSuccess(address indexed contract_, bytes4 selector);

    // =============================================================================
    // FUNCTIONS
    // =============================================================================

    /**
     * @dev Safe external call with fallback
     * @param target Target contract address
     * @param data Call data
     * @param errorMessage Error message if call fails
     * @return success Whether call succeeded
     * @return returnData Return data from call
     */
    function safeCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bool success, bytes memory returnData) {
        if (target == address(0)) {
            emit FallbackActivated(target, "Zero address");
            return (false, "");
        }

        // Check if contract exists
        uint256 size;
        assembly {
            size := extcodesize(target)
        }
        if (size == 0) {
            emit FallbackActivated(target, "No contract code");
            return (false, "");
        }

        // Make the call
        (success, returnData) = target.call(data);

        if (success) {
            emit ExternalCallSuccess(target, bytes4(data));
        } else {
            emit FallbackActivated(target, errorMessage);
        }
    }

    /**
     * @dev Safe static call for view functions
     * @param target Target contract address
     * @param data Call data
     * @param defaultValue Default value to return on failure
     * @return result The result or default value
     */
    function safeStaticCall(
        address target,
        bytes memory data,
        bytes memory defaultValue
    ) internal view returns (bytes memory result) {
        if (target == address(0)) {
            return defaultValue;
        }

        // Check if contract exists
        uint256 size;
        assembly {
            size := extcodesize(target)
        }
        if (size == 0) {
            return defaultValue;
        }

        // Make the static call
        (bool success, bytes memory returnData) = target.staticcall(data);

        if (success && returnData.length > 0) {
            return returnData;
        } else {
            return defaultValue;
        }
    }

    /**
     * @dev Check if external contract is available
     * @param target Contract address to check
     * @return available Whether contract is available
     */
    function isContractAvailable(
        address target
    ) internal view returns (bool available) {
        if (target == address(0)) {
            return false;
        }

        uint256 size;
        assembly {
            size := extcodesize(target)
        }

        return size > 0;
    }

    /**
     * @dev Safe boolean check with default
     * @param target Target contract
     * @param data Call data
     * @param defaultValue Default value if call fails
     * @return result Boolean result
     */
    function safeBoolCall(
        address target,
        bytes memory data,
        bool defaultValue
    ) internal view returns (bool result) {
        bytes memory returnData = safeStaticCall(
            target,
            data,
            abi.encode(defaultValue)
        );

        if (returnData.length >= 32) {
            return abi.decode(returnData, (bool));
        } else {
            return defaultValue;
        }
    }

    /**
     * @dev Safe uint256 check with default
     * @param target Target contract
     * @param data Call data
     * @param defaultValue Default value if call fails
     * @return result Uint256 result
     */
    function safeUintCall(
        address target,
        bytes memory data,
        uint256 defaultValue
    ) internal view returns (uint256 result) {
        bytes memory returnData = safeStaticCall(
            target,
            data,
            abi.encode(defaultValue)
        );

        if (returnData.length >= 32) {
            return abi.decode(returnData, (uint256));
        } else {
            return defaultValue;
        }
    }
}

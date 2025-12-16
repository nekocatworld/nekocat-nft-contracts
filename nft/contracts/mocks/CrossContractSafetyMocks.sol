// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../lib/CrossContractSafety.sol";

contract MockContract {
    uint256 public value;
    bool public boolValue;
    string public largeData;

    function setValue(uint256 _value) external {
        value = _value;
    }

    function getValue() external view returns (uint256) {
        return value;
    }

    function setBoolValue(bool _value) external {
        boolValue = _value;
    }

    function getBoolValue() external view returns (bool) {
        return boolValue;
    }

    function setLargeData(string calldata _data) external {
        largeData = _data;
    }

    function getLargeData() external view returns (string memory) {
        return largeData;
    }

    function revertFunction() external pure {
        revert("Intentional revert");
    }

    function emptyReturnFunction() external pure {
        // Returns nothing
    }

    function testFunction() external pure returns (string memory) {
        return "test";
    }
}

contract TestCrossContractSafety {
    using CrossContractSafety for address;

    event ExternalCallSuccess(address indexed contract_, bytes4 selector);
    event FallbackActivated(address indexed contract_, string reason);

    function testSafeCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) external {
        (bool success, bytes memory returnData) = target.safeCall(
            data,
            errorMessage
        );

        if (success) {
            emit ExternalCallSuccess(target, bytes4(data));
        } else {
            emit FallbackActivated(target, errorMessage);
        }
    }

    function testSafeCallWithReturn(
        address target,
        bytes memory data,
        string memory errorMessage
    ) external returns (bool success, bytes memory returnData) {
        (success, returnData) = target.safeCall(data, errorMessage);
    }

    function testSafeStaticCall(
        address target,
        bytes memory data,
        bytes memory defaultValue
    ) external view returns (bytes memory result) {
        return target.safeStaticCall(data, defaultValue);
    }

    function testIsContractAvailable(
        address target
    ) external view returns (bool available) {
        return target.isContractAvailable();
    }

    function testSafeBoolCall(
        address target,
        bytes memory data,
        bool defaultValue
    ) external view returns (bool result) {
        return target.safeBoolCall(data, defaultValue);
    }

    function testSafeUintCall(
        address target,
        bytes memory data,
        uint256 defaultValue
    ) external view returns (uint256 result) {
        return target.safeUintCall(data, defaultValue);
    }

    function testFunction() external pure returns (string memory) {
        return "test";
    }
}

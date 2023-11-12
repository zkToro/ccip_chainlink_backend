// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

abstract contract Util {

    function stringToUint(string memory str) public pure returns (uint256 result) {
        // Ensure the string is not empty
        require(bytes(str).length > 0, "String is empty");

        // Initialize the result variable
        result = 0;
        
        // Process each byte of the string
        for (uint256 i = 0; i < bytes(str).length; i++) {
            // Convert the byte to a uint and ensure it represents a number
            uint8 char = uint8(bytes(str)[i]);
            require(char >= 48 && char <= 57, "String contains non-numeric character");

            // Accumulate the result while preventing overflow
            result = result * 10 + (char - 48);
        }

        return result;
    }
    
    function addUint256ToInt256(int256 a, uint256 b) public pure returns (int256) {
        require(b <= uint256(type(int256).max), "Conversion overflow");

        int256 convertedB = int256(b);

        if (a >= 0) {
            // Check for overflow
            require(type(int256).max - a >= convertedB, "Addition overflow");
        } else {
            // Check for underflow
            require(type(int256).min - a <= convertedB, "Addition underflow");
        }

        return a + convertedB;
    }
    function subtractUint256FromInt256(int256 a, uint256 b) public pure returns (int256) {
        require(b <= uint256(type(int256).max), "Conversion overflow");

        int256 convertedB = int256(b);

        if (a >= 0) {
            // Check for underflow
            require(a >= convertedB, "Subtraction underflow");
        } else {
            // Check for overflow
            require(type(int256).min - a <= convertedB, "Subtraction overflow");
        }

        return a - convertedB;
    }
    function safeAddIntToUint(int256 a, uint256 b) public pure returns (uint256) {
        if (a < 0) {
            require(b >= uint256(-a), "Underflow occurred");
            return b - uint256(-a);
        } else {
            require(uint256(type(int256).max) - uint256(a) >= b, "Overflow occurred");
            return b + uint256(a);
        }
    }
    function bytesToHexString(bytes memory data) public pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory hexString = new bytes(data.length * 2);

        for (uint i = 0; i < data.length; i++) {
            hexString[i*2] = hexChars[uint8(data[i]) >> 4];
            hexString[i*2 + 1] = hexChars[uint8(data[i]) & 0x0f];
        }

        return string(hexString);
    }
}
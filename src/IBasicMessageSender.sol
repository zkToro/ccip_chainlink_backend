// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Define an interface that matches the functions of the deployed contract
interface IBasicMessageSender {

    function send(
        uint64 destinationChainSelector,
        address receiver,
        string memory messageText,
        bool useLink
    )  external returns (bytes32 messageId); // Replace with actual function signatures
    // Add more functions as needed
}



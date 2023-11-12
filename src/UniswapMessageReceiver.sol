// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Withdraw} from "./utils/Withdraw.sol";
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';

/**
this is the place where tokens should be deposited to 

 */
contract UniswapMessageReceiver is CCIPReceiver, Withdraw {
    bytes32 latestMessageId;
    uint64 latestSourceChainSelector;
    address latestSender;
    string latestMessage;
    bytes32 latestArgs;
    uint256 public tokenSwapAmount;
    address _owner;

    ISwapRouter public immutable swapRouter;

    event TokenSwapAmount(
        uint amountIn
    );

    event MessageReceived(
        bytes32 latestMessageId,
        uint64 latestSourceChainSelector,
        address latestSender,
        string latestMessage
    );
    modifier ownerOnly(){
        require(msg.sender == _owner);
        _;
    }

    // address public constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    // address public constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    // address public constant EOA = 0xE5E568ad4Eeb316Ac2930eFf406507ad13B71a5b;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    uint24 public constant poolFee = 100; //0.01%

    constructor(address router, ISwapRouter _swapRouter) CCIPReceiver(router) {
        _owner = msg.sender;
        swapRouter = _swapRouter;
    }

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

    function ccipReceiveTest(
        string memory message
    ) public ownerOnly returns(uint256)  {
        return swapExactInputSingle( stringToUint(message));

        // latestMessageId = message.messageId;
        // latestSourceChainSelector = message.sourceChainSelector;
        // latestSender = abi.decode(message.sender, (address));
        // latestMessage = abi.decode(message.data, (string));
        // latestArgs = abi.decode(message.extraArgs,(bytes));

        // bytes memory amountIn = abi.encodePacked(latestMessage);
        // bytes32 amountIn32;
        // assembly {
        //     amountIn32 := mload(add(amountIn, 32))
        // }

        // tokenSwapAmount = uint(amountIn32);
        // tokenSwapAmount = stringToUint(latestMessage);
        // emit TokenSwapAmount(
        //     tokenSwapAmount
        // );
        // // swapExactInputSingle( uint256(amountIn32));
        // emit MessageReceived(
        //     latestMessageId,
        //     latestSourceChainSelector,
        //     latestSender,
        //     latestMessage
        // );

    }

    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        latestMessageId = message.messageId;
        latestSourceChainSelector = message.sourceChainSelector;
        latestSender = abi.decode(message.sender, (address));
        latestMessage = abi.decode(message.data, (string));
        tokenSwapAmount = stringToUint(latestMessage);

        emit MessageReceived(
            latestMessageId,
            latestSourceChainSelector,
            latestSender,
            latestMessage
        );
        swapExactInputSingle( tokenSwapAmount);
    }

    function getLatestMessageDetails()
        public
        view
        returns (bytes32, uint64, address, string memory)
    {
        return (
            latestMessageId,
            latestSourceChainSelector,
            latestSender,
            latestMessage
        );
    }

    function swapExactInputSingle(uint256 amountIn) internal returns (uint256 amountOut) {
        // msg.sender must approve this contract

        // Transfer the specified amount of WETH to this contract.
        // TransferHelper.safeTransferFrom(WETH, _owner, address(this), amountIn);
        TransferHelper.safeTransferFrom(USDC, msg.sender, address(this), amountIn);

        // Approve the router to spend WETH.
        TransferHelper.safeApprove(USDC, address(swapRouter), amountIn);

        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: USDC,
                tokenOut: DAI,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);
    }
}

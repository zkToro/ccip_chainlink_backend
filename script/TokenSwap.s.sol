// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "./Helper.sol";
import {UniswapMessageReceiver} from "../src/UniswapMessageReceiver.sol";
import {BasicMessageSender} from "../src/BasicMessageSender.sol";
import {IBasicMessageSender} from "../src/IBasicMessageSender.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// forge script script/TokenSwap.s.sol:DeployUniswapMessager --rpc-url $POLYGON_MUMBAI_RPC_URL  --chain-id 80001 --private-key $PRIVATE_KEY --broadcast  --etherscan-api-key TF9Y7A6VEMCHD2X4WYXTFYPF5TU77RGPT7 


// forge script script/TokenSwap.s.sol:SendTokensAndData --rpc-url $POLYGON_MUMBAI_RPC_URL  --chain-id 80001 --broadcast  --etherscan-api-key $POLYGON_MUMBAI_ETHERSCAN_TOKEN --private-key $PRIVATE_KEY
// forge script script/TokenSwap.s.sol:DeployUniswapMessager --rpc-url $ETHEREUM_SEPOLIA_RPC_URL  --chain-id 11155111 --broadcast  --etherscan-api-key $ETHEREUM_SEPOLIA_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY
// forge script script/TokenSwap.s.sol:DeploySender --rpc-url $POLYGON_MUMBAI_RPC_URL  --chain-id 80001 --broadcast  --etherscan-api-key $POLYGON_MUMBAI_ETHERSCAN_TOKEN --legacy --private-key $PRIVATE_KEY
// cast send 0x326C977E6efc84E512bB9C30f76E30c160eD06FB "transfer(address,uint256)" 0x7E7EddFB55c3d855d6B17e176b0B70db311Dfc2b 500000000000000000 --rpc-url $POLYGON_MUMBAI_RPC_URL  --etherscan-api-key $POLYGON_MUMBAI_ETHERSCAN_TOKEN --private-key $PRIVATE_KEY --chain-id 80001

// forge script script/TokenSwap.s.sol:DeployUniswapMessager --rpc-url $ETHEREUM_MAINNET_RPC_URL  --chain-id 1 --broadcast  --etherscan-api-key $ETHEREUM_MAINNET_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY


// address constant publicKey = 0xE5E568ad4Eeb316Ac2930eFf406507ad13B71a5b;
// cast send 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 "approve(address,uint256)" 0xE5E568ad4Eeb316Ac2930eFf406507ad13B71a5b 500000000000000000 --rpc-url $ETHEREUM_MAINNET_RPC_URL  --etherscan-api-key $ETHEREUM_MAINNET_ETHERSCAN_TOKEN --private-key $PRIVATE_KEY --chain-id 1

// https://github.com/Uniswap/v3-periphery/blob/v1.0.0/testnet-deploys.md

contract DeployUniswapMessager is Script, Helper {

    function run() external {
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // vm.startBroadcast(deployerPrivateKey);

        

        vm.startBroadcast();
        
        (address ccipRouter, , , ) = getConfigFromNetwork(SupportedNetworks.ETHEREUM_SEPOLIA);

        ISwapRouter uniswapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        UniswapMessageReceiver receiver = new UniswapMessageReceiver(
                ccipRouter, uniswapRouter
            );

        console.log(
            "UniswapMessageReceiver contract deployed on "
            "with address: ",
            address(receiver)
        );

        // am i too childish ? 
        IERC20(receiver.USDC()).approve(address(receiver),10000000000); 
        // the token address will be called by receiver, so set the allowance for receiver

        // IERC20(receiver.USDC()).transferFrom(msg.sender,address(receiver),10);
        // IERC20(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14).approve(ccipRouter,type(uint256).max);
        // IERC20(0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14).approve(address(receiver),type(uint256).max);
        // Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
        //     sender: abi.encode(receiver),
        //     data: abi.encode("21"),
        //     destTokenAmounts: new Client.EVMTokenAmount[](0),
        //     messageId:0x0,
        //     sourceChainSelector: 0
        // });


        string memory message = "3000000";
        receiver.ccipReceiveTest(message);        
        vm.stopBroadcast();

    }
}

contract DeploySender is Script, Helper{
    function run() external {
        vm.startBroadcast();
        (address router,address linkToken , , ) = getConfigFromNetwork(SupportedNetworks.POLYGON_MUMBAI);
        BasicMessageSender sender = new BasicMessageSender(router,linkToken);
        console.log(
            "BasicMessageSender contract deployed on "
            "with address: ",
            address(sender)
        );

        

        vm.stopBroadcast();
    }
}



contract SendTokensAndData is Script, Helper {
    function run(
        // address payable sender,
        // SupportedNetworks destination,
        // address receiver,
        // string memory message,
        // address token,
        // uint256 amount
    ) external {

        // address link = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
        vm.startBroadcast();

        // (address router,address linkToken , , ) = getConfigFromNetwork(SupportedNetworks.POLYGON_MUMBAI);
        (, , , uint64 destChain) = getConfigFromNetwork(SupportedNetworks.ETHEREUM_SEPOLIA);
        address payable sender =  payable(0x7E7EddFB55c3d855d6B17e176b0B70db311Dfc2b);
        address receiver = address(0x6A23D813739801E34E961c2a91C43881dD5C43cc);
        string memory message = "20000000000";
        
        bytes32 messageId = IBasicMessageSender(sender).send(
            destChain,
            receiver,
            message,
            true
        );

        console.log(
            "You can now monitor the status of your Chainlink CCIP Message via https://ccip.chain.link using CCIP Message ID: "
        );
        console.logBytes32(messageId);

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../script/Helper.sol";
import {UniswapMessageReceiver} from "../src/UniswapMessageReceiver.sol";
import {BasicMessageSender} from "../src/BasicMessageSender.sol";
import {IBasicMessageSender} from "../src/IBasicMessageSender.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// forge script script/TokenSwap.s.sol:DeploySender --rpc-url $POLYGON_MUMBAI_RPC_URL  --chain-id 80001 --broadcast  --etherscan-api-key $POLYGON_MUMBAI_ETHERSCAN_TOKEN --legacy --private-key $PRIVATE_KEY

contract TokenSwapTest is Test,Helper {
    UniswapMessageReceiver receiver;
    uint256 senderPrivateKey;
    address owner;
    function setUp() public {

        senderPrivateKey = vm.envUint("PRIVATE_KEY");
        owner = 0xE5E568ad4Eeb316Ac2930eFf406507ad13B71a5b;

        (address router, , , ) = getConfigFromNetwork(SupportedNetworks.ETHEREUM_SEPOLIA);

        ISwapRouter uniswapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        receiver = new UniswapMessageReceiver(
                router, uniswapRouter
            );

        console.log(
            "UniswapMessageReceiver contract deployed on "
            "with address: ",
            address(receiver)
        );
    }

    function test1() public {
        vm.startPrank(owner);
        string memory message = "20000000000";
        console.log("Token received of " ,receiver.ccipReceiveTest(message));
        vm.stopPrank();
    }

    // function test2() public {
    //     assertEq(hello.version(), 0);
    //     hello.updateGreeting("Hello World");
    //     assertEq(hello.version(), 1);
    //     assertEq(hello.greet(), "Hello World");
    // }
}

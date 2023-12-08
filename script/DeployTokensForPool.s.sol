pragma solidity ^0.8.19;

import "../src/ERC20Mint.sol";
import "forge-std/Script.sol";
import "./Helper.sol";


// forge script script/DeployTokensForPool.s.sol:TokenCreation --rpc-url $POLYGON_MUMBAI_RPC_URL  --chain-id 80001 --etherscan-api-key $POLYGON_ETHERSCAN_TOKEN --private-key $PRIVATE_KEY --broadcast --via-ir
// forge script script/DeployTokensForPool.s.sol:TokenCreation --priority-gas-price 0.0001gwei  --rpc-url $OPTIMISM_TESTNET_RPC_URL  --chain-id 420  --etherscan-api-key $OPTIMISM_ETHERSCAN_TOKEN --private-key $PRIVATE_KEY --broadcast
// forge script script/DeployTokensForPool.s.sol:TokenCreation   --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --etherscan-api-key $ETHEREUM_SEPOLIA_ETHERSCAN_TOKEN --private-key $PRIVATE_KEY --broadcast
contract TokenCreation is Script {

    function run() external {
        vm.startBroadcast();

        ERC20Mint toroUSD = new ERC20Mint("toroUSD",'toroUSD');
        ERC20Mint toroWETH = new ERC20Mint("toroWETH",'toroWETH');

        toroUSD.mint(msg.sender, 10**30);
        toroWETH.mint(msg.sender, 10**30);

        console.log("toroUSD: ",address(toroUSD));
        console.log("toroWETH: ",address(toroWETH));

        vm.stopBroadcast();

    }
}
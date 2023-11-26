

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "./Helper.sol";
import "../src/SetProtocol/Controller.sol";
import "../src/SetProtocol/interfaces/IController.sol";
import "../src/SetProtocol/interfaces/ISetToken.sol";
import "../src/SetProtocol/interfaces/IManagerIssuanceHook.sol";
import "../src/SetProtocol/interfaces/IManager.sol";
import "../src/SetProtocol/SetTokenCreator.sol";
import "../src/SetProtocol/Manager.sol";
import "../src/SetProtocol/IntegrationRegistry.sol";
import "../src/SetProtocol/modules/TradeModule.sol";
import "../src/SetProtocol/modules/BasicIssuanceModule.sol";
import {LockReleaseModule} from "../src/SetProtocol/modules/LockReleaseModule.sol";

import "../src/SetProtocol/integration/UniswapV3ExchangeAdapterV2.sol";
import "../src/SetProtocol/lib/ResourceIdentifier.sol";

address constant swapRouterEthereum = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant swapRouterPolygon = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant swapRouterOptimism= 0xE592427A0AEce92De3Edee1F18E0157C05861564;

address constant ccipPolygonRouter  = 0x70499c328e1E2a3c41108bd3730F6670a44595D1;
address constant ccipOptimismRouter = 0xEB52E9Ae4A9Fb37172978642d4C141ef53876f26;

address constant feeRecipient = 0x7033026844F5Ee396996E72F2f9713a00B37Ae96;
string constant name = "Zktoro Genesis Vault";
string  constant symbol = 'TORO1';

uint8 constant decimals_weth = 18;
uint8 constant decimals_usdc = 6;

address constant LinkPOLYGON = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
address constant LinkOptimism = 0xdc2CC710e42857672E7907CF474a69B63B93089f;

address constant aaAddressPolygonFactory = 0x133A011ea872C170cff78264b2782e543275e97F;
address constant aaAddressOptimismFactory = 0xa806f95b6E7419194fa6253b1895F304B4f61cbD;

uint64 constant OptimismChainSelector = 2664363617261496610;

// forge script script/SetProtocolCCIPTest.s.sol:CCIPTest --rpc-url $POLYGON_MUMBAI_RPC_URL  --etherscan-api-key $POLYGON_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY --via-ir --broadcast
contract CCIPTest is Script {

    function run() external {

        // // Action 0
        vm.startBroadcast();


        
        address setTokenPolygon = address(0x056Dc4Ba7795c6cBc989969a61268909C01D1732);

        address setTokenOptimism = address(0x716b43c6975072F1a38C90A1cd1c6ade5332c18B);

        IManager manager = IManager(address(0x3805DE5A9194D757D6Cd44A4fbD463FD1B24Eb86));



        // manager.addToWhitelist(0x8fb67Db825f701d98Ac50327623fccf221c01F15);
        
        address _setToken = address(0);
        string memory  _exchangeName = 'UniswapV3';
        address _sendToken = address(0);
        uint256 _sendQuantity = 0;
        address _receiveToken = address(0);
        uint256 _minReceiveQuantity = 0;  
        uint8 _integrationRegistryID = 0;
        uint24 _poolFee = 3000;
        address _destToken = LinkOptimism; 
        uint256 _destQuantity = 5*10**(decimals_weth-2);  
        uint8 destActionType = 3; //  release 


        address receiver = address(0xcb8115fAE550Ee1A5A70F5a948Ffa3CdE6A988B8);

        bytes memory ccipInfoBytes =  manager.encodeCCIPInfo(_setToken,_exchangeName,_sendToken, _sendQuantity, _receiveToken, _minReceiveQuantity,_integrationRegistryID,
                    _poolFee,_destToken, _destQuantity,destActionType); 
        
        console.logBytes(ccipInfoBytes);
        // IERC20(LinkPOLYGON).transfer(address(manager), 2*10**18 );
        manager.lockAndSend( setTokenPolygon, LinkPOLYGON, _destQuantity, OptimismChainSelector, receiver, ccipInfoBytes, true );
           
        vm.stopBroadcast();
    }
}

// 0xdcc167ac2f8c9cfcb34f06795ad9ef2f4b83dc3a41c4a93db916d9e158870f7c
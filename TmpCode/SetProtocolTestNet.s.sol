// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "./Helper.sol";
import "../src/SetProtocol/Controller.sol";
import "../src/SetProtocol/interfaces/IController.sol";
import "../src/SetProtocol/interfaces/ISetToken.sol";
import "../src/SetProtocol/interfaces/IManagerIssuanceHook.sol";
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


// address constant WETH_POLYGON = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
// address constant USDC_POLYGON = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;

// address constant WETH_OPTIMISM = 0x4200000000000000000000000000000000000006;
// address constant USDC_OPTIMISM = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;

// address constant WETH_ETHEREUM = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
// address constant USDC_ETHEREUM = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

// address constant LinkETHEREUM = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
address constant LinkPOLYGON = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
address constant LinkOptimism = 0xdc2CC710e42857672E7907CF474a69B63B93089f;
address constant GWETHOptimism = 0xdD69DB25F6D620A7baD3023c5d32761D353D3De9;


address constant aaAddressPolygonFactory = 0x133A011ea872C170cff78264b2782e543275e97F;
address constant aaAddressOptimismFactory = 0xa806f95b6E7419194fa6253b1895F304B4f61cbD;

uint64 constant OptimismChainSelector = 2664363617261496610;

// forge script script/TokenSwap.s.sol:DeploySetToken --rpc-url $ETHEREUM_MAINNET_RPC_URL  --chain-id 1  --etherscan-api-key $ETHEREUM_MAINNET_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY

// forge script script/SetProtocol.s.sol:DeploySetTokenSender --rpc-url $POLYGON_MAINNET_RPC_URL  --chain-id 137  --etherscan-api-key $POLYGON_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY



// --via-ir
// Notes : every trade/lock/release on the SetToken is invoked on the setToken itself, so it will handle approve others beautifully




// forge script script/SetProtocol.s.sol:DeploySetTokenSender --rpc-url $POLYGON_MAINNET_RPC_URL  --chain-id 137  --etherscan-api-key $POLYGON_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY --legacy
// Sender consideration
// chain = 0
contract DeploySetTokenSender is Script {

    function run() external {

        vm.startBroadcast();
        uint8 chain = 0; // 0 Pol 1 Opt
        uint256 setTokenQuantity = 10*10**18;

        Controller controller = new Controller(feeRecipient);
        
        IntegrationRegistry integrations = new IntegrationRegistry(IController(address(controller)));
        

        SetTokenCreator creator = new SetTokenCreator(IController(address(controller)));

        TradeModule tradeModule = new TradeModule(IController(address(controller)));
        BasicIssuanceModule basicIssuanceModule = new BasicIssuanceModule(IController(address(controller)));

        LockReleaseModule lockReleaseModule = new LockReleaseModule(IController(address(controller)));

        address[] memory modules = new address[](3);
        modules[0] = address(tradeModule);
        modules[1] = address(basicIssuanceModule);
        modules[2] = address(lockReleaseModule);

        address[] memory factories = new address[](1);
        factories[0] = address(creator);

        address[] memory resources = new address[](1);
        resources[0] = address(integrations);

        uint256[] memory resourcesID = new uint256[](1);
        resourcesID[0] = ResourceIdentifier.INTEGRATION_REGISTRY_RESOURCE_ID;
        
        controller.initialize( factories, modules , resources , resourcesID );

        address[] memory components = new address[](1);
        components[0] = LinkPOLYGON;


        int256[] memory units = new int256[](1);
        units[0] = int256(1*10**18);


        Manager manager = _setUpManager(tradeModule,lockReleaseModule,controller,chain);

        
        address setToken = creator.create(components, units, modules, address(manager), name, symbol);
        
        
        UniswapV3ExchangeAdapterV2 uniswapAdapter = new UniswapV3ExchangeAdapterV2(swapRouterPolygon);

        integrations.addIntegration(address(tradeModule),"UniswapV3",address(uniswapAdapter));
        
        _init(tradeModule, integrations, basicIssuanceModule, setToken, uniswapAdapter,lockReleaseModule);

        manager.regsiterTokenPair(LinkPOLYGON, LinkOptimism);
        // Investor funding
        // setTokenQuantity / 10**18 * (virtual position = real position) 
        // basicIssuanceModule.issue(ISetToken(setToken), setTokenQuantity, msg.sender);
        // Manager action
        
        // ISetToken(setToken).setManager(address(manager));
        
        manager.addToWhitelist(msg.sender);
        // manager.addToWhitelist(aaAddressPolygon);
        // uint256 lockReleaseBufferETHOP = 1*10**(decimals_weth-2);
        // IERC20(WETH_POLYGON).transfer( address(lockReleaseModule) , lockReleaseBufferETHOP );



        
        console.log("Polygon");
        console.log('SetToken address ',setToken);
        console.log('LockReleaseModule address ',address(lockReleaseModule));
        console.log('BasicIssuanceModule address ',address(basicIssuanceModule));
        console.log('TradeModule address ',address(tradeModule));
        console.log('Integrations address ',address(integrations));
        console.log('SetTokenCreator address ',address(creator));
        console.log('Manager address ',address(manager));
        console.log('Controller address ',address(controller));
        


        vm.stopBroadcast();
        
        // lockReleaseModule.lockToken(ISetToken(setToken), WETH_POLYGON, 1*10**(decimals_weth-1));
        // lockReleaseModule.releaseToken(ISetToken(setToken), WETH_POLYGON, 1*10**(decimals_weth-1));

        // vm.stopBroadcast();

    }


    function _setUpManager(TradeModule tradeModule, LockReleaseModule lockReleaseModule, Controller controller, uint8 chain) internal returns(Manager) {
        Manager manager;
        if (chain == 0 ){
             manager = new Manager(address(tradeModule), address(lockReleaseModule), address(controller), ccipPolygonRouter, LinkPOLYGON );    
        }
        else{
             manager = new Manager(address(tradeModule), address(lockReleaseModule), address(controller), ccipOptimismRouter, LinkOptimism );    
        }
        return manager;        
    }

    // TODO approve for token to trade
    // TODO console log poistion change
    function _init(TradeModule tradeModule, IntegrationRegistry integrations, BasicIssuanceModule basicIssuanceModule, address setToken, UniswapV3ExchangeAdapterV2 uniswapAdapter, LockReleaseModule lockReleaseModule ) internal {
        
        tradeModule.initialize(ISetToken(setToken));
        
        // TODO what is pre-issue hook
        basicIssuanceModule.initialize(ISetToken(setToken), IManagerIssuanceHook(address(0)));
        lockReleaseModule.initialize(ISetToken(setToken));

        IERC20(LinkPOLYGON).approve(address(basicIssuanceModule), type(uint256).max );

    }

}







// TODO topup with LINK token for two sides
// TODO delete ccipReceiveTest endpoint during deployment
// Remove Reverse Action as it is not possible. The lock and unlock cannot be ensured in this case.
// The flow doesn't work.
// forge script script/SetProtocol.s.sol:DeploySetTokenReceiver --rpc-url $OPTIMISM_MAINNET_RPC_URL  --chain-id 10  --etherscan-api-key $OPTIMISM_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY --legacy
// forge script script/SetProtocol.s.sol:DeploySetTokenReceiver --rpc-url $ETHEREUM_MAINNET_RPC_URL  --chain-id 1  --etherscan-api-key $ETHEREUM_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY --via-ir  

contract DeploySetTokenReceiver is Script {
    event PositionEvent(address component, address module, int256 unit, uint8 positionState, bytes data);

            
    function run() external {
        vm.startBroadcast();
        // vm.startPrank(msg.sender);
        

        
        uint8 chain = 1; // 0 Pol 1 Opt
        uint256 setTokenQuantity = 10*10**18;

        Controller controller = new Controller(feeRecipient);
        
        IntegrationRegistry integrations = new IntegrationRegistry(IController(address(controller)));

        SetTokenCreator creator = new SetTokenCreator(IController(address(controller)));

        TradeModule tradeModule = new TradeModule(IController(address(controller)));
        BasicIssuanceModule basicIssuanceModule = new BasicIssuanceModule(IController(address(controller)));

        LockReleaseModule lockReleaseModule = new LockReleaseModule(IController(address(controller)));


        

        address[] memory modules = new address[](3);
        modules[0] = address(tradeModule);
        modules[1] = address(basicIssuanceModule);
        modules[2] = address(lockReleaseModule);

        address[] memory factories = new address[](1);
        factories[0] = address(creator);

        address[] memory resources = new address[](1);
        resources[0] = address(integrations);

        uint256[] memory resourcesID = new uint256[](1);
        resourcesID[0] = ResourceIdentifier.INTEGRATION_REGISTRY_RESOURCE_ID;
        
        controller.initialize( factories, modules , resources , resourcesID );

        address[] memory components = new address[](1);
        components[0] = LinkOptimism;
        
        int256[] memory units = new int256[](1);
        units[0] = int256(1*10**18);

        address setToken = creator.create(components, units, modules, msg.sender, name, symbol);
        
        UniswapV3ExchangeAdapterV2 uniswapAdapter = new UniswapV3ExchangeAdapterV2(swapRouterOptimism);

        _init(tradeModule, integrations, basicIssuanceModule, setToken,uniswapAdapter,lockReleaseModule);

        Manager manager = _setUpManager(tradeModule,lockReleaseModule,controller,chain);
        
        // Investor funding
        // setTokenQuantity / 10**18 * (virtual position = real position) 
        basicIssuanceModule.issue(ISetToken(setToken), setTokenQuantity, msg.sender);
        // Manager action
        ISetToken(setToken).setManager(address(manager));
        
        manager.addToWhitelist(msg.sender);
        
        uint256 lockReleaseBufferETHOP = 10*10**(decimals_weth);

        IERC20(LinkOptimism).transfer( address(lockReleaseModule) , lockReleaseBufferETHOP );


        // // Action 0
        // address _setToken = setToken;
        // string memory  _exchangeName = 'UniswapV3';
        // address _sendToken = WETH_OPTIMISM;
        // uint256 _sendQuantity = 3*10**(decimals_weth-1) ;
        // address _receiveToken = USDC_OPTIMISM;
        // uint256 _minReceiveQuantity = 0;  // TODO think of a better parameter here
        // uint8 _integrationRegistryID = uint8(ResourceIdentifier.INTEGRATION_REGISTRY_RESOURCE_ID);
        // uint24 _poolFee = 3000;
        // address _destToken = WETH_OPTIMISM;
        // uint256 _destQuantity = 3*10**(decimals_weth-1);  
        // uint8 destActionType = 0; // release and swap

        // Action 1
        // address _setToken = setToken;
        // string memory  _exchangeName = 'UniswapV3';
        // address _sendToken = USDC_OPTIMISM;
        // uint256 _sendQuantity = 100*10**(decimals_usdc);
        // address _receiveToken = WETH_OPTIMISM;
        // uint256 _minReceiveQuantity = 0;  // TODO think of a better parameter here
        // uint8 _integrationRegistryID = uint8(ResourceIdentifier.INTEGRATION_REGISTRY_RESOURCE_ID);
        // uint24 _poolFee = 3000;
        // address _destToken = WETH_OPTIMISM;
        // uint256 _destQuantity = 3*10**(decimals_weth-3);  
        // uint8 destActionType = 1; // swap and lock

        // bytes memory ccipInfoBytes =  manager.encodeCCIPInfo(_setToken,_exchangeName,_sendToken, _sendQuantity, _receiveToken, _minReceiveQuantity,_integrationRegistryID,
        //             _poolFee,_destToken, _destQuantity,destActionType); 

        // Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
        //     messageId : 0 ,
        //     sourceChainSelector: 0,
        //     sender: abi.encode(address(0)),
        //     data: ccipInfoBytes,
        //     destTokenAmounts: new Client.EVMTokenAmount[](0)
        // });

        // bytes32 messageId; // MessageId corresponding to ccipSend on source.
        // uint64 sourceChainSelector; // Source chain selector.
        // bytes sender; // abi.decode(sender) if coming from an EVM chain.
        // bytes data; // payload sent in original message.
        // EVMTokenAmount[] destTokenAmounts; 

        // manager.ccipReceiveTestCall(message);
        
        console.log("Optimism");
        console.log('SetToken address ',setToken);
        console.log('LockReleaseModule address ',address(lockReleaseModule));
        console.log('BasicIssuanceModule address ',address(basicIssuanceModule));
        console.log('TradeModule address ',address(tradeModule));
        console.log('Integrations address ',address(integrations));
        console.log('SetTokenCreator address ',address(creator));
        console.log('Manager address ',address(manager));
        console.log('Controller address ',address(controller));
        
        
        // lockReleaseModule.lockToken(ISetToken(setToken), WETH_POLYGON, 1*10**(decimals_weth-1));
        // lockReleaseModule.releaseToken(ISetToken(setToken), WETH_POLYGON, 1*10**(decimals_weth-1));

        vm.stopBroadcast();

    }

    function _setUpManager(TradeModule tradeModule, LockReleaseModule lockReleaseModule, Controller controller, uint8 chain) internal returns(Manager) {
        Manager manager;
        if (chain == 0 ){
             manager = new Manager(address(tradeModule), address(lockReleaseModule), address(controller), ccipPolygonRouter, LinkPOLYGON );    
        }
        else{
             manager = new Manager(address(tradeModule), address(lockReleaseModule), address(controller), ccipOptimismRouter, LinkOptimism );    
        }
        return manager;        
    }

    // TODO approve for token to trade
    // TODO console log poistion change
    function _init(TradeModule tradeModule, IntegrationRegistry integrations, BasicIssuanceModule basicIssuanceModule, address setToken, UniswapV3ExchangeAdapterV2 uniswapAdapter, LockReleaseModule lockReleaseModule ) internal {
        
        tradeModule.initialize(ISetToken(setToken));
        integrations.addIntegration(address(tradeModule),"UniswapV3",address(uniswapAdapter));
        // TODO what is pre-issue hook
        basicIssuanceModule.initialize(ISetToken(setToken), IManagerIssuanceHook(address(0)));
        lockReleaseModule.initialize(ISetToken(setToken));        
        
        
        
    }

}


//   Polygon
//   SetToken address  0x056Dc4Ba7795c6cBc989969a61268909C01D1732
//   LockReleaseModule address  0x0d30c5f7AcF5fcd983877730133c7F991A095589
//   BasicIssuanceModule address  0xF59737E626F0ecFA9E2A29b112928c9aa51e4922
//   TradeModule address  0xB049A6Cf22d4f3d0C53f484A8568e3BD883cEb46
//   Integrations address  0xd594cF3dF8D47df06F53b3f0b17206243409461d
//   SetTokenCreator address  0x9345E20E79d63cAd014E2b9ab52A3Cb4BEc2890e
//   Manager address  0x3805DE5A9194D757D6Cd44A4fbD463FD1B24Eb86
//   Controller address  0xF28dC0d702Fb237e57a5291B3bE16835f39aAd44

//   Optimism
//   SetToken address  0x716b43c6975072F1a38C90A1cd1c6ade5332c18B
//   LockReleaseModule address  0x69D3b34aB349d903E6947Ab89bB54c26bA511676
//   BasicIssuanceModule address  0xbf91526883A661F6ef7952539521f681fBb0Ab59
//   TradeModule address  0x0407BC8B41775EC42096E0F6614d9C28AFC107BA
//   Integrations address  0xEc7028700E61970175680aF6C45fA2CD9e9E4b8b
//   SetTokenCreator address  0xF1f42e72B515E12A69B3504a637E0a28e30A7549
//   Manager address  0xcb8115fAE550Ee1A5A70F5a948Ffa3CdE6A988B8
//   Controller address  0x2FA2d48c440c7F2DEbD05E1935Fa930b62905000



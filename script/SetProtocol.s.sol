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

address constant ccipPolygonRouter  = 0x3C3D92629A02a8D95D5CB9650fe49C3544f69B43;
address constant ccipOptimismRouter = 0x261c05167db67B2b619f9d312e0753f3721ad6E8;

address constant feeRecipient = 0x7033026844F5Ee396996E72F2f9713a00B37Ae96;
string constant name = "Zktoro Genesis Vault";
string  constant symbol = 'TORO1';

uint8 constant decimals_weth = 18;
uint8 constant decimals_usdc = 6;

address constant WETH_POLYGON = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
address constant USDC_POLYGON = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;

address constant WETH_OPTIMISM = 0x4200000000000000000000000000000000000006;
address constant USDC_OPTIMISM = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;

address constant WETH_ETHEREUM = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant USDC_ETHEREUM = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

address constant LinkETHEREUM = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
address constant LinkPOLYGON = 0xb0897686c545045aFc77CF20eC7A532E3120E0F1;
address constant LinkOptimism = 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6;
address constant aaAddressPolygon = 0xB20087b690E817ce47f63c1f431397Bd40CE1c54;
address constant aaAddressOptimism = 0x4349aA3A85127a63C34608a64e6F46ffadAbD614;
uint64 constant OptimismChainSelector = 3734403246176062136;

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
        uint256 setTokenQuantity = 1*10**16;

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

        address[] memory components = new address[](2);
        components[0] = WETH_POLYGON;
        components[1] = USDC_POLYGON;

        int256[] memory units = new int256[](2);
        units[0] = int256(1*10**decimals_weth);
        units[1] = int256(1200*10**decimals_usdc);

        address setToken = creator.create(components, units, modules, msg.sender, name, symbol);
        
        UniswapV3ExchangeAdapterV2 uniswapAdapter = new UniswapV3ExchangeAdapterV2(swapRouterPolygon);

        _init(tradeModule, integrations, basicIssuanceModule, setToken, uniswapAdapter,lockReleaseModule);

        Manager manager = _setUpManager(tradeModule,lockReleaseModule,controller,chain);
        manager.regsiterTokenPair(WETH_POLYGON, WETH_OPTIMISM);
        manager.regsiterTokenPair(USDC_POLYGON, USDC_OPTIMISM);
        // Investor funding
        // setTokenQuantity / 10**18 * (virtual position = real position) 
        basicIssuanceModule.issue(ISetToken(setToken), setTokenQuantity, msg.sender);
        // Manager action
        ISetToken(setToken).setManager(address(manager));
        
        manager.addToWhitelist(msg.sender);
        manager.addToWhitelist(aaAddressPolygon);
        // uint256 lockReleaseBufferETHOP = 1*10**(decimals_weth-2);
        // IERC20(WETH_POLYGON).transfer( address(lockReleaseModule) , lockReleaseBufferETHOP );


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
        // uint8 destActionType = 0; //  release and swap

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


        // address receiver = address(0x0);

        // bytes memory ccipInfoBytes =  manager.encodeCCIPInfo(_setToken,_exchangeName,_sendToken, _sendQuantity, _receiveToken, _minReceiveQuantity,_integrationRegistryID,
        //             _poolFee,_destToken, _destQuantity,destActionType); 

        // manager.lockAndSend(_setToken, WETH_POLYGON, _destQuantity, OptimismChainSelector, receiver, ccipInfoBytes, false );
        
        console.log("Polygon");
        console.log('SetToken address ',setToken);
        console.log('LockReleaseModule address ',address(lockReleaseModule));
        console.log('Manager address ',address(manager));
        console.log('BasicIssuanceModule address ',address(basicIssuanceModule));
        console.log('UniswapAdapter address ',address(uniswapAdapter));


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
        integrations.addIntegration(address(tradeModule),"UniswapV3",address(uniswapAdapter));
        // TODO what is pre-issue hook
        basicIssuanceModule.initialize(ISetToken(setToken), IManagerIssuanceHook(address(0)));
        lockReleaseModule.initialize(ISetToken(setToken));

        IERC20(WETH_POLYGON).approve(address(basicIssuanceModule), type(uint256).max );
        IERC20(USDC_POLYGON).approve(address(basicIssuanceModule), type(uint256).max );

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
        uint256 setTokenQuantity = 1*10**15;

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

        address[] memory components = new address[](2);
        components[0] = WETH_OPTIMISM;
        components[1] = USDC_OPTIMISM;

        int256[] memory units = new int256[](2);
        units[0] = int256(1*10**decimals_weth);
        units[1] = int256(1200*10**decimals_usdc);

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
        manager.addToWhitelist(aaAddressOptimism);
        uint256 lockReleaseBufferETHOP = 1*10**(decimals_weth-3);
        IERC20(WETH_OPTIMISM).transfer( address(lockReleaseModule) , lockReleaseBufferETHOP );


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
        console.log('Manager address ',address(manager));
        console.log('BasicIssuanceModule address ',address(basicIssuanceModule));
        
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

        IERC20(WETH_OPTIMISM).approve(address(basicIssuanceModule), type(uint256).max );
        IERC20(USDC_OPTIMISM).approve(address(basicIssuanceModule), type(uint256).max );

    }

    function _swap(BasicIssuanceModule basicIssuanceModule , address setToken, TradeModule tradeModule, UniswapV3ExchangeAdapterV2 uniswapAdapter ) internal {
        uint256 setTokenQuantity = 1*10**16;
        basicIssuanceModule.issue(ISetToken(setToken), setTokenQuantity, msg.sender);
        console.log("Total Toro Vault Token minted now: ", ISetToken(setToken).totalSupply());
        

        address[] memory paths = new address[](2);
        paths[0] = USDC_ETHEREUM;
        paths[1] = WETH_ETHEREUM;

        uint24[] memory fees = new uint24[](1);
        fees[0] = 3000;        

        bytes memory callData = uniswapAdapter.generateDataParam(paths, fees, true);
        tradeModule.trade(ISetToken(setToken), "UniswapV3" , USDC_ETHEREUM, 10*10**decimals_usdc, WETH_ETHEREUM, 10**(decimals_weth - 3) ,callData );

        console.log("After Swap");
        ISetToken.Position[] memory posList = ISetToken(setToken).getPositions();
        for (uint i = 0; i < posList.length; i++){
            // emit PositionEvent(posList[i].component, posList[i].module, posList[i].unit, posList[i].positionState, posList[i].data);
            console.log("Token: ",posList[i].component);
            console.log("Token unit per share");
            console.logInt(posList[i].unit);
        }
        basicIssuanceModule.redeem(ISetToken(setToken), setTokenQuantity/2, msg.sender);
        console.log("Half of vault value redeemed ");
        console.log("Total Toro Valut Token remaining now: ", ISetToken(setToken).totalSupply());
    }
}
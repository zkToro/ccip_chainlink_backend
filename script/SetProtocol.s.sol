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
import "../src/SetProtocol/integration/UniswapV302ExchangeAdapterV2.sol";
import "../src/SetProtocol/lib/ResourceIdentifier.sol";



address constant swapRouterEthereum = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant swapRouterPolygon = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
// address constant swapRouterOptimism= 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant swapRouterOptimism= 0xE592427A0AEce92De3Edee1F18E0157C05861564;

address constant swapRouterAvalanche= 0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE;

address constant ccipPolygonRouter  = 0x3C3D92629A02a8D95D5CB9650fe49C3544f69B43;
address constant ccipOptimismRouter = 0x261c05167db67B2b619f9d312e0753f3721ad6E8;
address constant ccipAvalancheRouter = 0x27F39D0af3303703750D4001fCc1844c6491563c;


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

address constant WETH_AVALANCHE = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
address constant USDC_AVALANCHE = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

address constant LinkETHEREUM = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
address constant LinkPOLYGON = 0xb0897686c545045aFc77CF20eC7A532E3120E0F1;
address constant LinkOptimism = 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6;
address constant LinkAvalanche = 0x5947BB275c521040051D82396192181b413227A3;



// address constant aaAddressPolygon = 0xB20087b690E817ce47f63c1f431397Bd40CE1c54;
// address constant aaAddressOptimism = 0x4349aA3A85127a63C34608a64e6F46ffadAbD614;

uint64 constant OptimismChainSelector = 3734403246176062136;
uint64 constant PolygonChainSelector = 4051577828743386545;
uint64 constant AvalancheChainSelector = 6433500567565415381;
// forge script script/TokenSwap.s.sol:DeploySetToken --rpc-url $ETHEREUM_MAINNET_RPC_URL  --chain-id 1  --etherscan-api-key $ETHEREUM_MAINNET_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY

// forge script script/SetProtocol.s.sol:DeploySetTokenSender --rpc-url $POLYGON_MAINNET_RPC_URL  --chain-id 137  --etherscan-api-key $POLYGON_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY



// --via-ir
// Notes : every trade/lock/release on the SetToken is invoked on the setToken itself, so it will handle approve others beautifully




// forge script script/SetProtocol.s.sol:DeploySetTokenSender --rpc-url $POLYGON_MAINNET_RPC_URL  --chain-id 137  --etherscan-api-key $POLYGON_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY 
// Sender consideration
// chain = 0

contract DeploySetTokenSender is Script {

    function run() external {

        vm.startBroadcast();
        Controller controller = new Controller(feeRecipient);
        
        IntegrationRegistry integrations = new IntegrationRegistry(IController(address(controller)));

        SetTokenCreator creator = new SetTokenCreator(IController(address(controller)));

        TradeModule tradeModule = new TradeModule(IController(address(controller)));
        BasicIssuanceModule basicIssuanceModule = new BasicIssuanceModule(IController(address(controller)));

        LockReleaseModule lockReleaseModule = new LockReleaseModule(IController(address(controller)));

        Manager manager = new Manager(address(tradeModule), address(lockReleaseModule), address(controller),
                                    address(creator) , address(basicIssuanceModule) , ccipPolygonRouter, LinkPOLYGON );
        
        manager.regsiterTokenPair(WETH_POLYGON, WETH_AVALANCHE);
        manager.regsiterTokenPair(USDC_POLYGON, USDC_AVALANCHE);

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

        address setToken = manager.createSetToken(components, units, name, symbol);
        
        UniswapV3ExchangeAdapterV2 uniswapAdapter = new UniswapV3ExchangeAdapterV2(swapRouterPolygon);
        integrations.addIntegration(address(tradeModule),"UniswapV3",address(uniswapAdapter));

        // _init(tradeModule, integrations, basicIssuanceModule, setToken,uniswapAdapter,lockReleaseModule);
        manager.addToWhitelist(msg.sender);

        // basicIssuanceModule.issue(ISetToken(setToken), setTokenQuantity, msg.sender);

        uint256 lockReleaseBufferETHPol = 1*10**(decimals_weth-3);
        IERC20(WETH_POLYGON).transfer( address(lockReleaseModule) , lockReleaseBufferETHPol );
    
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
        
    }
}



//   Polygon
//   SetToken address  0x670EcAD39ED80d0af15050eE7119Bb53f8F702Ce
//   LockReleaseModule address  0x6Ec9E796b7AE7020D0fb32CD53cF684c649dFc81
//   BasicIssuanceModule address  0x3Ca4FcD8239576F35cE8dc242ba7Bd740c3472c1
//   TradeModule address  0x376F3FD475765b2D2Fef3BC362CDafb01686f3ea
//   Integrations address  0x307E3a426bc295C6dd86edF80361e66D84198cb7
//   SetTokenCreator address  0x3cCB840fAe596926C5Ebc5369E0c3AB4a7e92389
//   Manager address  0x7295CEE2CfDEBa4451dF11e4d42ad4E0Bf476b6A
//   Controller address  0x6A23D813739801E34E961c2a91C43881dD5C43cc



// TODO topup with LINK token for two sides
// Remove Reverse Action as it is not possible. The lock and unlock cannot be ensured in this case.
// The flow doesn't work.
// forge script script/SetProtocol.s.sol:DeploySetTokenReceiver --rpc-url $AVALANCHE_MAINNET_RPC_URL  --chain-id 43114  --private-key $PRIVATE_KEY  

contract DeploySetTokenReceiver is Script {
    event PositionEvent(address component, address module, int256 unit, uint8 positionState, bytes data);

            
    function run() external {
        vm.startBroadcast();
        // vm.startPrank(msg.sender);
        
        
        // uint256 setTokenQuantity = 1*10**15;

        Controller controller = new Controller(feeRecipient);
        
        IntegrationRegistry integrations = new IntegrationRegistry(IController(address(controller)));

        SetTokenCreator creator = new SetTokenCreator(IController(address(controller)));

        TradeModule tradeModule = new TradeModule(IController(address(controller)));
        BasicIssuanceModule basicIssuanceModule = new BasicIssuanceModule(IController(address(controller)));

        LockReleaseModule lockReleaseModule = new LockReleaseModule(IController(address(controller)));

        Manager manager = new Manager(address(tradeModule), address(lockReleaseModule), address(controller),
                                    address(creator) , address(basicIssuanceModule) , ccipOptimismRouter, LinkAvalanche );
        
        manager.regsiterTokenPair(WETH_POLYGON, WETH_AVALANCHE);
        manager.regsiterTokenPair(USDC_POLYGON, USDC_AVALANCHE);

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
        components[0] = WETH_AVALANCHE;
        components[1] = USDC_AVALANCHE;

        int256[] memory units = new int256[](2);
        units[0] = int256(1*10**decimals_weth);
        units[1] = int256(1200*10**decimals_usdc);

        address setToken = manager.createSetToken(components, units, name, symbol);
        
        UniswapV302ExchangeAdapterV2 uniswapAdapter = new UniswapV302ExchangeAdapterV2(swapRouterAvalanche);
        integrations.addIntegration(address(tradeModule),"UniswapV3",address(uniswapAdapter));

        // _init(tradeModule, integrations, basicIssuanceModule, setToken,uniswapAdapter,lockReleaseModule);
        manager.addToWhitelist(msg.sender);

        // basicIssuanceModule.issue(ISetToken(setToken), setTokenQuantity, msg.sender);

        uint256 lockReleaseBufferETHAvax = 1*10**(decimals_weth-3);
        IERC20(WETH_AVALANCHE).transfer( address(lockReleaseModule) , lockReleaseBufferETHAvax );

        // IERC20(USDC_AVALANCHE).approve(address(basicIssuanceModule), type(uint256).max);
        // IERC20(WETH_AVALANCHE).approve(address(basicIssuanceModule), type(uint256).max);
                
        console.log("Avalanche");
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

        // _swap(basicIssuanceModule, setToken, manager );

        vm.stopBroadcast();

    }

    function _swap(BasicIssuanceModule basicIssuanceModule , address setToken,  Manager manager ) internal {
        uint256 setTokenQuantity = 1*10**16;
        basicIssuanceModule.issue(ISetToken(setToken), setTokenQuantity, msg.sender);
        console.log("Total Toro Vault Token minted now: ", ISetToken(setToken).totalSupply());
        
        // address[] memory paths = new address[](2);
        // paths[0] = USDC_AVALANCHE;
        // paths[1] = WETH_AVALANCHE;

        // uint24[] memory fees = new uint24[](1);
        // fees[0] = 500;        

        // bytes memory callData = uniswapAdapter.generateDataParam(paths, fees, true);
        manager.swap(setToken, "UniswapV3" , USDC_AVALANCHE, 10*10**decimals_usdc, WETH_AVALANCHE, 10**(decimals_weth - 3) , 0  , 500);

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

//   Avalanche
//   SetToken address  0x6603821B365A86d578Ce04DEA116262D8726331E
//   LockReleaseModule address  0x376F3FD475765b2D2Fef3BC362CDafb01686f3ea
//   BasicIssuanceModule address  0x3cCB840fAe596926C5Ebc5369E0c3AB4a7e92389
//   TradeModule address  0x307E3a426bc295C6dd86edF80361e66D84198cb7
//   Integrations address  0xB20087b690E817ce47f63c1f431397Bd40CE1c54
//   SetTokenCreator address  0x6A23D813739801E34E961c2a91C43881dD5C43cc
//   Manager address  0x3Ca4FcD8239576F35cE8dc242ba7Bd740c3472c1
//   Controller address  0x4349aA3A85127a63C34608a64e6F46ffadAbD614


// forge script script/SetProtocol.s.sol:DeploySetTokenReceiverOP --rpc-url $OPTIMISM_MAINNET_RPC_URL  --chain-id 10  --etherscan-api-key $OPTIMISM_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY 
contract DeploySetTokenReceiverOP is Script {
    event PositionEvent(address component, address module, int256 unit, uint8 positionState, bytes data);

            
    function run() external {
        vm.startBroadcast();
        // vm.startPrank(msg.sender);
        
        
        // uint256 setTokenQuantity = 1*10**15;

        Controller controller = new Controller(feeRecipient);
        
        IntegrationRegistry integrations = new IntegrationRegistry(IController(address(controller)));

        SetTokenCreator creator = new SetTokenCreator(IController(address(controller)));

        TradeModule tradeModule = new TradeModule(IController(address(controller)));
        BasicIssuanceModule basicIssuanceModule = new BasicIssuanceModule(IController(address(controller)));

        LockReleaseModule lockReleaseModule = new LockReleaseModule(IController(address(controller)));

        Manager manager = new Manager(address(tradeModule), address(lockReleaseModule), address(controller),
                                    address(creator) , address(basicIssuanceModule) , ccipOptimismRouter, LinkOptimism );
        
        manager.regsiterTokenPair(WETH_POLYGON, WETH_OPTIMISM);
        manager.regsiterTokenPair(USDC_POLYGON, USDC_OPTIMISM);

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

        address setToken = manager.createSetToken(components, units, name, symbol);
        
        UniswapV302ExchangeAdapterV2 uniswapAdapter = new UniswapV302ExchangeAdapterV2(swapRouterOptimism);
        integrations.addIntegration(address(tradeModule),"UniswapV3",address(uniswapAdapter));

        // _init(tradeModule, integrations, basicIssuanceModule, setToken,uniswapAdapter,lockReleaseModule);
        manager.addToWhitelist(msg.sender);
        // basicIssuanceModule.issue(ISetToken(setToken), setTokenQuantity, msg.sender);
        uint256 lockReleaseBufferETHAvax = 1*10**(decimals_weth-3);
        IERC20(WETH_OPTIMISM).transfer( address(lockReleaseModule) , lockReleaseBufferETHAvax );

        IERC20(USDC_OPTIMISM).approve(address(basicIssuanceModule), type(uint256).max);
        IERC20(WETH_OPTIMISM).approve(address(basicIssuanceModule), type(uint256).max);
                
        console.log("OPTIMISM");
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

        _swap(basicIssuanceModule, setToken, manager );

        vm.stopBroadcast();

    }

    function _swap(BasicIssuanceModule basicIssuanceModule , address setToken,  Manager manager ) internal {
        uint256 setTokenQuantity = 1*10**16;
        basicIssuanceModule.issue(ISetToken(setToken), setTokenQuantity, msg.sender);
        console.log("Total Toro Vault Token minted now: ", ISetToken(setToken).totalSupply());
        
        manager.swap(setToken, "UniswapV3" , USDC_OPTIMISM, 10*10**decimals_usdc, WETH_OPTIMISM, 10**(decimals_weth - 3) , 0  , 500);

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
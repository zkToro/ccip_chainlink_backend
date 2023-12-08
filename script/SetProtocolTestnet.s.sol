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
import "../src/SetProtocol/integration/UniswapV302ExchangeAdapterV2.sol";
import "../src/SetProtocol/lib/ResourceIdentifier.sol";
import "../src/verifier.sol";




address constant swapRouterPolygon = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant swapRouterSEPOLIA= 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;

address constant ccipPolygonRouter  = 0x70499c328e1E2a3c41108bd3730F6670a44595D1;
address constant ccipSEPOLIARouter = 0xD0daae2231E9CB96b94C8512223533293C3693Bf;

address constant feeRecipient = 0x7033026844F5Ee396996E72F2f9713a00B37Ae96;

uint8 constant decimals_weth = 18;
uint8 constant decimals_usdc = 18;

string constant name = "Zktoro Genesis Vault";
string  constant symbol = 'TORO1';


address constant WETH_POLYGON = 0xf471d9D3AEe379Ed024D796413503527a3Be12ad;
address constant USDC_POLYGON = 0x26fE521ae8424902055732ec5dcdbf4AB47cC9a0;

address constant WETH_SEPOLIA = 0x3722df51cD13F0393d239761591C296c8733DE15;
address constant USDC_SEPOLIA = 0xf607B132550Af445B049DD85Df36A0676332d545;

// address constant WETH_ETHEREUM = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
// address constant USDC_ETHEREUM = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

// address constant LinkETHEREUM = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
address constant LinkPOLYGON = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
address constant LinkSEPOLIA = 0x779877A7B0D9E8603169DdbD7836e478b4624789;


// address constant aaAddressPolygonFactory = 0x133A011ea872C170cff78264b2782e543275e97F;
// address constant aaAddressSEPOLIAFactory = 0xa806f95b6E7419194fa6253b1895F304B4f61cbD;

uint64 constant SEPOLIAChainSelector = 16015286601757825753;
uint64 constant PolygonChainSelector = 12532609583862916517;


// forge script script/SetProtocolTestnet.s.sol:ManagerWhiteList --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --etherscan-api-key $ETHEREUM_ETHERSCAN_TOKEN --private-key $PRIVATE_KEY --via-ir --broadcast 
// forge script script/SetProtocolTestnet.s.sol:ManagerWhiteList --rpc-url $POLYGON_MUMBAI_RPC_URL  --chain-id 80001  --etherscan-api-key $POLYGON_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY --via-ir --broadcast
contract ManagerWhiteList is Script {

    function run() external {
        vm.startBroadcast();
        IManager manager = IManager(0x72723E18D14F49741ef76aD2ca536B3c3c94864B);
        manager.addToWhitelist(0x511A0d10aF066A32D579B42b9076522cC526a5a1);

        vm.stopBroadcast();
    }
}


// forge script script/SetProtocolTestnet.s.sol:verfierDeployment --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --etherscan-api-key $ETHEREUM_ETHERSCAN_TOKEN --private-key $PRIVATE_KEY --via-ir --broadcast 
// forge script script/SetProtocolTestnet.s.sol:verfierDeployment --rpc-url $POLYGON_MUMBAI_RPC_URL  --chain-id 80001  --etherscan-api-key $POLYGON_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY --via-ir --broadcast
contract verfierDeployment is Script {
        function run() external {
        vm.startBroadcast();
        PlonkVerifier verifier = new PlonkVerifier();

        vm.stopBroadcast();
    }

}

// forge script script/SetProtocolTestnet.s.sol:DeploySetTokenSender --rpc-url $POLYGON_MUMBAI_RPC_URL  --chain-id 80001  --etherscan-api-key $POLYGON_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY --via-ir 
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
        
        manager.regsiterTokenPair(WETH_POLYGON, WETH_SEPOLIA);
        manager.regsiterTokenPair(USDC_POLYGON, USDC_SEPOLIA);

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
        units[1] = int256(2000*10**decimals_usdc);

        address setToken = manager.createSetToken(components, units, name, symbol);
        
        UniswapV3ExchangeAdapterV2 uniswapAdapter = new UniswapV3ExchangeAdapterV2(swapRouterPolygon);
        integrations.addIntegration(address(tradeModule),"UniswapV3",address(uniswapAdapter));

        // _init(tradeModule, integrations, basicIssuanceModule, setToken,uniswapAdapter,lockReleaseModule);
        manager.addToWhitelist(msg.sender);

        // basicIssuanceModule.issue(ISetToken(setToken), setTokenQuantity, msg.sender);

        uint256 lockReleaseBufferETHPol = 1000*10**(decimals_weth);
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
// forge script script/SetProtocol.s.sol:DeploySetTokenReceiver --rpc-url $SEPOLIA_MAINNET_RPC_URL  --chain-id 43114  --private-key $PRIVATE_KEY  



// forge script script/SetProtocolTestnet.s.sol:DeploySetTokenReceiverSepolia --rpc-url $ETHEREUM_SEPOLIA_RPC_URL --etherscan-api-key $ETHEREUM_ETHERSCAN_TOKEN --private-key $PRIVATE_KEY --via-ir
contract DeploySetTokenReceiverSepolia is Script {
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
                                    address(creator) , address(basicIssuanceModule) , ccipSEPOLIARouter, LinkSEPOLIA );
        
        manager.regsiterTokenPair(WETH_POLYGON, WETH_SEPOLIA);
        manager.regsiterTokenPair(USDC_POLYGON, USDC_SEPOLIA);

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
        components[0] = WETH_SEPOLIA;
        components[1] = USDC_SEPOLIA;

        int256[] memory units = new int256[](2);
        units[0] = int256(1*10**decimals_weth);
        units[1] = int256(2000*10**decimals_usdc);

        address setToken = manager.createSetToken(components, units, name, symbol);
        
        UniswapV302ExchangeAdapterV2 uniswapAdapter = new UniswapV302ExchangeAdapterV2(swapRouterSEPOLIA);
        integrations.addIntegration(address(tradeModule),"UniswapV3",address(uniswapAdapter));

        // _init(tradeModule, integrations, basicIssuanceModule, setToken,uniswapAdapter,lockReleaseModule);
        manager.addToWhitelist(msg.sender);
        // basicIssuanceModule.issue(ISetToken(setToken), setTokenQuantity, msg.sender);
        uint256 lockReleaseBufferETH = 1000*10**(decimals_weth);

        IERC20(WETH_SEPOLIA).transfer( address(lockReleaseModule) , lockReleaseBufferETH );
        IERC20(USDC_SEPOLIA).approve(address(basicIssuanceModule), type(uint256).max);
        IERC20(WETH_SEPOLIA).approve(address(basicIssuanceModule), type(uint256).max);
                
        console.log("SEPOLIA");
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
        uint256 setTokenQuantity = 1*10**20;
        basicIssuanceModule.issue(ISetToken(setToken), setTokenQuantity, msg.sender);
        console.log("Total Toro Vault Token minted now: ", ISetToken(setToken).totalSupply());
        
        manager.swap(setToken, "UniswapV3" , USDC_SEPOLIA, 1000*10**decimals_usdc, WETH_SEPOLIA, 10**(decimals_weth - 3) , 0  , 3000);

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


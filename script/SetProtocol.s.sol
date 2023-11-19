// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "./Helper.sol";
import "../src/SetProtocol/Controller.sol";
import "../src/SetProtocol/interfaces/IController.sol";
import "../src/SetProtocol/interfaces/ISetToken.sol";
import "../src/SetProtocol/interfaces/IManagerIssuanceHook.sol";
import "../src/SetProtocol/SetTokenCreator.sol";
import "../src/SetProtocol/IntegrationRegistry.sol";
import "../src/SetProtocol/modules/TradeModule.sol";
import "../src/SetProtocol/modules/BasicIssuanceModule.sol";
import "../src/SetProtocol/integration/UniswapV3ExchangeAdapterV2.sol";
import "../src/SetProtocol/lib/ResourceIdentifier.sol";



address constant swapRouterEthereum = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant feeRecipient = 0x7033026844F5Ee396996E72F2f9713a00B37Ae96;
string constant name = "Zktoro Genesis Vault";
string  constant symbol = 'TORO1';

uint8 constant decimals_weth = 18;
uint8 constant decimals_usdc = 6;
address constant WETH_POLYGON = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
address constant USDC_POLYGON = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
address constant WETH_ETHEREUM = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant USDC_ETHEREUM = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
// forge script script/TokenSwap.s.sol:DeploySetToken --rpc-url $ETHEREUM_MAINNET_RPC_URL  --chain-id 1  --etherscan-api-key $ETHEREUM_MAINNET_ETHERSCAN_TOKEN  --private-key $PRIVATE_KEY

contract DeploySetToken is Script {
    event PositionEvent(address component, address module, int256 unit, uint8 positionState, bytes data);

            
    function run() external {
        vm.startBroadcast();
        // vm.startPrank(msg.sender);

        

        Controller controller = new Controller(feeRecipient);
        
        IntegrationRegistry integrations = new IntegrationRegistry(IController(address(controller)));

        SetTokenCreator creator = new SetTokenCreator(IController(address(controller)));

        TradeModule tradeModule = new TradeModule(IController(address(controller)));
        BasicIssuanceModule basicIssuanceModule = new BasicIssuanceModule(IController(address(controller)));

        address[] memory modules = new address[](2);
        modules[0] = address(tradeModule);
        modules[1] = address(basicIssuanceModule);
        address[] memory factories = new address[](1);
        factories[0] = address(creator);

        address[] memory resources = new address[](1);
        resources[0] = address(integrations);

        uint256[] memory resourcesID = new uint256[](1);
        resourcesID[0] = ResourceIdentifier.INTEGRATION_REGISTRY_RESOURCE_ID;
        
        controller.initialize( factories, modules , resources , resourcesID );




        address[] memory components = new address[](2);
        components[0] = WETH_ETHEREUM;
        components[1] = USDC_ETHEREUM;

        int256[] memory units = new int256[](2);
        units[0] = int256(1*10**decimals_weth);
        units[1] = int256(1200*10**decimals_usdc);

        
        address manager = msg.sender;


        address setToken = creator.create(components, units, modules, manager, name, symbol);

        UniswapV3ExchangeAdapterV2 uniswapAdapter = new UniswapV3ExchangeAdapterV2(swapRouterEthereum);

        _prep(tradeModule, integrations, basicIssuanceModule, setToken,uniswapAdapter);
        _swap(basicIssuanceModule, setToken, tradeModule,uniswapAdapter);

        vm.stopBroadcast();

    }

    function _prep(TradeModule tradeModule, IntegrationRegistry integrations, BasicIssuanceModule basicIssuanceModule, address setToken, UniswapV3ExchangeAdapterV2 uniswapAdapter ) internal {
        
        ISetToken.Position[] memory posList = ISetToken(setToken).getPositions();
        for (uint i = 0; i < posList.length; i++){
            // emit PositionEvent(posList[i].component, posList[i].module, posList[i].unit, posList[i].positionState, posList[i].data);
            console.log("Token: ",posList[i].component);
            console.log("Token unit per share");
            console.logInt(posList[i].unit);
            
        }
        tradeModule.initialize(ISetToken(setToken));
        integrations.addIntegration(address(tradeModule),"UniswapV3",address(uniswapAdapter));
        // TODO what is pre-issue hook
        basicIssuanceModule.initialize(ISetToken(setToken), IManagerIssuanceHook(address(0)));

        IERC20(WETH_ETHEREUM).approve(address(basicIssuanceModule), type(uint256).max );
        IERC20(USDC_ETHEREUM).approve(address(basicIssuanceModule), type(uint256).max );
    }

    function _swap(BasicIssuanceModule basicIssuanceModule , address setToken, TradeModule tradeModule, UniswapV3ExchangeAdapterV2 uniswapAdapter ) internal {
        uint256 setTokenQuantity = 1*10**16;
        basicIssuanceModule.issue(ISetToken(setToken), setTokenQuantity, msg.sender);
        console.log("Total Toro Valut Token minted now: ", ISetToken(setToken).totalSupply());
        

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
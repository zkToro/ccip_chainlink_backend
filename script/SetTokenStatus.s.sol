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

contract SetTokenStatusCheck is Script {
    
    function run() external {

        ISetToken setToken = ISetToken(0x056Dc4Ba7795c6cBc989969a61268909C01D1732);

        ISetToken.Position[] memory posList = setToken.getPositions();
        for (uint i = 0; i < posList.length; i++){
            // emit PositionEvent(posList[i].component, posList[i].module, posList[i].unit, posList[i].positionState, posList[i].data);
            console.log("Token: ",posList[i].component);
            console.log("Token unit per share");
            console.logInt(posList[i].unit);
        }
    }

}
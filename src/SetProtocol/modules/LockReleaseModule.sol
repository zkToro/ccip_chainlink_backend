// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { PreciseUnitMath } from "../lib/PreciseUnitMath.sol";

import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/token/ERC20/IERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {Withdraw} from "./utils/Withdraw.sol";
import {ModuleBase} from "./ModuleBase.sol";
import { IController } from "../interfaces/IController.sol";
import { ILockReleaseModule } from "../interfaces/ILockReleaseModule.sol";
import { Invoke } from "../lib/Invoke.sol";
import { ISetToken } from "../interfaces/ISetToken.sol";
import { Position } from "../lib/Position.sol";
/**
 * THIS IS AN EXAMPLE CONTRACT THAT USES HARDCODED VALUES FOR CLARITY.
 * THIS IS AN EXAMPLE CONTRACT THAT USES UN-AUDITED CODE.
 * DO NOT USE THIS CODE IN PRODUCTION.
 */

// TODO Create a Token Pool in the future

contract LockReleaseModule is Withdraw,CCIPReceiver, ModuleBase , ILockReleaseModule {


    using SafeCast for int256;
    using SafeMath for uint256;

    using Invoke for ISetToken;
    using Position for ISetToken;
    using PreciseUnitMath for uint256;

    /* ============ Struct ============ */

    struct LockInfo {
        ISetToken setToken;                             // Instance of SetToken
        address lockToken;                              // Address of token being sold
        
        uint256 setTotalSupply;                         // Total supply of SetToken in Precise Units (10^18)
        uint256 totalLockQuantity;                      // Total quantity of sold token (position unit x total supply)
        
        uint256 preTradeLockTokenBalance;               // Total initial balance of token being sold
        
    }

    struct ReceiveInfo {
        ISetToken setToken;                             // Instance of SetToken
        
        address receiveToken;                           // Address of token being bought
        uint256 setTotalSupply;                         // Total supply of SetToken in Precise Units (10^18)
        
        uint256 totalReceiveQuantity;                // Total quantity of token to receive back
        
        uint256 preTradeReceiveTokenBalance;            // Total initial balance of token being bought
    }

    enum PayFeesIn {
        Native, 
        LINK  
    }
    bytes32 latestMessageId;
    uint64 latestSourceChainSelector;
    address latestLocker;
    string latestMessage;
    bytes32 latestArgs;
    
    address immutable i_link;
    uint16 immutable i_maxTokensLength;
    address _owner;
    event MessageSent(bytes32 messageId);

    event MessageReceived(
        bytes32 latestMessageId,
        uint64 latestSourceChainSelector,
        address latestLocker,
        string latestMessage
    );
    event TokenLockForCCIP(ISetToken setToken, address lockToken, uint256 ulockAmount);
    event TokenReleaseForCCIP(ISetToken setToken, address releaseToken, uint256 ureleaseAmount);

    constructor(address router, address link, IController controller ) CCIPReceiver(router) ModuleBase(controller) {
        i_link = link;
        i_maxTokensLength = 5;

        _owner = msg.sender;
        
        LinkTokenInterface(i_link).approve(router, type(uint256).max);
    }

    receive() external payable {}


    function getLatestMessageDetails()
        public
        view
        returns (bytes32, uint64, address, string memory)
    {
        return (
            latestMessageId,
            latestSourceChainSelector,
            latestLocker,
            latestMessage
        );
    }

    function _validateLockPreTradeData(LockInfo memory info, uint256 _qty) internal view {
        require(info.totalLockQuantity > 0, "Token to sell must be nonzero");

        require(
            _tradeInfo.setToken.hasSufficientDefaultUnits(info.lockToken, _qty),
            "Unit cant be greater than existing"
        );
    }


    // Lock quantity and receive quantity is per 1 set token what is the quantity to be rebalanced 
    function lockToken(
        ISetToken _setToken,
        address _lockToken,
        uint256 _lockQuantity
    )
        external
        nonReentrant
        onlyManagerAndValidSet(_setToken)
    {


        LockInfo memory lockInfo;
        lockInfo.setToken =_setToken;
        lockInfo.lockToken = _lockToken;
        lockInfo.totalLockQuantity = Position.getDefaultTotalNotional(tradeInfo.setTotalSupply, _lockQuantity);
        lockInfo.preTradeLockTokenBalance = IERC20(_lockToken).balanceOf(address(_setToken));

        _validatePreTradeData(lockInfo, _lockQuantity);

        _executeLock(lockInfo);

        // No post-validation because no receive token

        // TODO assume no protocol fees
        // uint256 protocolFee = 0;

        
        uint256 netLockAmount = _updateSetTokenPositionsAfterLock(lockInfo);

        emit TokenLockForCCIP(
            _setToken,
            _lockToken,
            netLockAmount
            // netReceiveAmount,
            // protocolFee
        );
    }


    function _executeLock(
        LockInfo memory lockInfo        
    )
        internal
    {
        uint256 callValue = 0;
        // transferFrom(IERC20 _token, address _from, address _to, uint256 _quantity)
        bytes memory methodData = abi.encodeCall(transferFrom,(lockInfo.lockToken, address(lockInfo.setToken), address(this),lockInfo.totalLockQuantity));

        _tradeInfo.setToken.invoke(address(this), callValue, methodData);
    }


    function _updateSetTokenPositionsAfterLock(LockInfo memory lockInfo) internal returns (uint256, uint256) {
        (uint256 currentLockTokenBalance,,) = _tradeInfo.setToken.calculateAndEditDefaultPosition(
            lockInfo.lockToken,
            lockInfo.setTotalSupply,
            lockInfo.preTradeLockTokenBalance
        );

        // (uint256 currentReceiveTokenBalance,,) = _tradeInfo.setToken.calculateAndEditDefaultPosition(
        //     _tradeInfo.receiveToken,
        //     _tradeInfo.setTotalSupply,
        //     _tradeInfo.preTradeReceiveTokenBalance
        // );

        return 
            lockInfo.preTradeLockTokenBalance.sub(currentLockTokenBalance)
            // ,
            // currentReceiveTokenBalance.sub(_tradeInfo.preTradeReceiveTokenBalance)
        ;
    }

    function _validateLockPreTradeData(LockInfo memory info, uint256 _qty) internal view {
        require(info.totalLockQuantity > 0, "Token to sell must be nonzero");

        require(
            _tradeInfo.setToken.hasSufficientDefaultUnits(info.lockToken, _qty),
            "Unit cant be greater than existing"
        );
    }


    // Lock quantity and receive quantity is per 1 set token what is the quantity to be rebalanced 
    function releaseToken(
        ISetToken _setToken,
        address _releaseToken,
        uint256 _releaseTQuantity
    )
        external
        nonReentrant
        onlyManagerAndValidSet(_setToken)
    {


        ReleaseInfo memory releaseInfo;
        releaseInfo.setToken =_setToken;
        releaseInfo.releaseToken = _releaseToken;
        releaseInfo.totalLockQuantity = Position.getDefaultTotalNotional(tradeInfo.setTotalSupply, _releaseTQuantity);
        releaseInfo.preTradeLockTokenBalance = IERC20(_releaseToken).balanceOf(address(_setToken));

        _validatePreTradeData(releaseInfo, _releaseTQuantity);

        IERC20(releaseInfo.releaseToken).transfer(address(releaseInfo.setToken), releaseInfo.totalReleaseQuantity);

        // No post-validation because no receive token

        // TODO assume no protocol fees
        // uint256 protocolFee = 0;

        uint256 netReleaseAmount = _updateSetTokenPositionsAfterRelease(releaseInfo);

        emit TokenReleaseForCCIP(
            _setToken,
            _releaseToken,
            netReleaseAmount
            // netReceiveAmount,
            // protocolFee
        );
    }




    function _updateSetTokenPositionsAfterRelease(LockInfo memory releaseInfo) internal returns (uint256, uint256) {
        // (uint256 currentLockTokenBalance,,) = _tradeInfo.setToken.calculateAndEditDefaultPosition(
        //     releaseInfo.lockToken,
        //     releaseInfo.setTotalSupply,
        //     releaseInfo.preTradeLockTokenBalance
        // );

        (uint256 currentReleaseTokenBalance,,) = _tradeInfo.setToken.calculateAndEditDefaultPosition(
            _tradeInfo.releaseToken,
            _tradeInfo.setTotalSupply,
            _tradeInfo.preTradeReleaseTokenBalance
        );

        return 
            releaseInfo.preTradeReleaseTokenBalance.sub(currentReleaseTokenBalance)
            // ,
            // currentReceiveTokenBalance.sub(_tradeInfo.preTradeReceiveTokenBalance)
        ;
    }



}

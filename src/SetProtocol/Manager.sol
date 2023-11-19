// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
pragma experimental "ABIEncoderV2";

import "./interfaces/ITradeModule.sol";
import "./interfaces/ILockReleaseModule.sol";
import "./interfaces/ILockReleaseModule.sol";
import "./interfaces/IController.sol";
import "./interfaces/IIntegrationRegistry.sol";
import "./interfaces/IExchangeAdapter.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";


contract Manager is Ownable, CCIPReceiver {
    
    bytes32 latestMessageId;
    uint64 latestSourceChainSelector;
    address latestSender;
    string latestMessage;
    bytes32 latestArgs;

    ITradeModule tradeModule;
    ILockReleaseModule lockReleaseModule;
    IController  controller;
    address immutable linkToken;

    mapping(address => bool) private whitelist;

    enum PayFeesIn {
        Native,
        LINK
    }

    event MessageSent(bytes32 messageId);
    receive() external payable {}

    struct CCIPInfo {
        address setToken;
        string  exchangeName;
        address sendToken;
        uint256 sendQuantity;
        address receiveToken;
        uint256 minReceiveQuantity;
        uint8 integrationRegistryID;
        uint8 poolFee;
        address releaseToken;
        uint256 releaseQuantity;
    }
    
    modifier whitelistOnly(){
        require(isWhitelisted(msg.sender),"Caller is not whitelisted");
        _;
    }
    function isWhitelisted(address _address) public view returns (bool) {
        return whitelist[_address];
    }

    constructor(address _tradeModule, address _lockReleaseModule, address _controller , address _ccipRouter, address _linkToken) CCIPReceiver(_ccipRouter) {
        tradeModule = ITradeModule(_tradeModule);
        lockReleaseModule = ILockReleaseModule(_lockReleaseModule);
        controller = IController(_controller);
        linkToken = _linkToken;
    }

    function addToWhitelist(address _address) public onlyOwner {
        whitelist[_address] = true;
     
    }
    

    function removeFromWhitelist(address _address) public onlyOwner {
        whitelist[_address] = false;

    }

    function swap(
        address _setToken,
        string memory _exchangeName,
        address _sendToken,
        uint256 _sendQuantity,
        address _receiveToken,
        uint256 _minReceiveQuantity,
        uint8 integrationRegistryID,
        uint8 poolFee
        // bytes memory _data
    ) whitelistOnly public{
        IExchangeAdapter exchangeAdapter = IExchangeAdapter(IIntegrationRegistry(controller.resourceId(integrationRegistryID)).getIntegrationAdapter(address(tradeModule), _exchangeName));
        address[] memory paths = new address[](2);
        paths[0] = _sendToken;
        paths[1] = _receiveToken;

        uint24[] memory fees = new uint24[](1);
        fees[0] = poolFee;        

        bytes memory callData = exchangeAdapter.generateDataParam(paths, fees, true);
        
        tradeModule.trade( ISetToken(_setToken),
                        _exchangeName,
                        _sendToken,
                        _sendQuantity,
                        _receiveToken,
                        _minReceiveQuantity, 
                        callData);   
        
    }

    function encodeCCIPInfo(        
        address _setToken,
        string memory  _exchangeName,
        address _sendToken,
        uint256 _sendQuantity,
        address _receiveToken,
        uint256 _minReceiveQuantity,
        uint8 _integrationRegistryID,
        uint8 _poolFee,
        address _releaseToken,
        uint256 _releaseQuantity) public pure returns(bytes memory)  {
            CCIPInfo memory ccipinfo;
        // address setToken;
        // string  exchangeName;
        // address sendToken;
        // uint256 sendQuantity;
        // address receiveToken;
        // uint256 minReceiveQuantity;
        // uint8 integrationRegistryID;
        // uint8 poolFee;
        // address releaseToken;
        // uint256 releaseQuantity;

            ccipinfo.setToken = _setToken;
            ccipinfo.exchangeName = _exchangeName;
            ccipinfo.sendToken = _sendToken;
            ccipinfo.sendQuantity = _sendQuantity;
            ccipinfo.receiveToken = _receiveToken;
            ccipinfo.minReceiveQuantity = _minReceiveQuantity;
            ccipinfo.integrationRegistryID = _integrationRegistryID;
            ccipinfo.poolFee = _poolFee;
            ccipinfo.releaseToken = _releaseToken;
            ccipinfo.releaseQuantity = _releaseQuantity;
            return abi.encode(ccipinfo);
    }

    function lockAndSend(address _setToken,
        address _lockToken,
        uint256 _lockQuantity,
        uint64 destinationChainSelector,
        address receiver,
        bytes memory dataToCallReceiver,
        bool useLink
        ) whitelistOnly public {

        lockReleaseModule.lockToken(ISetToken(_setToken),_lockToken,_lockQuantity);

        _sendMessage(destinationChainSelector, receiver, dataToCallReceiver,useLink);
    }   

    // function releaseToken(
    //     ISetToken _setToken,
    //     address _releaseToken,
    //     uint256 _releaseTQuantity
    // )

    function _ccipReceive( 
            Client.Any2EVMMessage memory message)
         onlyRouter internal override {
        latestMessageId = message.messageId;
        latestSourceChainSelector = message.sourceChainSelector;
        latestSender = abi.decode(message.sender, (address));
        CCIPInfo memory ccipInfo = abi.decode(message.data, (CCIPInfo));
        
        lockReleaseModule.releaseToken(ISetToken(ccipInfo.setToken), ccipInfo.releaseToken, ccipInfo.releaseQuantity);
        
        // address _setToken,
        // string memory _exchangeName,
        // address _sendToken,
        // uint256 _sendQuantity,
        // address _receiveToken,
        // uint256 _minReceiveQuantity,
        // uint8 integrationRegistryID,
        // uint8 poolFee

        swap(ccipInfo.setToken,ccipInfo.exchangeName,ccipInfo.sendToken, ccipInfo.sendQuantity, ccipInfo.receiveToken, ccipInfo.minReceiveQuantity, ccipInfo.integrationRegistryID,ccipInfo.poolFee);

    }


    function getLatestMessageDetails()
        public
        view
        returns (bytes32, uint64, address, string memory)
    {
        return (
            latestMessageId,
            latestSourceChainSelector,
            latestSender,
            latestMessage
        );
    }

    function _sendMessage(
        uint64 destinationChainSelector,
        address receiver,
        bytes memory dataToCallReceiver,
        bool useLink
    ) internal returns (bytes32 messageId)  {
        PayFeesIn payFeesIn = useLink? PayFeesIn.LINK:PayFeesIn.Native;
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: dataToCallReceiver,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: "",
            feeToken: payFeesIn == PayFeesIn.LINK ? linkToken : address(0)
        });

        uint256 fee = IRouterClient(getRouter()).getFee(
            destinationChainSelector,
            message
        );

        if (payFeesIn == PayFeesIn.LINK) {
            //  LinkTokenInterface(i_link).approve(i_router, fee);
            messageId = IRouterClient(getRouter()).ccipSend(
                destinationChainSelector,
                message
            );
        } else {
            messageId = IRouterClient(getRouter()).ccipSend{value: fee}(
                destinationChainSelector,
                message
            );
        }

        emit MessageSent(messageId);
    }

}
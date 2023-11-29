// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
pragma experimental "ABIEncoderV2";

import "./interfaces/ITradeModule.sol";
import "./interfaces/ILockReleaseModule.sol";
import "./interfaces/IBasicIssuanceModule.sol";
import "./interfaces/IManagerIssuanceHook.sol";
import "./interfaces/IController.sol";
import "./interfaces/IIntegrationRegistry.sol";
import "./interfaces/IExchangeAdapter.sol";
import "./interfaces/ISetTokenCreator.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";


contract Manager is Ownable, CCIPReceiver {
    
    bytes32 latestMessageId;
    uint64 latestSourceChainSelector;
    address latestSender;
    string latestMessage;
    bytes32 latestArgs;

    ITradeModule tradeModule;
    ILockReleaseModule lockReleaseModule;
    IController  controller;
    ISetTokenCreator creator;
    IBasicIssuanceModule basicIssuanceModule;

    address immutable linkToken;

    mapping(address => bool) private whitelist;

    enum PayFeesIn {
        Native,
        LINK
    }

    mapping(bytes => bool) public tokenPairExistence;

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
        uint24 poolFee;
        address destToken;
        uint256 destQuantity;
        uint8 destActionType;
    }
    
    modifier whitelistOnly(){
        require(isWhitelisted(msg.sender) ,"Caller is not whitelisted");
        _;
    }
    function isWhitelisted(address _address) public view returns (bool) {
        return whitelist[_address];
    }

    constructor(address _tradeModule, address _lockReleaseModule, address _controller , 
                address _creator, address _issuanceModule,
              address _ccipRouter, address _linkToken) CCIPReceiver(_ccipRouter) {
        tradeModule = ITradeModule(_tradeModule);
        lockReleaseModule = ILockReleaseModule(_lockReleaseModule);
        controller = IController(_controller);
        linkToken = _linkToken;
        creator = ISetTokenCreator(_creator);
        basicIssuanceModule =  IBasicIssuanceModule(_issuanceModule);

        LinkTokenInterface(linkToken).approve(_ccipRouter, type(uint256).max);
    }

    function addToWhitelist(address _address) public onlyOwner {
        whitelist[_address] = true;
     
    }
    
    function regsiterTokenPair(address _token1, address _token2) public onlyOwner{
        tokenPairExistence[abi.encode(_token1,_token2)]=true;
        tokenPairExistence[abi.encode(_token2,_token1)]=true;
    }

    function removeFromWhitelist(address _address) public onlyOwner {
        whitelist[_address] = false;

    }

    function changeManager(address setToken ,address _address) public onlyOwner {
        ISetToken(setToken).setManager(_address);
    }

    function createSetToken( address[] memory _components,
        int256[] memory _units,
        string memory _name,
        string memory _symbol)
        public
        returns (address)
        {

        address[] memory modules = new address[](3);
        modules[0] = address(tradeModule);
        modules[1] = address(basicIssuanceModule);
        modules[2] = address(lockReleaseModule);

        address setToken = creator.create(_components, _units, modules, address(this),_name, _symbol );
        tradeModule.initialize(ISetToken(setToken));
        basicIssuanceModule.initialize(ISetToken(setToken), IManagerIssuanceHook(address(0)));
        lockReleaseModule.initialize(ISetToken(setToken));        

        return setToken;
    }

    function swap(
        address _setToken,
        string memory _exchangeName,
        address _sendToken,
        uint256 _sendQuantity,
        address _receiveToken,
        uint256 _minReceiveQuantity,
        uint8 integrationRegistryID,
        uint24 poolFee
    ) whitelistOnly external {

        _swap(_setToken,
         _exchangeName,
         _sendToken,
         _sendQuantity,
         _receiveToken,
         _minReceiveQuantity,
         integrationRegistryID,
         poolFee);
    }

    function _swap(
        address _setToken,
        string memory _exchangeName,
        address _sendToken,
        uint256 _sendQuantity,
        address _receiveToken,
        uint256 _minReceiveQuantity,
        uint8 integrationRegistryID,
        uint24 poolFee
        // bytes memory _data
    )  internal {
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
        uint24 _poolFee,
        address _destToken,
        uint256 _destQuantity,
        uint8 destActionType
        ) public pure returns(bytes memory)  {
        
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
            ccipinfo.destToken = _destToken;
            ccipinfo.destQuantity = _destQuantity;
            ccipinfo.destActionType = destActionType;
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

        CCIPInfo memory ccipInfo = abi.decode(dataToCallReceiver,(CCIPInfo));
        
        require(ccipInfo.destActionType == 0 || ccipInfo.destActionType == 3 ," Not release on destination chain " );
        require(ccipInfo.destQuantity== _lockQuantity, "Lock unlock quantity not the same");
        require(tokenPairExistence[abi.encode(_lockToken,ccipInfo.destToken)] == true, "Lock unlock Token not the same");
        
        lockReleaseModule.lockToken(ISetToken(_setToken), _lockToken, _lockQuantity);

        _sendMessage(destinationChainSelector, receiver, dataToCallReceiver,useLink);
    }

    // consideration we shouldnt allow release first before lock ,
    // because what if we purposefully let destination chain fail and walk away with released token
    // TODO Confirm releaseSend is not necessary

    // function _releaseAndSend(address _setToken,
    //     address _releasekToken,
    //     uint256 _releaseQuantity,
    //     uint64 destinationChainSelector,
    //     address receiver,
    //     bytes memory dataToCallReceiver,
    //     bool useLink
    //     )  internal {
    //     CCIPInfo memory ccipInfo = abi.decode(dataToCallReceiver,(CCIPInfo));

    //     require(ccipInfo.destActionType == 1 || ccipInfo.destActionType == 2 ," Not lock on destination chain " );
    //     require(ccipInfo.destQuantity== _releaseQuantity, "Lock unlock quantity not the same");
    //     require(tokenPairExistence[abi.encode(_releasekToken,ccipInfo.destToken)] == true, "Lock unlock Token not the same");
        
    //     _sendMessage(destinationChainSelector, receiver, dataToCallReceiver,useLink);

    //     lockReleaseModule.releaseToken(ISetToken(_setToken),_releasekToken,_releaseQuantity);
    // }      

    // function releaseToken(``
    //     ISetToken _setToken,
    //     address _releaseToken,
    //     uint256 _releaseTQuantity
    // )

    function _ccipReceive( 
            Client.Any2EVMMessage memory message)
         onlyRouter internal 
         override {
        latestMessageId = message.messageId;
        latestSourceChainSelector = message.sourceChainSelector;
        latestSender = abi.decode(message.sender, (address));
        CCIPInfo memory ccipInfo = abi.decode(message.data, (CCIPInfo));

        // release and swap
        if (ccipInfo.destActionType == 0){
            lockReleaseModule.releaseToken(ISetToken(ccipInfo.setToken), ccipInfo.destToken, ccipInfo.destQuantity);
            _swap(ccipInfo.setToken,ccipInfo.exchangeName,ccipInfo.sendToken, ccipInfo.sendQuantity, ccipInfo.receiveToken, ccipInfo.minReceiveQuantity, ccipInfo.integrationRegistryID,ccipInfo.poolFee);
        }

        // // swap and lock
        // else if (ccipInfo.destActionType == 1){
        //     _swap(ccipInfo.setToken,ccipInfo.exchangeName,ccipInfo.sendToken, ccipInfo.sendQuantity, ccipInfo.receiveToken, ccipInfo.minReceiveQuantity, ccipInfo.integrationRegistryID,ccipInfo.poolFee);
        //     lockReleaseModule.lockToken(ISetToken(ccipInfo.setToken), ccipInfo.destToken, ccipInfo.destQuantity);
        // }
        // // simply lock
        // else if (ccipInfo.destActionType == 2){
        //     lockReleaseModule.lockToken(ISetToken(ccipInfo.setToken), ccipInfo.destToken, ccipInfo.destQuantity);            
        // }
        // simply release
        
        else if (ccipInfo.destActionType == 3){
            lockReleaseModule.releaseToken(ISetToken(ccipInfo.setToken), ccipInfo.destToken, ccipInfo.destQuantity);
        }
    }

    // TODO delete this endpoint during deployment
    // function ccipReceiveTestCall( 
    //         Client.Any2EVMMessage memory message)
    //      external
    // {
    //     latestMessageId = message.messageId;
    //     latestSourceChainSelector = message.sourceChainSelector;
    //     latestSender = abi.decode(message.sender, (address));
    //     CCIPInfo memory ccipInfo = abi.decode(message.data, (CCIPInfo));

    //     // release and swap
    //     if (ccipInfo.destActionType == 0){
    //         lockReleaseModule.releaseToken(ISetToken(ccipInfo.setToken), ccipInfo.destToken, ccipInfo.destQuantity);
    //         swap(ccipInfo.setToken,ccipInfo.exchangeName,ccipInfo.sendToken, ccipInfo.sendQuantity, ccipInfo.receiveToken, ccipInfo.minReceiveQuantity, ccipInfo.integrationRegistryID,ccipInfo.poolFee);
    //     }
    //     // swap and lock
    //     else if (ccipInfo.destActionType == 1){
    //         swap(ccipInfo.setToken,ccipInfo.exchangeName,ccipInfo.sendToken, ccipInfo.sendQuantity, ccipInfo.receiveToken, ccipInfo.minReceiveQuantity, ccipInfo.integrationRegistryID,ccipInfo.poolFee);
    //         lockReleaseModule.lockToken(ISetToken(ccipInfo.setToken), ccipInfo.destToken, ccipInfo.destQuantity);
    //     }
    //     // simply lock
    //     else if (ccipInfo.destActionType == 2){
    //         lockReleaseModule.lockToken(ISetToken(ccipInfo.setToken), ccipInfo.destToken, ccipInfo.destQuantity);            
    //     }
    //     // simply release
    //     else if (ccipInfo.destActionType == 3){
    //         lockReleaseModule.releaseToken(ISetToken(ccipInfo.setToken), ccipInfo.destToken, ccipInfo.destQuantity);
    //     }
    // }

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
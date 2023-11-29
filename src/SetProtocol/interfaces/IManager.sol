// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IManager {

    function isWhitelisted(address _address) external view returns (bool);

    function swap(
        address _setToken,
        string memory _exchangeName,
        address _sendToken,
        uint256 _sendQuantity,
        address _receiveToken,
        uint256 _minReceiveQuantity,
        uint8 integrationRegistryID,
        uint24 poolFee
        // bytes memory _data
    )  external;

    function lockAndSend(address _setToken,
        address _lockToken,
        uint256 _lockQuantity,
        uint64 destinationChainSelector,
        address receiver,
        bytes memory dataToCallReceiver,
        bool useLink
        )  external;

    function createSetToken( address[] memory _components,
        int256[] memory _units,
        string memory _name,
        string memory _symbol)
        external
        returns (address);

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
        ) external pure returns(bytes memory) ;

    function getLatestMessageDetails()
        external
        view
        returns (bytes32, uint64, address, string memory);
    
    function addToWhitelist(address _address) external;
    
    function regsiterTokenPair(address _token1, address _token2) external;

    function removeFromWhitelist(address _address) external;

    function changeManager(address setToken ,address _address) external;
}
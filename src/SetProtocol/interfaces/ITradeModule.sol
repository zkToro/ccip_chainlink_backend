// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
pragma experimental "ABIEncoderV2";

import "./ISetToken.sol";

interface ITradeModule {

    function trade(
        ISetToken _setToken,
        string memory _exchangeName,
        address _sendToken,
        uint256 _sendQuantity,
        address _receiveToken,
        uint256 _minReceiveQuantity,
        bytes memory _data
    ) external;
    

}
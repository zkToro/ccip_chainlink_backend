// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;
pragma experimental "ABIEncoderV2";

import "./ISetToken.sol";

interface ILockReleaseModule {

    function lockToken(
        ISetToken _setToken,
        address _lockToken,
        uint256 _lockQuantity
    ) external ;
    
    function releaseToken(
        ISetToken _setToken,
        address _releaseToken,
        uint256 _releaseTQuantity
    ) external; 


}
// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { ISetToken } from "./ISetToken.sol";
import { IManagerIssuanceHook } from "./IManagerIssuanceHook.sol";

interface IBasicIssuanceModule {
    function getRequiredComponentUnitsForIssue(
        ISetToken _setToken,
        uint256 _quantity
    ) external returns(address[] memory, uint256[] memory);

    function redeem(
        ISetToken _setToken,
        uint256 _quantity,
        address _to
    )
    external;
    
    function issue(
        ISetToken _setToken,
        uint256 _quantity,
        address _to
    ) external;
    
    function initialize(
        ISetToken _setToken,
        IManagerIssuanceHook _preIssueHook
    ) external;

}

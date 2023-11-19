// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IExchangeAdapter {
    function getSpender() external view returns(address);
    function getTradeCalldata(
        address _fromToken,
        address _toToken,
        address _toAddress,
        uint256 _fromQuantity,
        uint256 _minToQuantity,
        bytes memory _data
    )
        external
        view
        returns (address, uint256, bytes memory);

    function generateDataParam(
        address[] calldata _path,
        uint24[] calldata _fees,
        bool _fixIn
    ) external pure returns (bytes memory); 
}
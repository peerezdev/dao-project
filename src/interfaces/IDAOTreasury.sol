// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

interface IDAOTreasury {
    function spendFunds(address _recipient, address _token, uint256 _amount) external;
}
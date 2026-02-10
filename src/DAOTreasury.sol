// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DAOGovernanceToken} from "./DAOGovernanceToken.sol";

contract DAOTreasury is Ownable {
    address public dao;

    event FundedDAOWithEther(address indexed sender, uint256 amount);
    event FundedDAOWithToken(address indexed sender, address indexed token, uint256 amount);
    event DAOChanged(address dao);
    event SpentFunds(address recipient, address token, uint256 amount);

    constructor(address _dao) Ownable(msg.sender) {
        dao = _dao;
    }

    function spendFunds(address _recipient, address _token, uint256 _amount) external {
        require(msg.sender == dao, "Only DAO can spend funds");
        require(_recipient != address(0), "Invalid address");
        require(_amount > 0, "Amount must be greater that 0");
        
        if (_token == address(0)) {
            require(_amount <= address(this).balance, "Not enough ether balance");
            (bool _success, ) = _recipient.call{value: _amount}("");
            require(_success, "Ether transfer failed");
        } else {
            require(_amount <= IERC20(_token).balanceOf(address(this)), "Not enough token balance");
            require(IERC20(_token).transfer(_recipient, _amount), "Token transfer failed");
        }

        emit SpentFunds(_recipient, _token, _amount);
    }
    
    function fundTreasuryWithEther() external payable {
        require(msg.value > 0, "No ether in msg.value");
        emit FundedDAOWithEther(msg.sender, msg.value);
    }

    function fundTreasuryWithToken(address _token, uint256 _amount) external {
        require(_token != address(0), "Invalid token address");
        require(_amount > 0, "Amount must be greater that 0");
        require(_amount <= IERC20(_token).balanceOf(msg.sender), "Not enough balance");
        require(_amount <= IERC20(_token).allowance(msg.sender, address(this)), "Not enough allowance");

        require(IERC20(_token).transferFrom(msg.sender, address(this), _amount), "Token transfer failed");

        emit FundedDAOWithToken(msg.sender, _token, _amount);
    }

    function setDAO(address _dao) external onlyOwner() {
        require(_dao != address(0), "Invalid address");
        dao = _dao;

        emit DAOChanged(_dao);
    }

    function emergencyWithdraw(address _token, uint256 _amount) external onlyOwner() {
        if (_token == address(0)) {
            if (_amount == 0) {
                _amount = address(this).balance;
            }
            (bool _success,) = owner().call{value: _amount}("");
            require(_success, "Ether transfer failed");
        } else {
            if (_amount == 0) {
                _amount = IERC20(_token).balanceOf(address(this));
            }
            require(IERC20(_token).transfer(owner(), _amount), "Token transfer failed");
        }
    }


}
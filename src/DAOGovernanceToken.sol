// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract DAOGovernanceToken is ERC20, Ownable {
    mapping(address => address) public delegatedTo;
    mapping(address => uint256) public votingPowerDelegated;
    mapping(address => uint256) public votingPowerReceived;

    event Delegated(address indexed user, address indexed delegate, uint256 amount);
    event Undelegated(address indexed user, address indexed delegate, uint256 amount);
    

    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) ERC20(_name, _symbol) Ownable(msg.sender) {
        _mint(msg.sender, _initialSupply);
    }

    function mint(address _to, uint256 _amount) external onlyOwner() {
        _mint(_to, _amount);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    function _update(address _from, address _to, uint256 _amount) internal virtual override {
        if (_from != address(0) && delegatedTo[_from] != address(0) && votingPowerDelegated[_from] > 0) {
            votingPowerDelegated[_from] -= _amount;
            votingPowerReceived[delegatedTo[_from]] -= _amount;
        }

        super._update(_from, _to, _amount);

        if (_to != address(0) && delegatedTo[_to] != address(0)) {
            votingPowerDelegated[_to] += _amount;
            votingPowerReceived[delegatedTo[_to]] += _amount;
        }
    }

    function getVotingPower(address _user) external view returns (uint256 _votingPower) {
        _votingPower = balanceOf(_user) - votingPowerDelegated[_user] + votingPowerReceived[_user];
    }

    function delegate(address _delegate) external {
        require(_delegate != address(0) && _delegate != msg.sender, "Invalid address");
        address _oldDelegate = delegatedTo[msg.sender];
        require(_delegate != _oldDelegate, "Tokens are already delegated to this address");
        uint256 _balance = balanceOf(msg.sender);

        if (_oldDelegate != address(0)) {
            votingPowerReceived[_oldDelegate] -= votingPowerDelegated[msg.sender];
        }
        delegatedTo[msg.sender] = _delegate;
        votingPowerDelegated[msg.sender] = _balance;
        votingPowerReceived[_delegate] += _balance;

        emit Delegated(msg.sender, _delegate, _balance);
    }

    function undelegate() external {
        address _currentDelegate = delegatedTo[msg.sender];
        require(_currentDelegate != address(0), "No active delegation");
        uint256 _balance = balanceOf(msg.sender);

        delegatedTo[msg.sender] = address(0);
        votingPowerDelegated[msg.sender] = 0;
        votingPowerReceived[_currentDelegate] -= _balance;

        emit Undelegated(msg.sender, _currentDelegate, _balance);
    }

}
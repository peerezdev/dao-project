// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {DAOGovernanceToken} from "../src/DAOGovernanceToken.sol";
import {IDAOTreasury} from "./interfaces/IDAOTreasury.sol";

/**
 * @title DAO Core
 * @author peerezdev
 * @notice Contract that manages all the logic about DAO proposals.
 */
contract DAOCore is Ownable {
    DAOGovernanceToken public governanceToken;
    IDAOTreasury public treasury;

    uint256 public minimumPowerToCreateProposal = 500 * 1e18;
    uint256 public thresholdVotes = 4000;
    uint256 public minimumProposalDuration = 1 days;

    struct Proposal {
        address proposer;
        address recipient;
        string description;
        address token;
        uint256 amount;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Proposal) public proposals;

    uint256 public proposalCounter = 0;

    event ProposalCreated(uint256 proposalId, address indexed proposer, address indexed recipient, string description, address token, uint256 amount, uint256 startTime, uint256 endTime);
    event ProposalCanceled(uint256 proposalId, address indexed proposer);
    event Voted(address indexed voter, uint256 indexed proposalId, uint256 votingPower);
    event ProposalExecuted(uint256 proposalId);

    event ChangedGovernanceToken(address token);
    event ChangedTreasury(address treasury);
    event ChangedThresholdVotes(uint256 threshold);
    event ChangedMinimumProposalDuration(uint256 minimumDuration);

    constructor(address _governanceToken, address _treasury) Ownable(msg.sender) {
        governanceToken = DAOGovernanceToken(_governanceToken);
        treasury = IDAOTreasury(_treasury);
    }

    function createProposal(address _recipient, string memory _description, address _tokenPayment, uint256 _amount, uint256 _startTime, uint256 _endTime) external {
        require(governanceToken.getVotingPower(msg.sender) >= minimumPowerToCreateProposal, "Not enough voting power to create proposals");
        require(_recipient != address(0), "Invalid recipient");
        require(bytes(_description).length > 0, "Description is empty");
        require(_amount > 0, "Amount must be greater that 0");
        require(_startTime > block.timestamp, "Startime can not be before current timestamp");
        require(_endTime > _startTime + minimumProposalDuration, "Endtime have to be more that the minimum duration");

        proposals[proposalCounter].proposer = msg.sender;
        proposals[proposalCounter].recipient = _recipient;
        proposals[proposalCounter].description = _description;
        proposals[proposalCounter].token = _tokenPayment; 
        proposals[proposalCounter].amount = _amount;
        proposals[proposalCounter].startTime = _startTime;
        proposals[proposalCounter].endTime = _endTime;

        emit ProposalCreated(proposalCounter, msg.sender, _recipient, _description, _tokenPayment, _amount, _startTime, _endTime);
        proposalCounter++;
    }

    function cancelProposal(uint256 _proposalId) external {
        require(proposals[_proposalId].proposer != address(0), "Proposal does not exist");
        require(msg.sender == proposals[_proposalId].proposer || msg.sender == owner(), "Not authorized to cancel");
        proposals[_proposalId].canceled = true;
        emit ProposalCanceled(_proposalId, msg.sender);
    }

    function vote(uint256 _proposalId, bool _forVote) external {
        Proposal storage _proposal = proposals[_proposalId];
        require(_proposal.proposer != address(0), "Proposal does not exist");
        require(!_proposal.canceled, "Proposal is canceled");
        require(block.timestamp >= _proposal.startTime, "Proposal does not start yet");
        require(block.timestamp <= _proposal.endTime, "Proposal already ended");

        uint256 _votingPower = governanceToken.getVotingPower(msg.sender);
        require(_votingPower > 0, "No voting power");
        require(!_proposal.hasVoted[msg.sender], "You already voted this proposal");

        if (_forVote) {
            _proposal.forVotes += _votingPower;
        } else {
            _proposal.againstVotes += _votingPower;
        }

        _proposal.hasVoted[msg.sender] = true;
        emit Voted(msg.sender, _proposalId, _votingPower);
    }

    function executeProposal(uint256 _proposalId) external {
        Proposal storage _proposal = proposals[_proposalId];
        require(_proposal.proposer != address(0), "Proposal does not exist");
        require(!_proposal.canceled, "Proposal is canceled");
        require(block.timestamp > _proposal.endTime, "Proposal does not end yet");
        require(_proposal.forVotes + _proposal.againstVotes >= thresholdVotes, "Not enough votes");
        require(_proposal.forVotes > _proposal.againstVotes, "The result of the proposal is against");
        require(!_proposal.executed, "Proposal already executed");


        _proposal.executed = true;

        treasury.spendFunds(_proposal.recipient, _proposal.token, _proposal.amount);

        emit ProposalExecuted(_proposalId);
    }

    function setGovernanceToken(address _newGovernanceToken) external onlyOwner() {
        require(_newGovernanceToken != address(0), "Invalid token address");
        governanceToken = DAOGovernanceToken(_newGovernanceToken);
        emit ChangedGovernanceToken(_newGovernanceToken);
    }

    function setTreasury(address _newTreasury) external onlyOwner() {
        require(_newTreasury != address(0), "Invalid treasury address");
        treasury = IDAOTreasury(_newTreasury);
        emit ChangedTreasury(_newTreasury);
    }

    function setThresholdVotes(uint256 _newThreshold) external onlyOwner() {
        require(_newThreshold > 0, "Threshold must be greater that 0");
        thresholdVotes = _newThreshold;
        emit ChangedThresholdVotes(_newThreshold);
    }

    function setMinimumDuration(uint256 _newMinimumDuration) external onlyOwner() {
        require(_newMinimumDuration > 0, "Minimum duration must be greater that 0");
        minimumProposalDuration = _newMinimumDuration;
        emit ChangedMinimumProposalDuration(_newMinimumDuration);
    }


}
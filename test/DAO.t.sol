// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/Console.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {DAOGovernanceToken} from "../src/DAOGovernanceToken.sol";
import {DAOTreasury} from "../src/DAOTreasury.sol";
import {DAOCore} from "../src/DAOCore.sol";

contract TestDAO is Test {
    address deployer = vm.addr(1);

    address user1 = vm.addr(2);
    address user2 = vm.addr(3);
    address user3 = vm.addr(4);
    address user4 = vm.addr(5);

    address recipientTest = vm.addr(10);

    DAOGovernanceToken daoGT;
    DAOTreasury daoTreasury;
    DAOCore daoCore;

    struct ProposalCopy {
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
    }

    function setUp() external {
        vm.startPrank(deployer);
        daoGT = new DAOGovernanceToken("DAO Test", "DAOT", 1000 * 1e18);

        // Deploy treasury without dao address
        daoTreasury = new DAOTreasury(address(0));
        daoCore = new DAOCore(address(daoGT),address(daoTreasury));

        // Now setDAO in treasury
        daoTreasury.setDAO(address(daoCore));

        vm.stopPrank();
    }

    function mintToUser1() internal {
        vm.startPrank(deployer);
        uint256 _amountToMint = 1000 * 1e18;
        daoGT.mint(user1, _amountToMint);
        vm.stopPrank();
    }

    function mintToUser2() internal {
        vm.startPrank(deployer);
        uint256 _amountToMint = 2000 * 1e18;
        daoGT.mint(user2, _amountToMint);
        vm.stopPrank();
    }

    function mintToUser3() internal {
        vm.startPrank(deployer);
        uint256 _amountToMint = 3000 * 1e18;
        daoGT.mint(user3, _amountToMint);
        vm.stopPrank();
    }

    function mintToTreasury() internal {
        vm.startPrank(deployer);
        uint256 _amountToMint = 5000 * 1e18;
        daoGT.mint(address(daoTreasury), _amountToMint);
        vm.stopPrank();
    }

    function getProposal(uint256 _proposalId) internal view returns (ProposalCopy memory _proposal){
        (address proposer,
        address recipient,
        string memory description,
        address token,
        uint256 amount,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 startTime,
        uint256 endTime,
        bool executed,
        bool canceled) = daoCore.proposals(_proposalId);

        _proposal.proposer = proposer;
        _proposal.recipient = recipient;
        _proposal.description = description;
        _proposal.token = token;
        _proposal.amount = amount;
        _proposal.forVotes = forVotes;
        _proposal.againstVotes = againstVotes;
        _proposal.startTime = startTime;
        _proposal.endTime = endTime;
        _proposal.executed = executed;
        _proposal.canceled = canceled;
    }

    function createProposal() internal {
        vm.startPrank(user1);
        address _recipient = recipientTest;
        string memory _description = "Test";
        address _tokenPayment = address(0);
        uint256 _amount = 1 ether;
        uint256 _startTime = 1000;
        uint256 _endTime = _startTime + 1 days + 1 seconds;
        daoCore.createProposal(_recipient, _description, _tokenPayment, _amount, _startTime, _endTime);
        vm.stopPrank();
    }

    function testRevertMint_NotOwner() external {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        daoGT.mint(msg.sender, 1000 * 1e18);
        vm.stopPrank();
    }

    function testMint() external {
        vm.startPrank(deployer);
        uint256 _supplyBefore = daoGT.totalSupply();
        uint256 _amountToMint = 1000 * 1e18;
        daoGT.mint(msg.sender, _amountToMint);
        uint256 _supplyAfter = daoGT.totalSupply();
        assert(_supplyBefore + _amountToMint == _supplyAfter);
        vm.stopPrank();
    }

    function testBurn() external {
        vm.startPrank(deployer);
        uint256 _supplyBefore = daoGT.totalSupply();
        uint256 _amountToBurn = 1000 * 1e18;

        daoGT.burn(_amountToBurn);
        uint256 _supplyAfter = daoGT.totalSupply();
        assert(_supplyBefore - _amountToBurn == _supplyAfter);
        vm.stopPrank();
    }

    function testRevertDelegate_InvalidAddress() external {
        mintToUser1();
        vm.startPrank(user1);
        vm.expectRevert("Invalid address");
        daoGT.delegate(address(0));
        vm.stopPrank();
    }

    function testRevertDelegate_AlreadyDelegatedAddress() external {
        mintToUser1();
        vm.startPrank(user1);
        daoGT.delegate(user2);
        vm.expectRevert("Tokens are already delegated to this address");
        daoGT.delegate(user2);
        vm.stopPrank();
    }

    function testDelegate() external {
        mintToUser1();
        mintToUser2();
        vm.startPrank(user1);
        uint256 _balanceUser1 = daoGT.balanceOf(user1);
        uint256 _balanceUser2 = daoGT.balanceOf(user2);
        daoGT.delegate(user2);
        assert(daoGT.delegatedTo(user1) == user2);
        assert(daoGT.votingPowerDelegated(user1) == _balanceUser1);
        assert(daoGT.votingPowerReceived(user2) == _balanceUser1);

        // Here we are going to test that now user1 voting power must be 0 and user2's voting power must be balance + delegated tokens from user1.
        assert(daoGT.getVotingPower(user1) == 0);
        assert(daoGT.getVotingPower(user2) == _balanceUser1 + _balanceUser2);

        vm.stopPrank();
    }

    function testDelegate_AnotherDelegate() external {
        mintToUser1();
        mintToUser2();
        mintToUser3();
        vm.startPrank(user1);

        uint256 _balanceUser1 = daoGT.balanceOf(user1);
        uint256 _balanceUser2 = daoGT.balanceOf(user2);
        uint256 _balanceUser3 = daoGT.balanceOf(user3);
        
        daoGT.delegate(user2);

        assert(daoGT.delegatedTo(user1) == user2);
        assert(daoGT.votingPowerDelegated(user1) == _balanceUser1);
        assert(daoGT.votingPowerReceived(user2) == _balanceUser1);

        // Here we are going to test that now user1 voting power must be 0 and user2's voting power must be balance + delegated tokens from user1.
        assert(daoGT.getVotingPower(user1) == 0);
        assert(daoGT.getVotingPower(user2) == _balanceUser1 + _balanceUser2);

        daoGT.delegate(user3);
        console.log(daoGT.votingPowerReceived(user3));
        assert(daoGT.delegatedTo(user1) == user3);
        assert(daoGT.votingPowerDelegated(user1) == _balanceUser1);
        assert(daoGT.votingPowerReceived(user2) == 0);
        assert(daoGT.votingPowerReceived(user3) == _balanceUser1);

        assert(daoGT.getVotingPower(user1) == 0);
        assert(daoGT.getVotingPower(user2) == _balanceUser2);
        assert(daoGT.getVotingPower(user3) == _balanceUser1 + _balanceUser3);

        vm.stopPrank();
    }

    function testRevertUndelegate_NoActive() external {
        mintToUser1();
        vm.startPrank(user1);
        vm.expectRevert("No active delegation");
        daoGT.undelegate();
        vm.stopPrank();
    }

    function testUndelegate() external {
        mintToUser1();
        vm.startPrank(user1);
        uint256 _balanceUser1 = daoGT.balanceOf(user1);

        daoGT.delegate(user2);

        assert(daoGT.delegatedTo(user1) == user2);
        assert(daoGT.votingPowerDelegated(user1) == _balanceUser1);
        assert(daoGT.votingPowerReceived(user2) == _balanceUser1);

        daoGT.undelegate();

        assert(daoGT.delegatedTo(user1) == address(0));
        assert(daoGT.votingPowerDelegated(user1) == 0);
        assert(daoGT.votingPowerReceived(user2) == 0);

        vm.stopPrank();
    }

    function testDelegate_AfterDoTransfer() external {
        mintToUser1();
        mintToUser2();
        mintToUser3();
        vm.startPrank(user1);

        uint256 _balanceUser1 = daoGT.balanceOf(user1);
        uint256 _balanceUser3 = daoGT.balanceOf(user3);
        
        daoGT.delegate(user2);

        assert(daoGT.delegatedTo(user1) == user2);
        assert(daoGT.votingPowerDelegated(user1) == _balanceUser1);
        assert(daoGT.votingPowerReceived(user2) == _balanceUser1);

        vm.stopPrank();

        vm.startPrank(user3);

        daoGT.delegate(user4);

        assert(daoGT.delegatedTo(user3) == user4);
        assert(daoGT.votingPowerDelegated(user3) == _balanceUser3);
        assert(daoGT.votingPowerReceived(user4) == _balanceUser3);
        
        uint256 _amountToTranfer = 1000 * 1e18;
        daoGT.transfer(user1, _amountToTranfer);

        assert(daoGT.votingPowerDelegated(user1) == _balanceUser1 + _amountToTranfer);
        assert(daoGT.votingPowerReceived(user2) == _balanceUser1 + _amountToTranfer);

        assert(daoGT.votingPowerDelegated(user3) == _balanceUser3 - _amountToTranfer);
        assert(daoGT.votingPowerReceived(user4) == _balanceUser3 - _amountToTranfer);

        uint256 _balanceUser1After = daoGT.balanceOf(user1);
        uint256 _balanceUser3After = daoGT.balanceOf(user3);

        assert(_balanceUser1 + _amountToTranfer == _balanceUser1After);
        assert(_balanceUser3 - _amountToTranfer == _balanceUser3After);

        vm.stopPrank();
    }

    function testRevertCreateProposal_NotEnoughPower() external {
        vm.startPrank(user1);
        address _recipient = vm.randomAddress();
        string memory _description = "Test";
        address _tokenPayment = address(0);
        uint256 _amount = 1 ether;
        uint256 _startTime = 1000;
        uint256 _endTime = _startTime + 1 days;
        vm.expectRevert("Not enough voting power to create proposals");
        daoCore.createProposal(_recipient, _description, _tokenPayment, _amount, _startTime, _endTime);
        vm.stopPrank();
    }

    function testRevertCreateProposal_InvalidRecipient() external {
        mintToUser1();
        vm.startPrank(user1);
        address _recipient = address(0);
        string memory _description = "Test";
        address _tokenPayment = address(0);
        uint256 _amount = 1 ether;
        uint256 _startTime = 1000;
        uint256 _endTime = _startTime + 1 days;
        vm.expectRevert("Invalid recipient");
        daoCore.createProposal(_recipient, _description, _tokenPayment, _amount, _startTime, _endTime);
        vm.stopPrank();
    }

    function testRevertCreateProposal_DescriptionEmpty() external {
        mintToUser1();
        vm.startPrank(user1);
        address _recipient = vm.randomAddress();
        string memory _description = "";
        address _tokenPayment = address(0);
        uint256 _amount = 1 ether;
        uint256 _startTime = 1000;
        uint256 _endTime = _startTime + 1 days;
        vm.expectRevert("Description is empty");
        daoCore.createProposal(_recipient, _description, _tokenPayment, _amount, _startTime, _endTime);
        vm.stopPrank();
    }

    function testRevertCreateProposal_GreaterZero() external {
        mintToUser1();
        vm.startPrank(user1);
        address _recipient = vm.randomAddress();
        string memory _description = "Test";
        address _tokenPayment = address(0);
        uint256 _amount = 0;
        uint256 _startTime = 1000;
        uint256 _endTime = _startTime + 1 days;
        vm.expectRevert("Amount must be greater that 0");
        daoCore.createProposal(_recipient, _description, _tokenPayment, _amount, _startTime, _endTime);
        vm.stopPrank();
    }

    function testRevertCreateProposal_BeforeTimestamp() external {
        mintToUser1();
        vm.warp(1001);
        vm.startPrank(user1);
        address _recipient = vm.randomAddress();
        string memory _description = "Test";
        address _tokenPayment = address(0);
        uint256 _amount = 1 ether;
        uint256 _startTime = 1000;
        uint256 _endTime = _startTime + 1 days;
        vm.expectRevert("Startime can not be before current timestamp");
        daoCore.createProposal(_recipient, _description, _tokenPayment, _amount, _startTime, _endTime);
        vm.stopPrank();
    }

    function testRevertCreateProposal_NotEnoughDuration() external {
        mintToUser1();
        vm.startPrank(user1);
        address _recipient = vm.randomAddress();
        string memory _description = "Test";
        address _tokenPayment = address(0);
        uint256 _amount = 1 ether;
        uint256 _startTime = 1000;
        uint256 _endTime = _startTime + 1 days;
        vm.expectRevert("Endtime have to be more that the minimum duration");
        daoCore.createProposal(_recipient, _description, _tokenPayment, _amount, _startTime, _endTime);
        vm.stopPrank();
    }

    function testCreateProposal() external {
        mintToUser1();
        vm.startPrank(user1);
        address _recipient = vm.randomAddress();
        string memory _description = "Test";
        address _tokenPayment = address(0);
        uint256 _amount = 1 ether;
        uint256 _startTime = 1000;
        uint256 _endTime = _startTime + 1 days + 1 seconds;
        daoCore.createProposal(_recipient, _description, _tokenPayment, _amount, _startTime, _endTime);

        ProposalCopy memory _proposal = getProposal(0);
        assert(user1 == _proposal.proposer);
        assert(_recipient == _proposal.recipient);
        assert(keccak256(abi.encodePacked(_description)) == keccak256(abi.encodePacked(_proposal.description)));
        assert(_tokenPayment == _proposal.token);
        assert(_amount == _proposal.amount);
        assert(_startTime == _proposal.startTime);
        assert(_endTime == _proposal.endTime);
        assert(daoCore.proposalCounter() == 1);
        vm.stopPrank();
    }

    function testRevertCancelProposal_DoesNotExist() external {
        vm.startPrank(user1);
        vm.expectRevert("Proposal does not exist");
        daoCore.cancelProposal(0);
        vm.stopPrank();
    }

    function testRevertCancelProposal_NotAuthorized() external {
        mintToUser1();
        createProposal();
        vm.startPrank(user2);

        vm.expectRevert("Not authorized to cancel");
        daoCore.cancelProposal(0);

        vm.stopPrank();
    }

    function testCancelProposal() external {
        mintToUser1();
        createProposal();
        vm.startPrank(user1);

        ProposalCopy memory _proposalBefore = getProposal(0);
        assert(!_proposalBefore.canceled);

        daoCore.cancelProposal(0);
        ProposalCopy memory _proposalAfter = getProposal(0);
        assert(_proposalAfter.canceled);

        vm.stopPrank();
    }

    function testRevertVote_DoesNotExist() external {
        vm.startPrank(user1);
        vm.expectRevert("Proposal does not exist");
        daoCore.vote(0, true);
        vm.stopPrank();
    }

    function testRevertVote_IsCanceled() external {
        mintToUser1();
        createProposal();
        vm.startPrank(user1);

        daoCore.cancelProposal(0);
        vm.expectRevert("Proposal is canceled");
        daoCore.vote(0, true);

        vm.stopPrank();
    }

    function testRevertVote_NotStartYet() external {
        mintToUser1();
        createProposal();
        vm.startPrank(user1);

        vm.expectRevert("Proposal does not start yet");
        daoCore.vote(0, true);

        vm.stopPrank();
    }

    function testRevertVote_AlreadyEnded() external {
        mintToUser1();
        createProposal();
        vm.warp(2 days);
        vm.startPrank(user1);
        
        vm.expectRevert("Proposal already ended");
        daoCore.vote(0, true);

        vm.stopPrank();
    }

    function testRevertVote_NoVotingPower() external {
        mintToUser1();
        createProposal();
        vm.warp(1 days);
        vm.startPrank(user2);

        vm.expectRevert("No voting power");
        daoCore.vote(0, true);

        vm.stopPrank();
    }

    function testRevertVote_AlreadyVoted() external {
        mintToUser1();
        createProposal();
        vm.warp(1 days);
        vm.startPrank(user1);

        daoCore.vote(0, true);
        vm.expectRevert("You already voted this proposal");
        daoCore.vote(0, true);

        vm.stopPrank();
    }

    function testVote_For() external {
        mintToUser1();
        mintToUser2();
        createProposal();
        vm.warp(1 days);

        vm.startPrank(user1);
        daoCore.vote(0, true);
        vm.stopPrank();

        vm.startPrank(user2);
        daoCore.vote(0, true);
        vm.stopPrank();

        ProposalCopy memory _proposal = getProposal(0);
        uint256 _votingPowerUser1 = daoGT.getVotingPower(user1);
        uint256 _votingPowerUser2 = daoGT.getVotingPower(user2);
        assert(_votingPowerUser1 + _votingPowerUser2 == _proposal.forVotes);
    }

    function testVote_Against() external {
        mintToUser1();
        mintToUser2();
        mintToUser3();
        createProposal();
        vm.warp(1 days);

        vm.startPrank(user1);
        daoCore.vote(0, true);
        vm.stopPrank();

        vm.startPrank(user2);
        daoCore.vote(0, false);
        vm.stopPrank();

        vm.startPrank(user3);
        daoCore.vote(0, false);
        vm.stopPrank();

        ProposalCopy memory _proposal = getProposal(0);
        uint256 _votingPowerUser1 = daoGT.getVotingPower(user1);
        uint256 _votingPowerUser2 = daoGT.getVotingPower(user2);
        uint256 _votingPowerUser3 = daoGT.getVotingPower(user3);
        assert(_votingPowerUser1 == _proposal.forVotes);
        assert(_votingPowerUser2 + _votingPowerUser3 == _proposal.againstVotes);
    }

    function testRevertExecuteProposal_DoesNotExist() external {
        vm.startPrank(user1);
        vm.expectRevert("Proposal does not exist");
        daoCore.executeProposal(0);
        vm.stopPrank();
    }

    function testRevertExecuteProposal_IsCanceled() external {
        mintToUser1();
        createProposal();
        vm.startPrank(user1);
        daoCore.cancelProposal(0);

        vm.expectRevert("Proposal is canceled");
        daoCore.executeProposal(0);

        vm.stopPrank();
    }

    function testRevertExecuteProposal_DoesNotEnd() external {
        mintToUser1();
        createProposal();
        vm.warp(1 days);
        vm.startPrank(user1);

        vm.expectRevert("Proposal does not end yet");
        daoCore.executeProposal(0);

        vm.stopPrank();
    }

    function testRevertExecuteProposal_NotEnoughVotes() external {
        mintToUser1();
        createProposal();
        vm.warp(2 days);
        vm.startPrank(user1);

        vm.expectRevert("Not enough votes");
        daoCore.executeProposal(0);

        vm.stopPrank();
    }

    function testRevertExecuteProposal_ResultAgainst() external {
        mintToUser1();
        mintToUser2();
        mintToUser3();
        createProposal();
        vm.warp(1 days);
        
        vm.startPrank(user3);
        daoCore.vote(0, false);
        vm.stopPrank();

        vm.startPrank(user2);
        daoCore.vote(0, true);

        vm.warp(2 days);
        vm.expectRevert("The result of the proposal is against");
        daoCore.executeProposal(0);

        vm.stopPrank();
    }

    function testRevertExecuteProposal_AlreadyExecuted() external {
        mintToUser1();
        mintToUser2();
        mintToUser3();
        createProposal();
        vm.warp(1 days);
        vm.deal(address(daoTreasury), 2 ether);
        
        vm.startPrank(user3);
        daoCore.vote(0, true);
        vm.stopPrank();

        vm.startPrank(user2);
        daoCore.vote(0, false);

        vm.warp(2 days);
        daoCore.executeProposal(0);
        vm.expectRevert("Proposal already executed");
        daoCore.executeProposal(0);

        vm.stopPrank();
    }

    function testExecuteProposal() external {
        mintToUser1();
        mintToUser2();
        mintToUser3();
        createProposal();
        vm.warp(1 days);
        vm.deal(address(daoTreasury), 2 ether);

        uint256 _treasuryBalanceBefore = address(daoTreasury).balance;
        uint256 _recipientBalanceBefore = recipientTest.balance;
        
        vm.startPrank(user3);
        daoCore.vote(0, true);
        vm.stopPrank();

        vm.startPrank(user2);
        daoCore.vote(0, false);

        vm.warp(2 days);
        daoCore.executeProposal(0);
        vm.stopPrank();

        ProposalCopy memory _proposal = getProposal(0);

        uint256 _treasuryBalanceAfter = address(daoTreasury).balance;
        uint256 _recipientBalanceAfter = recipientTest.balance;
        assert(_treasuryBalanceBefore - _proposal.amount == _treasuryBalanceAfter);
        assert(_recipientBalanceBefore + _proposal.amount == _recipientBalanceAfter);
        assert(_proposal.executed);
    }




    function testRevertSetGovernanceToken_NotOwner() external {
        vm.startPrank(user1);
        address _newGovernanceToken = address(1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        daoCore.setGovernanceToken(_newGovernanceToken);
        vm.stopPrank();
    }
    
    function testRevertSetGovernanceToken_InvalidAddress() external {
        vm.startPrank(deployer);
        address _newGovernanceToken = address(0);
        vm.expectRevert("Invalid token address");
        daoCore.setGovernanceToken(_newGovernanceToken);
        vm.stopPrank();
    }

    function testSetGovernanceToken() external {
        vm.startPrank(deployer);
        address _newGovernanceToken = address(1);
        assert(_newGovernanceToken != address(daoCore.governanceToken()));
        daoCore.setGovernanceToken(_newGovernanceToken);
        assert(_newGovernanceToken == address(daoCore.governanceToken()));

        vm.stopPrank();
    }

    function testRevertSetTreasury_NotOwner() external {
        vm.startPrank(user1);
        address _newTreasury = address(1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        daoCore.setTreasury(_newTreasury);
        vm.stopPrank();
    }
    
    function testRevertSetTreasury_InvalidAddress() external {
        vm.startPrank(deployer);
        address _newTreasury = address(0);
        vm.expectRevert("Invalid treasury address");
        daoCore.setTreasury(_newTreasury);
        vm.stopPrank();
    }

    function testSetTreasury() external {
        vm.startPrank(deployer);
        address _newTreasury = address(1);
        assert(_newTreasury != address(daoCore.treasury()));
        daoCore.setTreasury(_newTreasury);
        assert(_newTreasury == address(daoCore.treasury()));
        vm.stopPrank();
    }

    function testRevertSetThresholdVotes_NotOwner() external {
        vm.startPrank(user1);
        uint256 _newThreshold = 100;
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        daoCore.setThresholdVotes(_newThreshold);
        vm.stopPrank();
    }
    
    function testRevertSetThresholdVotes_GreaterZero() external {
        vm.startPrank(deployer);
        uint256 _newThreshold = 0;
        vm.expectRevert("Threshold must be greater that 0");
        daoCore.setThresholdVotes(_newThreshold);
        vm.stopPrank();
    }

    function testSetThresholdVotes() external {
        vm.startPrank(deployer);
        uint256 _newThreshold = 100;
        assert(_newThreshold != daoCore.thresholdVotes());
        daoCore.setThresholdVotes(_newThreshold);
        assert(_newThreshold == daoCore.thresholdVotes());
        vm.stopPrank();
    }

    function testRevertSetMinimumDuration_NotOwner() external {
        vm.startPrank(user1);
        uint256 _newMinimumDuration = 100;
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        daoCore.setMinimumDuration(_newMinimumDuration);
        vm.stopPrank();
    }
    
    function testRevertSetMinimumDuration_GreaterZero() external {
        vm.startPrank(deployer);
        uint256 _newMinimumDuration = 0;
        vm.expectRevert("Minimum duration must be greater that 0");
        daoCore.setMinimumDuration(_newMinimumDuration);
        vm.stopPrank();
    }

    function testSetMinimumDuration() external {
        vm.startPrank(deployer);
        uint256 _newMinimumDuration = 100;
        assert(_newMinimumDuration != daoCore.minimumProposalDuration());
        daoCore.setMinimumDuration(_newMinimumDuration);
        assert(_newMinimumDuration == daoCore.minimumProposalDuration());
        vm.stopPrank();
    }

    function testRevertSpendFunds_NotDAO() external {
        vm.startPrank(deployer);
        address _recipient = recipientTest;
        address _token = address(0);
        uint256 _amount = 1 ether;
        vm.expectRevert("Only DAO can spend funds");
        daoTreasury.spendFunds(_recipient, _token, _amount);
        vm.stopPrank();
    }

    function testRevertSpendFunds_InvalidAddress() external {
        vm.startPrank(address(daoCore));
        address _recipient = address(0);
        address _token = address(0);
        uint256 _amount = 1 ether;
        vm.expectRevert("Invalid address");
        daoTreasury.spendFunds(_recipient, _token, _amount);
        vm.stopPrank();
    }

    function testRevertSpendFunds_GreaterZero() external {
        vm.startPrank(address(daoCore));
        address _recipient = recipientTest;
        address _token = address(0);
        uint256 _amount = 0;
        vm.expectRevert("Amount must be greater that 0");
        daoTreasury.spendFunds(_recipient, _token, _amount);
        vm.stopPrank();
    }

    function testRevertSpendFunds_NotEnoughEther() external {
        vm.startPrank(address(daoCore));
        address _recipient = recipientTest;
        address _token = address(0);
        uint256 _amount = 1 ether;
        vm.expectRevert("Not enough ether balance");
        daoTreasury.spendFunds(_recipient, _token, _amount);
        vm.stopPrank();
    }

    function testRevertSpendFunds_NotEnoughTokens() external {
        vm.startPrank(address(daoCore));
        address _recipient = recipientTest;
        address _token = address(daoGT);
        uint256 _amount = 1 ether;
        vm.expectRevert("Not enough token balance");
        daoTreasury.spendFunds(_recipient, _token, _amount);
        vm.stopPrank();
    }

    function testSpendFunds() external {
        vm.deal(address(daoTreasury), 2 ether);
        uint256 _treasuryBalanceBefore = address(daoTreasury).balance;
        uint256 _recipientBalanceBefore = recipientTest.balance;

        vm.startPrank(address(daoCore));
        address _recipient = recipientTest;
        address _token = address(0);
        uint256 _amount = 1 ether;
        daoTreasury.spendFunds(_recipient, _token, _amount);
        vm.stopPrank();

        uint256 _treasuryBalanceAfter = address(daoTreasury).balance;
        uint256 _recipientBalanceAfter = recipientTest.balance;

        assert(_treasuryBalanceBefore - _amount == _treasuryBalanceAfter);
        assert(_recipientBalanceBefore + _amount == _recipientBalanceAfter);
    }

    function testRevertFundTreasuryWithEther_NoEther() external {
        vm.deal(user1, 2 ether);
        vm.startPrank(user1);
        vm.expectRevert("No ether in msg.value");
        daoTreasury.fundTreasuryWithEther{value: 0 ether}();
        vm.stopPrank();
    }

    function testFundTreasuryWithEther() external {
        vm.deal(user1, 2 ether);
        uint256 _treasuryBalanceBefore = address(daoTreasury).balance;
        uint256 _userBalanceBefore = user1.balance;

        vm.startPrank(user1);
        daoTreasury.fundTreasuryWithEther{value: 1 ether}();
        vm.stopPrank();

        uint256 _treasuryBalanceAfter = address(daoTreasury).balance;
        uint256 _userBalanceAfter = user1.balance;

        assert(_treasuryBalanceBefore + 1 ether == _treasuryBalanceAfter);
        assert(_userBalanceBefore - 1 ether == _userBalanceAfter);
    }

    function testRevertFundTreasuryWithToken_InvalidTokenAddress() external {
        vm.startPrank(user1);
        address _token = address(0);
        uint256 _amount = 500 * 1e18;
        vm.expectRevert("Invalid token address");
        daoTreasury.fundTreasuryWithToken(_token, _amount);
        vm.stopPrank();
    }

    function testRevertFundTreasuryWithToken_GreaterZero() external {
        vm.startPrank(user1);
        address _token = address(daoGT);
        uint256 _amount = 0;
        vm.expectRevert("Amount must be greater that 0");
        daoTreasury.fundTreasuryWithToken(_token, _amount);
        vm.stopPrank();
    }

    function testRevertFundTreasuryWithToken_NotEnoughBalance() external {
        vm.startPrank(user1);
        address _token = address(daoGT);
        uint256 _amount = 500 * 1e18;
        vm.expectRevert("Not enough balance");
        daoTreasury.fundTreasuryWithToken(_token, _amount);
        vm.stopPrank();
    }

    function testRevertFundTreasuryWithToken_NotEnoughAllowance() external {
        mintToUser1();
        vm.startPrank(user1);
        address _token = address(daoGT);
        uint256 _amount = 500 * 1e18;
        vm.expectRevert("Not enough allowance");
        daoTreasury.fundTreasuryWithToken(_token, _amount);
        vm.stopPrank();
    }

    function testFundTreasuryWithToken() external {
        mintToUser1();

        uint256 _treasuryBalanceBefore = IERC20(daoGT).balanceOf(address(daoTreasury));
        uint256 _userBalanceBefore = IERC20(daoGT).balanceOf(user1);

        vm.startPrank(user1);
        address _token = address(daoGT);
        uint256 _amount = 500 * 1e18;
        daoGT.approve(address(daoTreasury), 1000 * 1e18);
        daoTreasury.fundTreasuryWithToken(_token, _amount);
        vm.stopPrank();
        
        uint256 _treasuryBalanceAfter = IERC20(daoGT).balanceOf(address(daoTreasury));
        uint256 _userBalanceAfter = IERC20(daoGT).balanceOf(user1);

        assert(_treasuryBalanceBefore + _amount == _treasuryBalanceAfter);
        assert(_userBalanceBefore - _amount == _userBalanceAfter);
    }
    
    function testRevertSetDAO_NotOwner() external {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        daoTreasury.setDAO(address(1));
        vm.stopPrank();
    }

    function testRevertSetDAO_InvalidAddress() external {
        vm.startPrank(deployer);
        vm.expectRevert("Invalid address");
        daoTreasury.setDAO(address(0));
        vm.stopPrank();
    }

    function testSetDAO() external {
        vm.startPrank(deployer);
        daoTreasury.setDAO(address(1));
        assert(daoTreasury.dao() == address(1));
        vm.stopPrank();
    }

    function testRevertEmergencyWithdraw_NotOwner() external {
        vm.startPrank(user1);
        address _token = address(0);
        uint256 _amount = 0;
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        daoTreasury.emergencyWithdraw(_token, _amount);
        vm.stopPrank();
    }

    function testRevertEmergencyWithdraw_EtherTransferFailed() external {
        vm.startPrank(deployer);
        address _token = address(0);
        uint256 _amount = 5 ether;
        vm.expectRevert("Ether transfer failed");
        daoTreasury.emergencyWithdraw(_token, _amount);
        vm.stopPrank();
    }

    function testEmergencyWithdraw_FullBalanceEther() external {
        vm.deal(address(daoTreasury), 10 ether);

        uint256 _treasuryBalanceBefore = address(daoTreasury).balance;
        uint256 _deployerBalanceBefore = deployer.balance;

        vm.startPrank(deployer);
        address _token = address(0);
        uint256 _amount = 0;
        daoTreasury.emergencyWithdraw(_token, _amount);
        vm.stopPrank();

        uint256 _treasuryBalanceAfter = address(daoTreasury).balance;
        uint256 _deployerBalanceAfter = deployer.balance;

        assert(_treasuryBalanceBefore - _treasuryBalanceBefore == _treasuryBalanceAfter);
        assert(_deployerBalanceBefore + _treasuryBalanceBefore == _deployerBalanceAfter);
    }

    function testEmergencyWithdraw_PartialBalanceEther() external {
        vm.deal(address(daoTreasury), 10 ether);

        uint256 _treasuryBalanceBefore = address(daoTreasury).balance;
        uint256 _deployerBalanceBefore = deployer.balance;

        vm.startPrank(deployer);
        address _token = address(0);
        uint256 _amount = 5 ether;
        daoTreasury.emergencyWithdraw(_token, _amount);
        vm.stopPrank();

        uint256 _treasuryBalanceAfter = address(daoTreasury).balance;
        uint256 _deployerBalanceAfter = deployer.balance;

        assert(_treasuryBalanceBefore - _amount == _treasuryBalanceAfter);
        assert(_deployerBalanceBefore + _amount == _deployerBalanceAfter);
    }

    function testEmergencyWithdraw_FullBalanceToken() external {
        mintToTreasury();

        uint256 _treasuryBalanceBefore = IERC20(daoGT).balanceOf(address(daoTreasury));
        uint256 _deployerBalanceBefore = IERC20(daoGT).balanceOf(address(deployer));

        vm.startPrank(deployer);
        address _token = address(daoGT);
        uint256 _amount = 0;
        daoTreasury.emergencyWithdraw(_token, _amount);
        vm.stopPrank();

        uint256 _treasuryBalanceAfter = IERC20(daoGT).balanceOf(address(daoTreasury));
        uint256 _deployerBalanceAfter = IERC20(daoGT).balanceOf(address(deployer));

        assert(_treasuryBalanceBefore - _treasuryBalanceBefore == _treasuryBalanceAfter);
        assert(_deployerBalanceBefore + _treasuryBalanceBefore == _deployerBalanceAfter);
    }

    function testEmergencyWithdraw_PartialBalanceToken() external {
        mintToTreasury();

        uint256 _treasuryBalanceBefore = IERC20(daoGT).balanceOf(address(daoTreasury));
        uint256 _deployerBalanceBefore = IERC20(daoGT).balanceOf(address(deployer));

        vm.startPrank(deployer);
        address _token = address(daoGT);
        uint256 _amount = 2500 * 1e18;
        daoTreasury.emergencyWithdraw(_token, _amount);
        vm.stopPrank();

        uint256 _treasuryBalanceAfter = IERC20(daoGT).balanceOf(address(daoTreasury));
        uint256 _deployerBalanceAfter = IERC20(daoGT).balanceOf(address(deployer));

        assert(_treasuryBalanceBefore - _amount == _treasuryBalanceAfter);
        assert(_deployerBalanceBefore + _amount == _deployerBalanceAfter);
    }

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "forge-std/console.sol"; 
import "../src/TWAML.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {
        _mint(msg.sender, 10000 * 10 ** decimals()); // Mint some tokens for testing
    }
}

contract InnovativeTWAMLTest is Test {
    InnovativeTWAML public twAML;
    MockERC20 public stakingToken;
    address public contractOwner;

    function setUp() public {
        // Deploy the mock ERC20 token
        stakingToken = new MockERC20();
        
        // Set the owner address (the address running the tests)
        contractOwner = address(this);

        // Deploy the InnovativeTWAML contract and initialize it
        twAML = new InnovativeTWAML();
        twAML.initialize(stakingToken, 1 days, 30 days, 100, contractOwner);
        twAML.setRewardRate(2);
    }

    function testInitialParameters() public {
        assertEq(twAML.minLockTime(), 1 days);
        assertEq(twAML.maxLockTime(), 30 days);
        assertEq(twAML.maxWeeklyWeightIncrease(), 100);
        assertEq(twAML.contractOwner(), contractOwner);
    }

    function testStake() public {
        uint256 stakeAmount = 1000 * 10 ** stakingToken.decimals();
        
        // Transfer tokens to the test contract
        stakingToken.transfer(address(this), stakeAmount);
        stakingToken.approve(address(twAML), stakeAmount);

        // Stake tokens
        twAML.stake(stakeAmount, 7 days);

        // Check user info after staking
       InnovativeTWAML.UserInfo memory user = twAML.getUserInfo(address(this));
        assertEq(user.amount, stakeAmount);
        assertEq(user.lockEndTime, block.timestamp + 7 days);
    }


    function testGetReward() public {
        uint256 stakeAmount = 10 * 10 ** stakingToken.decimals();
        
        // Transfer tokens to the test contract and stake them first
        stakingToken.transfer(address(this), stakeAmount);
        stakingToken.approve(address(twAML), stakeAmount);
        twAML.stake(stakeAmount, 7 days);

        // Simulate some time passing for reward calculation
        vm.warp(block.timestamp + 1 weeks); // Move time forward

        // Set reward rate and update rewards
        twAML.setRewardRate(10); // Example reward rate

        uint256 initialBalance = stakingToken.balanceOf(address(this));
        
        // Get rewards
        (uint256 reward1, uint256 userWeight, uint256 userRewardDebt, uint256 _accRewardPerShare) = twAML.getReward();
        console.log('reward', reward1);
        console.log('user.weight', userWeight);
        console.log('user.rewardDebt',userRewardDebt);
        console.log('accRewardPerShare', _accRewardPerShare);

        uint256 finalBalance = stakingToken.balanceOf(address(this));
        console.log('initialBalance: ', initialBalance);
        console.log('finalBalance: ',finalBalance);
        assert(finalBalance > initialBalance); // Ensure rewards were received
    }

        function testWithdraw() public {
        uint256 stakeAmount = 1000 * 10 ** stakingToken.decimals();
        
        // Transfer tokens to the test contract and stake them first
        stakingToken.approve(address(twAML), stakeAmount);
        twAML.stake(stakeAmount, 7 days);

        // Fast forward time to allow withdrawal
        vm.warp(block.timestamp + 7 days + 1); // Move past lock period

        // Withdraw tokens
        twAML.withdraw();

        // Check user info after withdrawal
        InnovativeTWAML.UserInfo memory user = twAML.getUserInfo(address(this));
        assertEq(user.amount, 0); // Should be zero after withdrawal
    }

    function testEmergencyWithdraw() public {
        uint256 stakeAmount = 1000 * 10 ** stakingToken.decimals();
        
        // Transfer tokens to the test contract and stake them first
        stakingToken.approve(address(twAML), stakeAmount);
        twAML.stake(stakeAmount, 7 days);

        // Emergency withdraw
        twAML.emergencyWithdraw();

        // Check user info after emergency withdrawal
       InnovativeTWAML.UserInfo memory user = twAML.getUserInfo(address(this));
        
        assertEq(user.amount, 0); // Should be zero after emergency withdrawal
    }

    function testUpdateReward() public {
        uint256 stakeAmount = 1000 * 10 ** stakingToken.decimals();
        
        // Stake tokens with a lock duration of 7 days
        stakingToken.approve(address(twAML), stakeAmount);
        twAML.stake(stakeAmount, 7 days);

        // Set reward rate and fast forward time
        twAML.setRewardRate(10); // Set a reward rate of 10
        vm.warp(block.timestamp + 1 weeks); // Move time forward

        // Update rewards for the user
        twAML.updateReward(address(this));

        // Calculate expected accRewardPerShare increase
        uint256 newWeight = TWAMLMath.computeWeight(stakeAmount, 7 days, twAML.maxWeeklyWeightIncrease());
        
        uint256 expectedReward = (10 * (7 days)) * 1e18 / newWeight; // Calculate expected accRewardPerShare increase

        // Assert that accRewardPerShare has been updated correctly
        assertEq(twAML.accRewardPerShare(), expectedReward);
    }


    function testUpdateParameters() public {
        uint256 newMinLockTime = 2 days;
        uint256 newMaxLockTime = 15 days;
        
        // Update parameters as owner
        twAML.updateParameters(newMinLockTime, newMaxLockTime, 200);
        // Check that parameters are updated correctly
        assertEq(twAML.minLockTime(), newMinLockTime);
        assertEq(twAML.maxLockTime(), newMaxLockTime);
    }


}
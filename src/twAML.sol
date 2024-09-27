// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import "./TWAMLMath.sol";

contract InnovativeTWAML is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using TWAMLMath for uint256;

    IERC20 public stakingToken;
    
    struct UserInfo {
        uint256 amount;
        uint256 weight;
        uint256 lockEndTime;
        uint256 lastUpdateTime;
        uint256 rewardDebt;
        uint8 tier;
    }

    mapping(address => UserInfo) public userInfo;
    
    uint256 public totalStaked;
    uint256 public totalWeight;
    uint256 public accRewardPerShare;
    uint256 public lastRewardTime;
    uint256 public rewardRate;

    uint256 public minLockTime;
    uint256 public maxLockTime;
    uint256 public maxWeeklyWeightIncrease;
    address public contractOwner;

    event Staked(address indexed user, uint256 amount, uint256 lockDuration);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event ParametersUpdated(uint256 minLockTime, uint256 maxLockTime, uint256 maxWeeklyWeightIncrease);

    function initialize(
        IERC20 _stakingToken,
        uint256 _minLockTime,
        uint256 _maxLockTime,
        uint256 _maxWeeklyWeightIncrease,
        address _contractOwner
    ) public initializer {
        __Ownable_init(_contractOwner);
        __ReentrancyGuard_init();
        __Pausable_init();

        contractOwner = _contractOwner;
        stakingToken = _stakingToken;
        minLockTime = _minLockTime;
        maxLockTime = _maxLockTime;
        maxWeeklyWeightIncrease = _maxWeeklyWeightIncrease;
    }

    function stake(uint256 _amount, uint256 _lockDuration) external nonReentrant whenNotPaused {
        require(_amount > 0, "Cannot stake 0");
        require(_lockDuration >= minLockTime && _lockDuration <= maxLockTime, "Invalid lock duration");

        updateReward(msg.sender);

        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        UserInfo storage user = userInfo[msg.sender];
        user.amount += _amount;
        user.lockEndTime = block.timestamp + _lockDuration;
        user.lastUpdateTime = block.timestamp;

        uint256 newWeight = TWAMLMath.computeWeight(_amount, _lockDuration, maxWeeklyWeightIncrease);
        user.weight = TWAMLMath.safeAdd(user.weight, newWeight);

        totalStaked += _amount;
        totalWeight = TWAMLMath.safeAdd(totalWeight, newWeight);

        emit Staked(msg.sender, _amount, _lockDuration);
    }

    function withdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(block.timestamp >= user.lockEndTime, "Lock period not ended");

        updateReward(msg.sender);

        uint256 amount = user.amount;
        require(amount > 0, "Nothing to withdraw");

        user.amount = 0;
        totalStaked -= amount;
        totalWeight -= user.weight;
        user.weight = 0;

        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() external nonReentrant {
        updateReward(msg.sender);
        UserInfo storage user = userInfo[msg.sender];
        uint256 reward = (user.weight * accRewardPerShare / 1e18) - user.rewardDebt;
        if (reward > 0) {
            user.rewardDebt = user.weight * accRewardPerShare / 1e18;
            stakingToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function updateReward(address _account) public {
        if (block.timestamp > lastRewardTime) {
            if (totalWeight > 0) {
                uint256 timeElapsed = block.timestamp - lastRewardTime;
                uint256 reward = timeElapsed * rewardRate;
                accRewardPerShare += reward * 1e18 / totalWeight;
            }
            lastRewardTime = block.timestamp;
        }
        if (_account != address(0)) {
            UserInfo storage user = userInfo[_account];
            user.rewardDebt = user.weight * accRewardPerShare / 1e18;
        }
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        updateReward(address(0));
        rewardRate = _rewardRate;
    }

    function updateParameters(
        uint256 _minLockTime,
        uint256 _maxLockTime,
        uint256 _maxWeeklyWeightIncrease
    ) external onlyOwner {
        require(_minLockTime <= _maxLockTime, "Invalid lock times");
        minLockTime = _minLockTime;
        maxLockTime = _maxLockTime;
        maxWeeklyWeightIncrease = _maxWeeklyWeightIncrease;
        emit ParametersUpdated(_minLockTime, _maxLockTime, _maxWeeklyWeightIncrease);
    }

    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.amount;
        require(amount > 0, "Nothing to withdraw");

        user.amount = 0;
        user.weight = 0;
        user.rewardDebt = 0;
        totalStaked -= amount;
        totalWeight -= user.weight;

        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getSystemHealth() public view returns (
        uint256 _totalStaked,
        uint256 _totalWeight,
        uint256 _participantCount
    ) {
        return (totalStaked, totalWeight, totalWeight > 0 ? totalStaked / totalWeight : 0);
    }

    function getUserInfo(address account) public view returns (UserInfo memory) {
        return userInfo[account];
    }
}
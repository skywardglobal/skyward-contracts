// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/* ----------------------------------------- Imports ------------------------------------------ */

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/* -------------------------------------- Main Contract --------------------------------------- */

contract Skyvault_0 is Ownable {

    using SafeERC20 for IERC20;

    /* ------------------------------------ State Variables ----------------------------------- */

    IERC20 public immutable skywardToken;
    address public immutable skyRewards;
    bool public poolOpened;
    uint256 public poolOpenedTime;
    uint256 public poolClosedTime;
    uint256 public totalStaked;

    struct staker {
        uint256 owedRewards;
        uint256 stakerBalance;
        uint256 stakeTime;
    }

    mapping (address => staker) public stakers;

    event RewardsCompounded(address staker, uint256 amount);
    event RewardsClaimed(address staker, uint256 amount);
    event Staked(address staker, uint256 amount);
    event Unstaked(address staker, uint256 amount);

    /* --------------------------------- Contract Constructor --------------------------------- */

    constructor(address _skywardToken, address _skyRewards) {
        skywardToken = IERC20(_skywardToken); 
        skyRewards = _skyRewards;
        transferOwnership(msg.sender);
    }

    /* ------------------------------- Main Contract Functions -------------------------------- */

    // Claim pending rewards (manual implementation)
    function claimManual() external {
        require(stakers[msg.sender].stakerBalance > 0 || stakers[msg.sender].owedRewards > 0, "Not a staker");
        uint256 rewards = getPendingRewards();
        require(rewards > 0, "No rewards to claim");
        require(rewards <= skywardToken.balanceOf(skyRewards), "Insufficient rewards in rewards pool");

        skywardToken.safeTransferFrom(skyRewards, msg.sender, rewards);
        if (stakers[msg.sender].owedRewards > 0) {
            stakers[msg.sender].owedRewards = 0;
        }
        
        if (poolOpened) {
            stakers[msg.sender].stakeTime = block.timestamp;
        } else {
            stakers[msg.sender].stakeTime = poolClosedTime;
        }

        emit RewardsClaimed(msg.sender, rewards);
    }

    // Compound pending rewards
    function compound() external {
        require(poolOpened, "Staking pool not open");
        require(stakers[msg.sender].stakerBalance > 0, "Not a staker");
        uint256 rewards = getPendingRewards();
        require(rewards > 0, "No rewards to compound");
        require(rewards <= skywardToken.balanceOf(skyRewards), "Insufficient rewards in rewards pool");

        totalStaked += rewards;
        stakers[msg.sender].stakerBalance += rewards;
        stakers[msg.sender].stakeTime = block.timestamp;
        if (stakers[msg.sender].owedRewards > 0) {
            stakers[msg.sender].owedRewards = 0;
        }

        skywardToken.safeTransferFrom(skyRewards, address(this), rewards);
        emit RewardsCompounded(msg.sender, rewards);
    }

    // Stake the specified amount of tokens
    function stake(uint256 _amount) external {
        require(poolOpened, "Staking pool not open");
        require(skywardToken.balanceOf(msg.sender) > 0, "No wallet balance to stake");
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount <= skywardToken.balanceOf(msg.sender), "Amount greater than wallet balance");

        uint256 rewards = getPendingRewards();
        claim(rewards);

        totalStaked += _amount;
        stakers[msg.sender].stakerBalance += _amount;
        stakers[msg.sender].stakeTime = block.timestamp;

        skywardToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    // Unstake the specified amount of tokens
    function unstake(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(stakers[msg.sender].stakerBalance >= _amount, "Amount must be less than or equal to staked balance");

        uint256 rewards = getPendingRewards();
        claim(rewards);
        
        totalStaked -= _amount;
        stakers[msg.sender].stakerBalance -= _amount;
        if (poolOpened) {
            stakers[msg.sender].stakeTime = block.timestamp;
        } else {
            stakers[msg.sender].stakeTime = poolClosedTime;
        }

        uint256 fees = _amount * 5 / 100;
        _amount -= fees;

        skywardToken.safeTransfer(skyRewards, fees);
        skywardToken.safeTransfer(msg.sender, _amount);
        emit Unstaked(msg.sender, _amount);
    }

    /* ----------------------------------- Owner Functions ------------------------------------ */

    // Open the staking pool
    function openPool() external onlyOwner {
        require(poolOpenedTime == 0, "Staking pool already opened");
        poolOpened = true;
        poolOpenedTime = block.timestamp;
    }

    // Close the staking pool
    function closePool() external onlyOwner {
        require(poolOpened, "Staking pool not open");
        poolOpened = false;
        poolClosedTime = block.timestamp;
    }

    /* ------------------------------- Private Helper Functions ------------------------------- */

    // Claim pending rewards
    function claim(uint256 rewards) private {
        if (rewards > 0) {
            if (rewards > skywardToken.balanceOf(skyRewards)) {
                stakers[msg.sender].owedRewards += rewards - stakers[msg.sender].owedRewards;
            } else {
                skywardToken.safeTransferFrom(skyRewards, msg.sender, rewards);
                if (stakers[msg.sender].owedRewards > 0) {
                    stakers[msg.sender].owedRewards = 0;
                }
            }
        }
    }

    /* -------------------------------- Public View Functions --------------------------------- */

    // Get pending rewards
    function getPendingRewards() public view returns (uint256) { 
        if (poolOpened) {
            return (block.timestamp - stakers[msg.sender].stakeTime) * (getStakerRewardRate() / 86400) + stakers[msg.sender].owedRewards;
        } else {
            return (poolClosedTime - stakers[msg.sender].stakeTime) * (getStakerRewardRate() / 86400) + stakers[msg.sender].owedRewards;
        }
    }

    // Get staked balance
    function getStakerBalance() public view returns (uint256) {
        return stakers[msg.sender].stakerBalance;
    }

    // Get daily reward yield rate
    function getStakerRewardRate() public view returns (uint256) { 
        return stakers[msg.sender].stakerBalance / 100;
    }
}

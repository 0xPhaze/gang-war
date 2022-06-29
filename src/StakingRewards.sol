// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external;

    function transfer(address to, uint256 amount) external;

    function mint(address to, uint256 amount) external;

    function balanceOf(address owner) external view returns (uint256);
}

error CallerNotOwner();

contract Owned {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert CallerNotOwner();
        _;
    }
}

// import "forge-std/console.sol";

// adapted from https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol
contract StakingRewards is Owned {
    /* ========== STATE VARIABLES ========== */

    IERC20 public rewardsToken;
    IERC20 public stakingToken;

    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public totalRewardPerToken;

    mapping(address => uint256) public lastUserRewardPerToken;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _rewardsToken, address _stakingToken) {
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount) external {
        _updateReward(msg.sender);

        totalSupply += amount;
        balanceOf[msg.sender] += amount;
        stakingToken.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public {
        _updateReward(msg.sender);

        totalSupply -= amount;
        balanceOf[msg.sender] -= amount;
        stakingToken.transfer(msg.sender, amount);
    }

    function claimReward() public {
        _updateReward(msg.sender);
    }

    /* ========== MODIFIERS ========== */

    function _updateReward(address account) internal {
        uint256 rpt;

        if (totalSupply != 0)
            rpt = totalRewardPerToken + ((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalSupply;

        totalRewardPerToken = rpt;
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            uint256 reward = (balanceOf[account] * (rpt - lastUserRewardPerToken[account])) / 1e18;
            lastUserRewardPerToken[account] = rpt;
            rewardsToken.mint(account, reward);
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setRewardRate(uint256 rate) external {
        _updateReward(address(0));

        rewardRate = rate;
    }
}

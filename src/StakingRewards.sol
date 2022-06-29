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
    uint256 public totalShares;
    uint256 public lastUpdateTime;

    /*      token   => rpt      */
    mapping(uint256 => uint256) public totalRewardPerToken;
    mapping(uint256 => uint256) public rewardRate;
    mapping(uint256 => IERC20) public rewardsToken;

    /*      user    =>         token   => rpt       */
    mapping(address => mapping(uint256 => uint256)) public lastUserRewardPerToken;
    mapping(address => uint256) public shares;

    /* ------------- Constructor ------------- */

    constructor(address[] memory _rewardsToken) {
        for (uint256 i; i < 3; i++) rewardsToken[i] = IERC20(_rewardsToken[i]);
    }

    /* ------------- External ------------- */

    function enter(uint256 amount) external {
        _updateReward(msg.sender);

        totalShares += amount;
        shares[msg.sender] += amount;
    }

    function exit(uint256 amount) public {
        _updateReward(msg.sender);

        totalShares -= amount;
        shares[msg.sender] -= amount;
    }

    function claim() public {
        _updateReward(msg.sender);
    }

    /* ------------- Internal ------------- */

    function _updateReward(address account) internal {
        uint256 rpt_0;
        uint256 rpt_1;
        uint256 rpt_2;

        if (totalShares != 0) {
            uint256 timeScaled = (block.timestamp - lastUpdateTime) * 1e18;
            rpt_0 = totalRewardPerToken[0] + (timeScaled * rewardRate[0]) / totalShares;
            rpt_1 = totalRewardPerToken[1] + (timeScaled * rewardRate[1]) / totalShares;
            rpt_2 = totalRewardPerToken[2] + (timeScaled * rewardRate[2]) / totalShares;
        }

        totalRewardPerToken[0] = rpt_0;
        totalRewardPerToken[1] = rpt_1;
        totalRewardPerToken[2] = rpt_2;

        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            uint256 share = shares[account];

            rewardsToken[0].mint(account, (share * (rpt_0 - lastUserRewardPerToken[account][0])) / 1e18); //prettier-ignore
            rewardsToken[1].mint(account, (share * (rpt_1 - lastUserRewardPerToken[account][1])) / 1e18); //prettier-ignore
            rewardsToken[2].mint(account, (share * (rpt_2 - lastUserRewardPerToken[account][2])) / 1e18); //prettier-ignore

            lastUserRewardPerToken[account][0] = rpt_0;
            lastUserRewardPerToken[account][1] = rpt_1;
            lastUserRewardPerToken[account][2] = rpt_2;
        }
    }

    /* ------------- Owner ------------- */

    function setRewardRate(uint256[] calldata rate) external onlyOwner {
        _updateReward(address(0));

        rewardRate[0] = rate[0];
        rewardRate[1] = rate[1];
        rewardRate[2] = rate[2];
    }
}

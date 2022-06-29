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

import "forge-std/console.sol";

// adapted from https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol
contract StakingRewards is Owned {
    IERC20[3] public rewardsToken;

    uint256[3] public totalShares;
    uint256[3] public lastUpdateTime;

    uint256[3][3] public totalRewardPerToken;
    uint256[3][3] public rewardRate;

    mapping(address => uint256[3]) public shares;
    mapping(address => uint256[3][3]) public lastUserRewardPerToken;

    /* ------------- Constructor ------------- */

    constructor(address[] memory _rewardsToken) {
        for (uint256 i; i < 3; i++) rewardsToken[i] = IERC20(_rewardsToken[i]);
    }

    /* ------------- External ------------- */

    function enter(uint256 gang, uint256 amount) external {
        _updateReward(gang, msg.sender);

        totalShares[gang] += amount;
        shares[msg.sender][gang] += amount;
    }

    function exit(uint256 gang, uint256 amount) public {
        _updateReward(gang, msg.sender);

        totalShares[gang] -= amount;
        shares[msg.sender][gang] -= amount;
    }

    function claim(uint256 gang) public {
        _updateReward(gang, msg.sender);
    }

    /* ------------- Internal ------------- */

    function _updateReward(uint256 gang, address account) internal {
        uint256 rpt_0 = totalRewardPerToken[gang][0];
        uint256 rpt_1 = totalRewardPerToken[gang][1];
        uint256 rpt_2 = totalRewardPerToken[gang][2];

        uint256 totalShares_ = totalShares[gang];

        if (totalShares_ != 0) {
            uint256 timeScaled = (block.timestamp - lastUpdateTime[gang]) * 1e18;

            rpt_0 += (timeScaled * rewardRate[gang][0]) / totalShares_;
            rpt_1 += (timeScaled * rewardRate[gang][1]) / totalShares_;
            rpt_2 += (timeScaled * rewardRate[gang][2]) / totalShares_;
        }

        totalRewardPerToken[gang][0] = rpt_0;
        totalRewardPerToken[gang][1] = rpt_1;
        totalRewardPerToken[gang][2] = rpt_2;

        lastUpdateTime[gang] = block.timestamp;

        if (account != address(0)) {
            uint256 share = shares[account][gang];

            rewardsToken[0].mint(account, (share * (rpt_0 - lastUserRewardPerToken[account][gang][0])) / 1e18); //prettier-ignore
            rewardsToken[1].mint(account, (share * (rpt_1 - lastUserRewardPerToken[account][gang][1])) / 1e18); //prettier-ignore
            rewardsToken[2].mint(account, (share * (rpt_2 - lastUserRewardPerToken[account][gang][2])) / 1e18); //prettier-ignore

            lastUserRewardPerToken[account][gang][0] = rpt_0;
            lastUserRewardPerToken[account][gang][1] = rpt_1;
            lastUserRewardPerToken[account][gang][2] = rpt_2;
        }
    }

    /* ------------- Owner ------------- */

    function setRewardRate(uint256 gang, uint256[] calldata rate) external onlyOwner {
        _updateReward(gang, address(0));

        rewardRate[gang][0] = rate[0];
        rewardRate[gang][1] = rate[1];
        rewardRate[gang][2] = rate[2];
    }
}

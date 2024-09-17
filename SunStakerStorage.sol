pragma solidity ^0.5.8;



contract SunStakerStorage {

    uint256 internal totalSupply_;
    mapping(address => uint256) internal balanceOf_;
    mapping(address => uint256) public   rewards;
    mapping(address => uint256) public   userRewardOneSunPaid;

    uint256 public starttime;
    uint256 public periodFinish;


    uint256 public rewardRate = 10**18;
    uint256 public lastUpdateTime;
    uint256 public rewardOneSunStored;
    uint256 public rawAll = 0;

    address public gov = msg.sender;

    bool public withdrawOn;

}




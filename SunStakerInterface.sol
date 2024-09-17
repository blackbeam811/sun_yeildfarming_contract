pragma solidity ^0.5.8;

import "./SunStakerStorage.sol";
import "./lib/SafeMath.sol";

contract SunStakerInterface is SunStakerStorage {

    function deposit() public payable ;

    function withdraw(address token) public;

    function lastTimeRewardApplicable() public view returns (uint256);

    function rewardOneSun() public view returns (uint256);

    function earned(address account) public view returns (uint256);

    function earned(address account,address token) public view returns (uint256);

    function totalSupply() public view returns (uint);

    function balanceOf(address guy) public view returns (uint);

}




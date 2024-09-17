import "./SunStakerInterface.sol";

pragma solidity ^0.5.8;


contract SunStaker is SunStakerInterface {
    modifier checkStart() {
        require(block.timestamp >= starttime && block.timestamp < periodFinish,"only in start period");
        _;
    }

    modifier checkEnd() {
        require(block.timestamp >= periodFinish,"not end");
        _;
    }


    using  SafeMath for uint256;
    event  Deposit(address indexed dst, uint sad);
    event  Withdrawal(address indexed src, uint sad);


    function initialize(uint256 _starttime, uint256 _periodFinish) public{
        starttime = _starttime;
        periodFinish = _periodFinish;
    }



    function rewardOneSun() public view returns (uint256) {
        return 0;
    }

    function earned(address account) public view returns (uint256) {
        return 0;
    }

    function earned(address account,address token) public view returns (uint256) {
        return 0;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return min(block.timestamp, periodFinish);
    }


    function deposit() checkStart  public payable {
        require( msg.value > 0,"deposit must gt 0");
        balanceOf_[msg.sender] = balanceOf_[msg.sender].add(msg.value);
        totalSupply_ = totalSupply_.add(msg.value);
        emit Deposit(msg.sender, msg.value);
    }


    function withdraw(address token) checkEnd public {
        uint256 sad = balanceOf_[msg.sender];
        balanceOf_[msg.sender] = 0;
        msg.sender.transfer(sad);
        totalSupply_ = totalSupply_.sub(sad);
        emit Withdrawal(msg.sender, sad);
    }

    function totalSupply() public view returns (uint) {
        return totalSupply_;
    }

    function balanceOf(address guy) public view returns (uint){
        return balanceOf_[guy];
    }


    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }


}




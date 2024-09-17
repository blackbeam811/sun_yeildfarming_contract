import "./SunStakerInterface.sol";

pragma solidity ^0.5.8;


contract SunStakerSimpleStandAlone is SunStakerInterface {
    using  SafeMath for uint256;

    modifier checkStart() {
        require(block.timestamp >= starttime , "not started");
        require(block.timestamp < periodFinish, "already ended");
    _;
    }

    modifier checkEnd() {
        require(block.timestamp >= periodFinish, "not end");
        _;
    }

    event  Rescue(address indexed dst, uint sad);
    event  Deposit(address indexed dst, uint sad);
    event  Withdrawal(address indexed src, uint sad);


    constructor(uint256 _starttime, uint256 _periodFinish) public{
        starttime = _starttime;
        periodFinish = _periodFinish;
    }

    function() external payable {
        deposit();
    }

    function rewardOneSun() public view returns (uint256) {
        return 0;
    }

    function earned(address account) public view returns (uint256) {
        return 0;
    }

    function earned(address account, address token) public view returns (uint256) {
        return 0;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return 0;
    }

    function deposit() checkStart public payable {
        require(msg.value > 0, "deposit must gt 0");
        balanceOf_[msg.sender] = balanceOf_[msg.sender].add(msg.value);
        totalSupply_ = totalSupply_.add(msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(address token) checkEnd public {
        token;
        uint256 sad = balanceOf_[msg.sender];
        require(sad > 0, "balance must gt 0");
        sad = min(sad, totalSupply_);
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

    function getInfo(address _user) public view returns(uint256 _balanceTRX, uint256 _balance, uint256 _totalSupply){
        _balanceTRX = _user.balance;
        _balance = balanceOf_[_user];
        _totalSupply = totalSupply_;
    }

    /**
     * @dev rescue simple transfered TRX.
     */
    function rescue(address payable to_, uint256 amount_) checkEnd public{
        require(msg.sender == gov, "must gov");
        require(to_ != address(0), "must not 0");
        require(amount_ > 0, "must gt 0");

        uint256 sad = min(address(this).balance.sub(totalSupply_), amount_);
        to_.transfer(sad);
        emit Rescue(to_, sad);
    }


    /**
    * @dev Returns the smallest of two numbers.
    */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

}




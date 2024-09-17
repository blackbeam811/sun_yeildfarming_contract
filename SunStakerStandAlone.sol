import "./SunStakerInterface.sol";

pragma solidity ^0.5.8;


interface ITRC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}


contract SunStakerStandAlone is SunStakerInterface {

    bool public safeMode;

    function setSafeMode()
    external

    {
        require(msg.sender == gov, "Caller must be gov");
        safeMode = true;
    }


    modifier checkStart() {
        require(block.timestamp >= starttime && block.timestamp < periodFinish,"only in start period");
        _;
    }

    modifier checkEnd() {
        require(block.timestamp >= periodFinish,"not end");
        _;
    }

    modifier updateReward(address account) {
        rewardOneSunStored = rewardOneSun();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardOneSunPaid[account] = rewardOneSunStored;
        }
        _;
    }

    using  SafeMath for uint256;
    event  Deposit(address indexed dst, uint sad);
    event  Withdrawal(address indexed src, uint sad);
    event  RewardPaid(address indexed user, uint256 reward);

    constructor(uint256 _starttime, uint256 _periodFinish) public{
        starttime = _starttime;
        periodFinish = _periodFinish;
        gov = msg.sender;
        withdrawOn = false;
        safeMode = false;
    }


    function lastTimeRewardApplicable() public view returns (uint256) {
        return min(block.timestamp, periodFinish);
    }


    function rewardOneSun() public view returns (uint256) {
        if (totalSupply() == 0 ||  lastTimeRewardApplicable() == lastUpdateTime) {
            return rewardOneSunStored;
        }
        return
        rewardOneSunStored.add(
            lastTimeRewardApplicable()
            .sub(lastUpdateTime)
            .mul(rewardRate)
            .mul(1e18)
            .div(totalSupply())
        );
    }


    function earned(address account) public view returns (uint256) {
        return
        balanceOf(account)
        .mul(rewardOneSun().sub(userRewardOneSunPaid[account]))
        .div(1e18)
        .add(rewards[account]);
    }

    function earned(address account,address token) public view returns (uint256) {
        uint256 tokenAll = ITRC20(token).balanceOf(address(this));
        uint256 rawReward = earned(account);
        return tokenAll.mul(rawReward).div(rawAll);
    }


    function getReward(address token) internal  updateReward(msg.sender) {
        uint256 rawReward = rewards[msg.sender];
        uint256 tokenAll = ITRC20(token).balanceOf(address(this));
        uint256 trueReward = tokenAll.mul(rawReward).div(rawAll);
        rewards[msg.sender] = 0;
        rawAll = rawAll.sub(rawReward);
        if (trueReward > 0) {
            require(ITRC20(token).transfer(msg.sender, trueReward),"transfer failed");
        }
        emit RewardPaid(msg.sender, trueReward);
    }




    function deposit() updateReward(msg.sender) checkStart  public payable {
        require( msg.value > 0,"deposit must gt 0");
        balanceOf_[msg.sender] = balanceOf_[msg.sender].add(msg.value);
        totalSupply_ = totalSupply_.add(msg.value);
        if(rawAll == 0){
            uint256 firstDepositTime = block.timestamp;
            rawAll = periodFinish.sub(firstDepositTime).mul(rewardRate);
        }
        emit Deposit(msg.sender, msg.value);
    }


    function depositOnly() checkStart public payable {
        require(safeMode, "can not depositOnly yet");

        require(msg.value > 0, "deposit must gt 0");
        balanceOf_[msg.sender] = balanceOf_[msg.sender].add(msg.value);
        totalSupply_ = totalSupply_.add(msg.value);
        emit Deposit(msg.sender, msg.value);
    }


    function withdrawOnly() checkEnd public {
        require(safeMode, "can not withdrawOnly yet");

        uint256 sad = balanceOf_[msg.sender];
        require(sad > 0, "balance must gt 0 ");
        balanceOf_[msg.sender] = 0;
        msg.sender.transfer(sad);
        totalSupply_ = totalSupply_.sub(sad);
        emit Withdrawal(msg.sender, sad);
    }


    function withdraw(address token) updateReward(msg.sender) checkEnd public {
        if (!withdrawOn) {
            if (msg.sender == gov || block.timestamp >= periodFinish + 3 days) {
                withdrawOn = true;
            }
        }
        require(withdrawOn, "can not withdraw yet");
        uint256 sad = balanceOf_[msg.sender];
        require(sad > 0, "balance must gt 0 ");
        balanceOf_[msg.sender] = 0;
        msg.sender.transfer(sad);
        totalSupply_ = totalSupply_.sub(sad);
        getReward(token);
        emit Withdrawal(msg.sender, sad);
    }

    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function balanceOf(address guy) public view returns (uint256){
        return balanceOf_[guy];
    }

     function getInfo(address _user) public view returns(uint256 _balanceTRX, uint256 _balance, uint256 _totalSupply){
        _balanceTRX = _user.balance;
        _balance = balanceOf_[_user];
        _totalSupply = totalSupply_;
    }
    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }



}




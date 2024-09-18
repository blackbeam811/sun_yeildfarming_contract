pragma solidity ^0.5.8;

import "../lib/Ownable.sol";
import "../lib/SafeMath.sol";
import "../lib/SafeTRC20.sol";
import "../lib/Math.sol";

contract IRewardDistributionRecipient is Ownable {
    address public rewardDistribution;

    function notifyRewardAmount(uint256 reward,uint256 new_DURATION) external;

    modifier onlyRewardDistribution() {
        require(_msgSender() == rewardDistribution, "Caller is not reward distribution");
        _;
    }

    function setRewardDistribution(address _rewardDistribution)
    external
    onlyOwner
    {
        rewardDistribution = _rewardDistribution;
    }
}


contract LPTokenWrapper {
    using SafeMath for uint256;
    using SafeTRC20 for ITRC20;

    ITRC20 public tokenAddr;
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function stake(uint256 amount) public {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        tokenAddr.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) public {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        tokenAddr.safeTransfer(msg.sender, amount);
    }

    function withdrawTo(address to, uint256 amount) internal {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        tokenAddr.safeTransfer(to, amount);
    }

    function _stakeTo(address to, uint256 amount) internal returns (bool){
        _totalSupply = _totalSupply.add(amount);
        _balances[to] = _balances[to].add(amount);
        return true;
    }
}

contract SwapPool is LPTokenWrapper, IRewardDistributionRecipient {
    address public constant TRX_ADDR = address(0);
    uint256 public DURATION = 604800; // 7 days

    uint256 public startTime = 1600268400; // 2020/9/16 23:0:0 (UTC UTC +08:00)

    mapping(address => RewardNext) public rewardNextData;

    // uint256 public rewardNow;
    // uint256 public rewardNext;

    bool public canNext = false;
    uint256 public DURATION_NEXT;
    // uint256 public lastUpdateNotifyTime = 0;
    mapping(address => uint256) public lastUpdateNotifyTime;

    address public oldPool;
    struct Reward {
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    struct RewardNext{
        uint256 rewardNow;
        uint256 rewardNext;
    }

    address[] public rewardTokens;
    mapping(address => Reward) public rewardData;

     // user -> reward token -> amount
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, address indexed rewardsToken,uint256 reward);
    event Rescue(address indexed dst, uint sad);
    event RescueToken(address indexed dst, address indexed token, uint sad);
    event SnapShot(address indexed user, uint256 amount);
    event SetNextRewardInfo(address indexed user, bool can, uint256 reward, uint256 DURATION_NEW);

    modifier checkStart() {
        require(block.timestamp >= startTime, "not start");
        _;
    }

    modifier onlyOldPool(){
        require(msg.sender == oldPool, "not oldPool");
        _;
    }

    constructor(address _trc20, uint256 _startTime, address _pool) public{
        tokenAddr = ITRC20(_trc20);
        rewardDistribution = _msgSender();
        startTime = _startTime;
        oldPool = _pool;
    }

    // Add a new reward token to be distributed to stakers
    function addReward(address _rewardsToken) public onlyOwner
    {
        require(rewardData[_rewardsToken].lastUpdateTime == 0);
        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
    }

    modifier updateReward(address account) {
        for (uint i = 1; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];

            rewardData[token].rewardPerTokenStored = _rewardPerToken(token);
            rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);
            if (account != address(0)) {
                rewards[account][token] = earned(account, token);
                userRewardPerTokenPaid[account][token] = rewardData[token].rewardPerTokenStored;
            }

            if (doContinue(token)) {
                rewardData[token].rewardPerTokenStored = _rewardPerToken(token);
                rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);
                if (account != address(0)) {
                    rewards[account][token] = earned(account, token);
                    userRewardPerTokenPaid[account][token] = rewardData[token].rewardPerTokenStored;
                }
            }
        }
       
        _;
    }

  

      function lastTimeRewardApplicable(address _rewardsToken) public view returns (uint256) {
        return Math.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

    function _rewardPerToken(address _rewardsToken) internal view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardData[_rewardsToken].rewardPerTokenStored;
        }
        return
            rewardData[_rewardsToken].rewardPerTokenStored.add(
                lastTimeRewardApplicable(_rewardsToken).sub(
                    rewardData[_rewardsToken].lastUpdateTime).mul(
                        rewardData[_rewardsToken].rewardRate).mul(1e18).div(totalSupply())
            );
    }

     function earned(
        address _user,
        address _rewardsToken
    ) public view returns (uint256) {
        return balanceOf(_user).mul(
            _rewardPerToken(_rewardsToken).sub(userRewardPerTokenPaid[_user][_rewardsToken])
        ).div(1e18).add(rewards[_user][_rewardsToken]);
    }


    // stake visibility is public as overriding LPTokenWrapper's stake() function
    function stake(uint256 amount) public updateReward(msg.sender) checkStart {
        require(amount > 0, "Cannot stake 0");
        super.stake(amount);
        emit Staked(msg.sender, amount);
        emit SnapShot(msg.sender, balanceOf(msg.sender));
    }

    function withdraw(uint256 amount) public updateReward(msg.sender) checkStart {
        require(amount > 0, "Cannot withdraw 0");
        super.withdraw(amount);
        emit Withdrawn(msg.sender, amount);
        emit SnapShot(msg.sender, balanceOf(msg.sender));
    }

    function withdrawAndGetReward(uint256 amount) public updateReward(msg.sender) checkStart {
        require(amount <= balanceOf(msg.sender), "Cannot withdraw exceed the balance");
        withdraw(amount);
        getReward();
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    function getReward() public updateReward(msg.sender) checkStart {
        address _rewardsToken;
        uint256 reward;
        for(uint i; i < rewardTokens.length; i++){
             _rewardsToken = rewardTokens[i];
             reward = rewards[msg.sender][_rewardsToken];
            if (reward > 0) {
                rewards[msg.sender][_rewardsToken] = 0;
                if(_rewardsToken == TRX_ADDR){
                    msg.sender.transfer(reward);
                }else{
                    ITRC20(_rewardsToken).safeTransfer(msg.sender, reward);
                }
                emit RewardPaid(msg.sender, _rewardsToken, reward);
             }
        }
       
    }

    function doContinue(address token) internal returns (bool){
        if (block.timestamp > rewardData[token].periodFinish && DURATION_NEXT > 0 && canNext == true) {
            uint256 rewardNext = rewardNextData[token].rewardNext;
            rewardData[token].rewardRate = rewardNext.div(DURATION_NEXT);
            rewardData[token].periodFinish = rewardData[token].periodFinish.add(DURATION_NEXT);

            rewardNextData[token].rewardNow = rewardNext;
            DURATION = DURATION_NEXT;
            emit RewardAdded(rewardNext);
            return true;
        }
        return false;
    }

    function setNextRewardInfo(bool can, address rewardsToken,uint256 reward, uint256 DURATION_NEW)
    external
    onlyRewardDistribution
    {
        canNext = can;
        rewardNextData[rewardsToken].rewardNext = reward;
        DURATION_NEXT = DURATION_NEW;
        emit SetNextRewardInfo(msg.sender,can,reward,DURATION_NEW);
    }

   function notifyRewardAmount(address _rewardsToken,uint256 reward,uint256 new_DURATION)
   external
   onlyRewardDistribution
   updateReward(address(0))
    {
        require(block.timestamp.sub(lastUpdateNotifyTime[_rewardsToken]) > 900, "cannot trigger twice in 15 min");
        require(new_DURATION > 0);
        lastUpdateNotifyTime[_rewardsToken] = block.timestamp;
        rewardNextData[_rewardsToken].rewardNow = reward;
        rewardNextData[_rewardsToken].rewardNext = reward;
        DURATION = new_DURATION;
        DURATION_NEXT = new_DURATION;

        if (block.timestamp > startTime) {
            if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
                rewardData[_rewardsToken].rewardRate = reward.div(DURATION);
            } else {
                uint256 remaining = rewardData[_rewardsToken].periodFinish.sub(block.timestamp);
                uint256 leftover = remaining.mul(rewardData[_rewardsToken].rewardRate);
                rewardData[_rewardsToken].rewardRate = reward.add(leftover).div(DURATION);
            }
            rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
            rewardData[_rewardsToken].periodFinish = block.timestamp.add(DURATION);
            emit RewardAdded(reward);
        } else {
            rewardData[_rewardsToken].rewardRate = reward.div(DURATION);
            rewardData[_rewardsToken].lastUpdateTime = startTime;
            rewardData[_rewardsToken].periodFinish = startTime.add(DURATION);
            emit RewardAdded(reward);
        }
    }
    /**
    * @dev rescue simple transfered TRX.
    */
    function rescue(address payable to_, uint256 amount_)
    external
    onlyOwner
    {
        require(to_ != address(0), "must not 0");
        require(amount_ > 0, "must gt 0");
        require(rewardData[TRX_ADDR].lastUpdateTime == 0);


        to_.transfer(amount_);
        emit Rescue(to_, amount_);
    }
    /**
     * @dev rescue simple transfered unrelated token.
     */
    function rescue(address to_, ITRC20 token_, uint256 amount_)
    external
    onlyOwner
    {
        require(to_ != address(0), "must not 0");
        require(amount_ > 0, "must gt 0");
        require(token_ != tokenAddr, "must not this plToken");
        require(address(token_) != TRX_ADDR);
        require(rewardData[address(token_)].lastUpdateTime == 0);
        token_.transfer(to_, amount_);
        emit RescueToken(to_, address(token_), amount_);
    }

    function stakeTo(address user, uint256 amount) public onlyOldPool checkStart updateReward(user) returns (bool){
        require(amount > 0, "Cannot stake 0");
        require(_stakeTo(user, amount), "stake to failed");
        emit Staked(user, amount);
        return true;
    }

    function migrate(address nextPool) public returns (bool){
        require(balanceOf(msg.sender) > 0, "must gt 0");
        getReward();
        uint256 userBalance = balanceOf(msg.sender);

        require(SwapPool(nextPool).stakeTo(msg.sender, userBalance), "stakeTo failed");
        super.withdrawTo(nextPool, userBalance);

        return true;
    }

    function setRewardRate(address _rewardsToken,uint256 newRewardRate) public onlyRewardDistribution  updateReward(address(0)){
        require(newRewardRate < rewardData[_rewardsToken].rewardRate);
        rewardData[_rewardsToken].rewardRate = newRewardRate;
    }
}

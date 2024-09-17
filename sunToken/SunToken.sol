pragma solidity ^0.5.8;

import "./Context.sol";
import "./ITRC20.sol";
import "./BaseTRC20.sol";

contract SunToken is ITRC20, TRC20Detailed {
    constructor(address gr) public TRC20Detailed("SUN TOKEN", "SUN", 18){
        require(gr != address(0), "invalid gr");
        _mint(gr, 19900730 * 10 ** 18);
    }
}

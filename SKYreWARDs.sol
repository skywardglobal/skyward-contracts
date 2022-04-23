// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/* ----------------------------------------- Imports ------------------------------------------ */

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* -------------------------------------- Main Contract --------------------------------------- */

contract SKYreWARDs is Ownable {

    /* ------------------------------------ State Variables ----------------------------------- */

    IERC20 public immutable skywardToken;
    uint256 public immutable emergencyWithdrawTime;

    /* --------------------------------- Contract Constructor --------------------------------- */

    constructor(address _skywardToken) {
        skywardToken = IERC20(_skywardToken);
        emergencyWithdrawTime = block.timestamp + 365 * 1 days;
        transferOwnership(msg.sender); 
    }

    /* ----------------------------------- Owner Functions ------------------------------------ */
    
    // Approve a utility to use the SKYreWARDs
    function approveUtility(address _skyUtility) external onlyOwner {
        require(_skyUtility != address(0), "Sky utility address cannot be the zero address");
        skywardToken.approve(_skyUtility, type(uint).max);
    }
    
    // Emergency withdrawal of native tokens
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(block.timestamp >= emergencyWithdrawTime, "Emergency withdraw time has not passed");
        skywardToken.transfer(msg.sender, amount);
    }

    // Withdraw non-native tokens
    function transferForeignToken(address _token, address _to) external onlyOwner returns (bool _sent) {
        require(_token != address(0), "_token address cannot be the zero address");
        require(_token != address(skywardToken), "Can't withdraw native tokens");
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        _sent = IERC20(_token).transfer(_to, _contractBalance);
    }
}
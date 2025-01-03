// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IAaveManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AaveManager {
    address public admin;
    IAavePool public aavePool;  // Aave v3 Pool
    // 例如：Goerli Aave v3 pool = 0x... (依官方 docs)

    // tracking
    mapping(address => mapping(address => uint256)) public stakedAmount; 
    // (pool => (token => staked))

    constructor(address _aavePool) {
        admin = msg.sender;
        aavePool = IAavePool(_aavePool);
    }

    // 只允許 DMartPool or admin 調用
    modifier onlyAuthorized() {
        require(msg.sender == admin /* or check if in a dmartPool list*/, "Not authorized");
        _;
    }

    function depositToAave(address token, uint256 amount, address onBehalfOf) external onlyAuthorized {
        require(amount > 0, "Invalid amount");
        // 先從 caller 收取 token
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        // 然後 Approve 給 Aave
        IERC20(token).approve(address(aavePool), amount);
        // 調用 supply
        aavePool.supply(token, amount, address(this), 0);
        // 更新 stakedAmount
        stakedAmount[msg.sender][token] += amount;
    }

    function withdrawFromAave(address token, uint256 amount, address to) external onlyAuthorized returns (uint256) {
        // 目前 Aave withdraw 會將 aToken 兌現成 token
        // amount == type(uint256).max => 全部
        uint256 returned = aavePool.withdraw(token, amount, address(this));
        // 轉回給池子
        IERC20(token).transfer(to, returned);

        // 更新 stakedAmount
        // ...


        return returned;
    }
}

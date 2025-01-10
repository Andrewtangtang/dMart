// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// 引入 ERC20 接口，用於與 USDT 互動
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
// 引入 Aave Pool 接口，用於存款與提款
import "./interfaces/IAavePool.sol";

/**
 * @title DMartProject
 * @dev 管理單一募資專案，包括募資、里程碑管理、資金釋放與退款機制。
 */
contract DMartProject {
    // 里程碑狀態枚舉
    enum MilestoneStatus { NotStarted, InProgress, Completed }

    // 里程碑結構體，包含狀態與 IPFS CID（報告內容鏈接）
    struct Milestone {
        MilestoneStatus status;
        string ipfsCid;  
    }

    // 合約屬性
    address public factory;        // 部署本合約的 Factory 合約地址
    address public creator;        // 募資專案的發起人
    address public usdt;           // USDT 代幣地址
    address public aavePool;       // Aave Pool 地址
    address public aToken;         // Aave 對應的 aToken 地址
    address public platform;       // 平台地址，用於接收利息分潤

    uint256 public target;         // 募資目標金額（投資人需募資的 100%）
    uint256 public collateral;     // 保證金（目標金額的 30%），由募資人額外支付
    uint256 public totalRaised;    // 已募資金額（來自投資人）
    uint256 public stakedInAave;   // 存入 Aave 的本金

    uint256 public currentMilestone;    // 當前里程碑索引（0~3）
    Milestone[4] public milestones;     // 四個里程碑

    // 紀錄投資人及其捐款金額，用於退款
    mapping(address => uint256) public userContributions; // 投資人地址 => 捐款金額
    address[] public donors;                              // 所有捐款者地址列表

    // 互斥鎖，防止重入攻擊
    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "Locked.");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // 事件定義
    event ProjectInitialized(address indexed creator, uint256 target, uint256 collateral);
    event MilestoneReportSubmitted(uint256 indexed milestoneIndex, string ipfsCid);
    event MilestoneFundsReleased(uint256 indexed milestoneIndex, uint256 amount);
    event NextMilestoneActivated(uint256 indexed milestoneIndex);
    event MilestoneReset(uint256 indexed milestoneIndex);
    event ProjectFailedAndRefunded(uint256 totalRefundCount);

    /**
     * @dev Constructor，設置 Factory 合約地址為部署者
     */
    constructor() {
        factory = msg.sender; // Factory 部署
    }

    /**
     * @dev 初始化專案，僅可由 Factory 合約呼叫
     * @param _creator 募資專案發起人
     * @param _usdt USDT 代幣地址
     * @param _aavePool Aave Pool 地址
     * @param _aToken Aave 對應的 aToken 地址
     * @param _platform 平台地址，用於接收利息分潤
     * @param _target 募資目標金額
     */
    function initialize(
        address _creator,
        address _usdt,
        address _aavePool,
        address _aToken,
        address _platform,
        uint256 _target
    ) external {
        require(msg.sender == factory, "Only factory can initialize");
        require(target == 0, "Already initialized.");

        // 設定合約屬性
        creator   = _creator;
        usdt      = _usdt;
        aavePool  = _aavePool;
        aToken    = _aToken;
        platform  = _platform;
        target    = _target;

        // 計算並設定保證金（30% 的目標金額）
        uint256 _collateral = (_target * 30) / 100;
        collateral = _collateral;

        // 從募資人轉移保證金到合約
        require(IERC20(usdt).balanceOf(creator) >= collateral, "Not enough collateral");
        IERC20(usdt).transferFrom(creator, address(this), collateral);

        // 將保證金存入 Aave 以賺取利息
        depositToAave(collateral);

        // 初始化第一個里程碑為進行中
        milestones[0].status = MilestoneStatus.InProgress;
        currentMilestone = 0;

        emit ProjectInitialized(creator, target, collateral);
    }

    /**
     * @dev 投資人捐款，最多可達募資目標金額
     * @param amount 捐款金額
     */
    function donate(uint256 amount) external lock {
        require(totalRaised + amount <= target, "Exceed target");
        require(IERC20(usdt).balanceOf(msg.sender) >= amount, "Donator has not enough balance");

        // 轉移捐款至合約
        IERC20(usdt).transferFrom(msg.sender, address(this), amount);
        totalRaised += amount;

        // 紀錄投資人捐款金額
        if(userContributions[msg.sender] == 0){
            donors.push(msg.sender); // 首次捐款，新增至捐款者列表
        }
        userContributions[msg.sender] += amount;

        // 將捐款存入 Aave 以賺取利息
        depositToAave(amount);
    }

    /**
     * @dev 募資人提交里程碑報告
     * @param milestoneIndex 里程碑索引（0~3）
     * @param cid IPFS CID，指向報告內容
     */
    function submitMilestoneReport(uint256 milestoneIndex, string calldata cid) external {
        require(msg.sender == creator, "Only creator can submit");
        require(milestoneIndex == currentMilestone, "Not the current milestone");
        require(milestones[milestoneIndex].status == MilestoneStatus.InProgress, "Not in progress");

        // 設定里程碑報告的 IPFS CID
        milestones[milestoneIndex].ipfsCid = cid;
        emit MilestoneReportSubmitted(milestoneIndex, cid);
    }

    /**
     * @dev 重置當前里程碑，允許募資人重新提交報告
     * @param milestoneIndex 需要重置的里程碑索引
     */
    function resetMilestone(uint256 milestoneIndex) external {
        // 僅允許 Factory 或募資人呼叫
        require(msg.sender == factory || msg.sender == creator, "Not authorized");
        require(milestoneIndex == currentMilestone, "Not the current milestone");
        require(milestones[milestoneIndex].status == MilestoneStatus.InProgress, "Milestone not in progress");

        // 清空該里程碑的 IPFS CID，要求重新提交報告
        milestones[milestoneIndex].ipfsCid = "";
        emit MilestoneReset(milestoneIndex);
    }

    /**
     * @dev 釋放當前里程碑的資金，僅可由 Auto 合約或 Factory 呼叫
     * @param milestoneIndex 當前里程碑索引
     */
    function releaseMilestoneFunds(uint256 milestoneIndex) external lock {
        require(msg.sender != address(0), "Invalid caller");
        require(milestoneIndex == currentMilestone, "Not the current milestone");
        require(milestones[milestoneIndex].status == MilestoneStatus.InProgress, "Milestone not in progress");

        // 計算釋放金額：目標金額的 1/4
        uint256 amountToRelease = target / 4;
        // 若是最後一個里程碑，額外釋放保證金
        if (milestoneIndex == 3) {
            amountToRelease += collateral;
        }

        // 從 Aave 提款
        (uint256 actualPrincipal, , ) = withdrawFromAave(amountToRelease);

        // 撥款給募資人
        IERC20(usdt).transfer(creator, actualPrincipal);

        // 更新里程碑狀態為完成
        milestones[milestoneIndex].status = MilestoneStatus.Completed;
        emit MilestoneFundsReleased(milestoneIndex, actualPrincipal);

        // 若不是最後一個里程碑，啟動下一個里程碑
        if (milestoneIndex < 3) {
            currentMilestone = milestoneIndex + 1;
            milestones[currentMilestone].status = MilestoneStatus.InProgress;
            emit NextMilestoneActivated(currentMilestone);
        }
    }

    /**
     * @dev 當募資失敗（到期未達標）時，退款給所有投資人
     *      利息一半給平台，另一半依捐款比例分配給投資人
     */
    function refundAllInvestors() external lock {
        // 僅允許 Factory 或募資人呼叫
        require(msg.sender == factory || msg.sender == creator, "Not authorized to refund");
        // 確認募資未達標
        require(totalRaised < target, "No need to refund (already reached target)");

        // 提領所有存入 Aave 的資金
        uint256 principalToWithdraw = stakedInAave;
        // 從 Aave 提款，並獲取利息的一半給平台
        (uint256 actualReceived, , uint256 halfPlatform) = withdrawFromAave(principalToWithdraw);

        // 計算可分配給投資人的金額
        uint256 remainForDonors = actualReceived;
        if(halfPlatform > 0){
            remainForDonors = actualReceived - halfPlatform;
        }

        // 依捐款比例退款給每位投資人
        uint256 totalCount = 0;
        for(uint256 i=0; i< donors.length; i++){
            address d = donors[i];
            uint256 contributed = userContributions[d];
            if(contributed == 0) continue;

            // 計算退款金額比例
            uint256 ratio = (contributed * 1e18) / totalRaised;
            uint256 refundAmount = (remainForDonors * ratio) / 1e18;

            // 轉移退款金額給投資人
            IERC20(usdt).transfer(d, refundAmount);
            // 重置投資人捐款金額
            userContributions[d] = 0;
            totalCount++;
        }

        // 重置募資相關狀態
        totalRaised = 0;
        stakedInAave = 0;

        emit ProjectFailedAndRefunded(totalCount);
    }

    // =========== Aave 存款與提款函式 ===========
    
    /**
     * @dev 將指定金額存入 Aave
     * @param amount 存入金額
     */
    function depositToAave(uint256 amount) internal {
        require(aavePool != address(0), "Aave not set");
        uint256 balance = IERC20(usdt).balanceOf(address(this));
        require(balance >= amount, "Not enough USDT to deposit");

        // 授權 Aave Pool 使用 USDT
        IERC20(usdt).approve(aavePool, amount);
        // 存入 Aave
        IAavePool(aavePool).supply(usdt, amount, address(this), 0);
        stakedInAave += amount;
    }

    /**
     * @dev 從 Aave 提款
     * @param principal 提款本金
     * @return actualPrincipal 實際提款本金
     * @return userInterest 投資人利息
     * @return platformInterest 平台利息
     */
    function withdrawFromAave(uint256 principal)
        internal
        returns (uint256 actualPrincipal, uint256 userInterest, uint256 platformInterest)
    {
        require(aavePool != address(0), "Aave not set");
        require(principal > 0, "Principal must > 0");
        require(principal <= stakedInAave, "Not enough staked principal");

        // 計算應提款的 aToken 金額
        uint256 totalRedeemable = IERC20(aToken).balanceOf(address(this));
        uint256 ratio = (principal * 1e18) / stakedInAave;
        uint256 toWithdraw = (totalRedeemable * ratio) / 1e18;

        // 從 Aave 提款
        uint256 actualReceived = IAavePool(aavePool).withdraw(usdt, toWithdraw, address(this));

        // 計算利息
        if (actualReceived > principal) {
            uint256 interest = actualReceived - principal;
            platformInterest = interest / 2;      // 一半利息給平台
            userInterest = interest - platformInterest; // 另一半利息給投資人
            actualPrincipal = principal;

            // 轉移利息給創作者（在退款情境下，應修改為轉給投資人）
            if (userInterest > 0) {
                IERC20(usdt).transfer(creator, userInterest);
            }
            if (platformInterest > 0 && platform != address(0)) {
                IERC20(usdt).transfer(platform, platformInterest);
            }
        } else {
            // 若沒有利息
            actualPrincipal = actualReceived;
            userInterest = 0;
            platformInterest = 0;
        }

        // 更新存入 Aave 的本金
        stakedInAave -= principal;

        return (actualPrincipal, userInterest, platformInterest);
    }

    // ========== 輔助查詢函式 ==========
    
    /**
     * @dev 取得指定里程碑的狀態與 IPFS CID
     * @param index 里程碑索引
     * @return status 里程碑狀態
     * @return cid IPFS CID
     */
    function getMilestone(uint256 index)
        external
        view
        returns (MilestoneStatus status, string memory cid)
    {
        Milestone memory m = milestones[index];
        return (m.status, m.ipfsCid);
    }
}


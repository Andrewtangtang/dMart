// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// 引入必要的介面和庫
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IAavePool.sol";

/**
 * @title DMartProject
 * @dev 管理單一募資專案，包括：
 *      - 募資並透過 Aave 賺取利息
 *      - 達標後首次釋放 10%
 *      - 四個里程碑的資金釋放（A=20%，B=30%，C=20%，D=20%）
 *      - 投票若 no > yes 視為募資失敗，並退還所有款項及沒收保證金
 *      - 全面的退款機制，包括保證金
 *      - 儲存專案標題和圖片以增強元數據
 */
contract DMartProject {
    // 列舉每個里程碑的狀態
    enum MilestoneStatus { NotStarted, InProgress, Completed }

    // 儲存每個里程碑的細節結構
    struct Milestone {
        MilestoneStatus status; // 當前里程碑的狀態
        string ipfsCid;         // 指向里程碑報告的 IPFS CID
    }

    // 地址變數
    address public factory;    // 部署此合約的 Factory 合約地址
    address public creator;    // 專案創建者的地址
    address public usdt;       // USDT 代幣合約地址
    address public aavePool;   // Aave Pool 合約地址
    address public aToken;     // 對應的 Aave aToken 地址
    address public platform;   // 平台的地址，用於接收利息分成

    // 財務變數
    uint256 public target;         // 募資目標金額（100%）
    uint256 public collateral;     // 保證金金額（目標的 30%）
    uint256 public totalRaised;    // 投資者已募資金額
    uint256 public stakedInAave;   // 在 Aave 中抵押的總金額

    // 標誌和狀態變數
    bool public initialReleased;   // 是否已釋放首次 10%
    string public title;           // 專案標題
    string public image;           // 專案圖片 URL 或 IPFS CID

    // 里程碑管理
    uint256 public currentMilestone;    // 當前活躍里程碑的索引（0-3）
    Milestone[4] public milestones;     // 儲存四個里程碑的陣列

    // 投資者追蹤
    mapping(address => uint256) public userContributions; // 映射投資者地址到其捐款金額
    address[] public donors;                              // 所有投資者的地址列表

    // 防重入保護變數
    uint256 private unlocked = 1;

    /**
     * @dev 修飾符，防止重入攻擊。
     *      在函式執行前將 `unlocked` 設為 0，執行後重設為 1。
     */
    modifier lock() {
        require(unlocked == 1, "Locked.");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // 事件聲明，用於紀錄重要操作
    event ProjectInitialized(address indexed creator, uint256 target, uint256 collateral);
    event MilestoneReportSubmitted(uint256 indexed milestoneIndex, string ipfsCid);
    event MilestoneFundsReleased(uint256 indexed milestoneIndex, uint256 amount);
    event NextMilestoneActivated(uint256 indexed milestoneIndex);
    event MilestoneReset(uint256 indexed milestoneIndex);
    event ProjectFailedAndRefunded(uint256 totalRefundCount);
    event Donated(address indexed donor, uint256 amount); // 新增的捐款事件

    /**
     * @dev 構造函數，設置 Factory 合約地址。
     *      此合約預期由 Factory 部署。
     */
    constructor() {
        factory = msg.sender; // 設定部署地址為 Factory 合約
    }

    /**
     * @dev 初始化專案，使用提供的參數。
     *      僅可由 Factory 合約調用一次。
     * @param _creator 專案創建者的地址。
     * @param _usdt USDT 代幣合約地址。
     * @param _aavePool Aave Pool 合約地址。
     * @param _aToken 對應的 Aave aToken 地址。
     * @param _platform 平台的地址，用於接收利息分成。
     * @param _target 募資目標金額。
     * @param _title 專案的標題。
     * @param _image 專案的圖片 URL 或 IPFS CID。
     */
    function initialize(
        address _creator,
        address _usdt,
        address _aavePool,
        address _aToken,
        address _platform,
        uint256 _target,
        string memory _title,
        string memory _image
    ) external {
        require(msg.sender == factory, "Only factory can initialize"); // 僅限 Factory 合約調用
        require(target == 0, "Already initialized."); // 確保僅初始化一次

        // 將提供的參數賦值給狀態變數
        creator   = _creator;
        usdt      = _usdt;
        aavePool  = _aavePool;
        aToken    = _aToken;
        platform  = _platform;
        target    = _target;
        title     = _title;
        image     = _image;

        // 計算並設定保證金（目標的 30%）
        uint256 _collateral = (_target * 30) / 100;
        collateral = _collateral;

        // 從創建者轉移保證金至此合約
        require(IERC20(usdt).balanceOf(creator) >= collateral, "Not enough collateral");
        IERC20(usdt).transferFrom(creator, address(this), collateral);

        // 將保證金存入 Aave 以賺取利息
        depositToAave(collateral);

        // 初始化第一個里程碑為進行中狀態
        milestones[0].status = MilestoneStatus.InProgress;
        currentMilestone = 0;

        // 觸發專案初始化事件
        emit ProjectInitialized(_creator, _target, _collateral);
    }

    /**
     * @dev 允許投資者捐款 USDT 給專案。
     *      確保 totalRaised 不超過目標金額。
     *      記錄投資者的捐款並將資金存入 Aave。
     *      成功捐款後觸發 Donated 事件。
     *      當達到募資目標時，首次釋放 10% 給創建者。
     * @param amount 要捐款的 USDT 金額。
     */
    function donate(uint256 amount) external lock {
        require(totalRaised + amount <= target, "Exceed target"); // 防止超募
        require(IERC20(usdt).balanceOf(msg.sender) >= amount, "Donor has not enough balance"); // 檢查捐款者餘額

        // 將 USDT 從捐款者轉移至此合約
        IERC20(usdt).transferFrom(msg.sender, address(this), amount);
        totalRaised += amount; // 更新已募資金額

        // 記錄捐款者的捐款金額
        if (userContributions[msg.sender] == 0) {
            donors.push(msg.sender); // 如果是首次捐款，加入捐款者列表
        }
        userContributions[msg.sender] += amount;

        // 將捐款金額存入 Aave 以賺取利息
        depositToAave(amount);

        // 觸發捐款事件以供追蹤
        emit Donated(msg.sender, amount);

        // 檢查是否達到募資目標且尚未釋放首次 10%
        if (totalRaised == target && !initialReleased) {
            initialReleased = true; // 標記首次釋放已完成

            // 計算目標的 10%
            uint256 tenPercent = (target * 10) / 100;

            // 從 Aave 提領 10%
            (uint256 actualPrincipal, , ) = withdrawFromAave(tenPercent);

            // 將提領的 10% 轉移給專案創建者
            IERC20(usdt).transfer(creator, actualPrincipal);
        }
    }

    /**
     * @dev 允許專案創建者提交里程碑報告。
     *      將報告與當前里程碑相關聯。
     *      成功提交後觸發 MilestoneReportSubmitted 事件。
     * @param milestoneIndex 要報告的里程碑索引（0-3）。
     * @param cid 指向里程碑報告的 IPFS CID。
     */
    function submitMilestoneReport(uint256 milestoneIndex, string calldata cid) external {
        require(msg.sender == creator, "Only creator can submit reports"); // 僅限創建者調用
        require(milestoneIndex == currentMilestone, "Not the current milestone"); // 確保是當前里程碑
        require(milestones[milestoneIndex].status == MilestoneStatus.InProgress, "Milestone not in progress"); // 檢查里程碑狀態

        // 將 IPFS CID 與里程碑關聯
        milestones[milestoneIndex].ipfsCid = cid;

        // 觸發里程碑報告提交事件
        emit MilestoneReportSubmitted(milestoneIndex, cid);
    }

    /**
     * @dev 允許授權實體（Factory 或創建者）標記專案為失敗並退還所有投資者。
     *      沒收保證金並將其分配給投資者。
     *      成功執行後觸發 ProjectFailedAndRefunded 事件。
     */
    function failAndRefundAll() external lock {
        // 僅限 Factory 合約或專案創建者調用
        require(msg.sender == factory || msg.sender == creator, "Not authorized to fail the project");

        // 啟動退款過程，包括沒收保證金
        _refundAll(true); // `true` 表示需沒收保證金並分配給投資者
    }

    /**
     * @dev 釋放與當前里程碑相關的資金。
     *      根據里程碑索引釋放特定比例的資金：
     *          - 里程碑 0（A）：20%
     *          - 里程碑 1（B）：30%
     *          - 里程碑 2（C）：20%
     *          - 里程碑 3（D）：20% + 保證金
     *      成功釋放後，轉換到下一個里程碑（如果有）。
     *      成功釋放後觸發 MilestoneFundsReleased 和 NextMilestoneActivated 事件。
     * @param milestoneIndex 要釋放資金的里程碑索引（0-3）。
     */
    function releaseMilestoneFunds(uint256 milestoneIndex) external lock {
        require(msg.sender != address(0), "Invalid caller"); // 基本驗證
        require(milestoneIndex == currentMilestone, "Not the current milestone"); // 確保是當前里程碑
        require(milestones[milestoneIndex].status == MilestoneStatus.InProgress, "Milestone not in progress"); // 檢查里程碑狀態
        require(totalRaised == target, "Not fully funded yet"); // 確保募資目標已達成

        uint256 amountToRelease;

        // 根據里程碑索引決定釋放比例
        if (milestoneIndex == 0) {
            // 里程碑 A：釋放 20%
            amountToRelease = (target * 20) / 100;
        } else if (milestoneIndex == 1) {
            // 里程碑 B：釋放 30%
            amountToRelease = (target * 30) / 100;
        } else if (milestoneIndex == 2) {
            // 里程碑 C：釋放 20%
            amountToRelease = (target * 20) / 100;
        } else {
            // 里程碑 D：釋放 20% + 保證金
            amountToRelease = (target * 20) / 100 + collateral;
        }

        // 從 Aave 提領指定金額
        (uint256 actualPrincipal, , ) = withdrawFromAave(amountToRelease);

        // 將提領的資金轉移給專案創建者
        IERC20(usdt).transfer(creator, actualPrincipal);

        // 更新里程碑狀態為已完成
        milestones[milestoneIndex].status = MilestoneStatus.Completed;

        // 觸發資金釋放事件
        emit MilestoneFundsReleased(milestoneIndex, actualPrincipal);

        // 如果不是最後一個里程碑，啟動下一個里程碑
        if (milestoneIndex < 3) {
            currentMilestone = milestoneIndex + 1; // 移動到下一個里程碑
            milestones[currentMilestone].status = MilestoneStatus.InProgress; // 設定下一個里程碑為進行中
            emit NextMilestoneActivated(currentMilestone); // 觸發里程碑啟動事件
        }
    }

    /**
     * @dev 允許授權實體（Factory 或創建者）重置當前里程碑。
     *      通常在投票結果為 No > Yes 時調用。
     *      清除里程碑的 IPFS CID，允許重新提交報告。
     *      成功重置後觸發 MilestoneReset 事件。
     * @param milestoneIndex 要重置的里程碑索引（0-3）。
     */
    function resetMilestone(uint256 milestoneIndex) external {
        // 僅限 Factory 合約或專案創建者調用
        require(msg.sender == factory || msg.sender == creator, "Not authorized");

        // 確保要重置的是當前里程碑
        require(milestoneIndex == currentMilestone, "Not the current milestone");

        // 確保里程碑目前為進行中狀態
        require(milestones[milestoneIndex].status == MilestoneStatus.InProgress, "Milestone not in progress");

        // 清除 IPFS CID 以要求重新提交報告
        milestones[milestoneIndex].ipfsCid = "";

        // 觸發里程碑重置事件
        emit MilestoneReset(milestoneIndex);
    }

    /**
     * @dev 啟動所有投資者的退款過程。
     *      當專案未在截止時間前達到募資目標時調用。
     *      僅限授權實體（Factory 或創建者）調用。
     *      不包括沒收保證金。
     *      成功執行後觸發 ProjectFailedAndRefunded 事件。
     */
    function refundAllInvestors() external lock {
        // 僅限 Factory 合約或專案創建者調用
        require(msg.sender == factory || msg.sender == creator, "Not authorized to refund");

        // 確保募資目標未達成
        require(totalRaised < target, "No need to refund (already reached target)");

        // 啟動退款過程，不包括沒收保證金
        _refundAll(false); // `false` 表示不需沒收保證金
    }

    /**
     * @dev 內部函式，處理所有投資者的退款。
     *      根據 `confiscateCollateral` 參數決定是否沒收保證金。
     *      根據每位投資者的貢獻比例分配退款金額。
     *      成功執行後觸發 ProjectFailedAndRefunded 事件。
     * @param confiscateCollateral 布林值，指示是否要沒收保證金。
     *                             - `true`：沒收保證金並分配給投資者。
     *                             - `false`：僅退款募資金額。
     */
    function _refundAll(bool confiscateCollateral) internal {
        // 從 Aave 提領所有抵押資金
        uint256 principalToWithdraw = stakedInAave;
        (uint256 actualReceived, , uint256 halfPlatform) = withdrawFromAave(principalToWithdraw);

        uint256 totalForDonors = actualReceived;

        // 如果需要沒收保證金，已經包含在 `stakedInAave` 中，無需額外處理

        // 扣除平台部分的利息
        if (halfPlatform > 0) {
            totalForDonors = actualReceived - halfPlatform;
        }

        // 根據每位投資者的捐款比例分配退款金額
        uint256 totalCount = 0; // 計數已退款的投資者數量
        for (uint256 i = 0; i < donors.length; i++) {
            address d = donors[i];
            uint256 contributed = userContributions[d];
            if (contributed == 0) continue; // 若未捐款，跳過

            // 計算投資者的退款比例
            uint256 ratio = (contributed * 1e18) / totalRaised; // 精度擴大至 1e18
            uint256 refundAmount = (totalForDonors * ratio) / 1e18; // 計算實際退款金額

            // 將退款金額轉移給投資者
            IERC20(usdt).transfer(d, refundAmount);

            // 重置投資者的捐款金額，防止重複退款
            userContributions[d] = 0;
            totalCount++;
        }

        // 重置專案的募資和抵押變數
        totalRaised = 0;
        stakedInAave = 0;

        // 觸發退款事件，記錄已退款的投資者數量
        emit ProjectFailedAndRefunded(totalCount);
    }

    // =================== Aave 存取函式 ===================

    /**
     * @dev 內部函式，將指定金額的 USDT 存入 Aave。
     *      更新 `stakedInAave` 以反映抵押金額。
     * @param amount 要存入 Aave 的 USDT 金額。
     */
    function depositToAave(uint256 amount) internal {
        require(aavePool != address(0), "Aave not set"); // 確保 Aave Pool 地址已設定
        uint256 bal = IERC20(usdt).balanceOf(address(this));
        require(bal >= amount, "Not enough USDT to deposit"); // 確保有足夠的 USDT

        // 授權 Aave Pool 合約轉移 USDT
        IERC20(usdt).approve(aavePool, amount);

        // 將 USDT 供應到 Aave Pool
        IAavePool(aavePool).supply(usdt, amount, address(this), 0);
        stakedInAave += amount; // 更新抵押金額
    }

    /**
     * @dev 內部函式，從 Aave 提領指定的本金金額。
     *      計算並分配任何賺取的利息。
     * @param principal 要從 Aave 提領的本金金額。
     * @return actualPrincipal 實際提領的本金金額。
     * @return userInterest 分配給用戶的利息部分。
     * @return platformInterest 分配給平台的利息部分。
     */
    function withdrawFromAave(uint256 principal)
        internal
        returns (
            uint256 actualPrincipal,
            uint256 userInterest,
            uint256 platformInterest
        )
    {
        require(aavePool != address(0), "Aave not set"); // 確保 Aave Pool 地址已設定
        require(principal > 0, "Principal must be > 0"); // 本金必須大於 0
        require(principal <= stakedInAave, "Not enough staked principal"); // 確保有足夠的抵押資金

        // 計算提領比例
        uint256 totalRedeemable = IERC20(aToken).balanceOf(address(this));
        uint256 ratio = (principal * 1e18) / stakedInAave; // 精度擴大至 1e18
        uint256 toWithdraw = (totalRedeemable * ratio) / 1e18; // 從 Aave 提領的金額

        // 從 Aave 提領資金
        uint256 actualReceived = IAavePool(aavePool).withdraw(usdt, toWithdraw, address(this));

        // 計算賺取的利息
        if (actualReceived > principal) {
            uint256 interest = actualReceived - principal; // 總利息
            platformInterest = interest / 2; // 利息的一半分配給平台
            userInterest = interest - platformInterest; // 剩餘的利息分配給用戶
            actualPrincipal = principal; // 本金保持不變

            // 將用戶部分的利息轉移給專案創建者
            if (userInterest > 0) {
                IERC20(usdt).transfer(creator, userInterest);
            }

            // 將平台部分的利息轉移給平台地址
            if (platformInterest > 0 && platform != address(0)) {
                IERC20(usdt).transfer(platform, platformInterest);
            }
        } else {
            // 如果沒有賺取利息，僅返回本金
            actualPrincipal = actualReceived;
            userInterest = 0;
            platformInterest = 0;
        }

        // 更新抵押金額
        stakedInAave -= principal;

        return (actualPrincipal, userInterest, platformInterest);
    }

    // =================== 輔助函式 ===================

    /**
     * @dev 獲取特定里程碑的狀態和 IPFS CID。
     * @param index 要查詢的里程碑索引（0-3）。
     * @return status 該里程碑的當前狀態。
     * @return cid 該里程碑報告的 IPFS CID。
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


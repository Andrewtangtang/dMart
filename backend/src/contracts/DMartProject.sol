// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title DMartProject (Demo Version)
 * @dev 精簡版本：不使用 USDT / Aave，僅示範多里程碑與投票流程。
 *      - 可以假裝 donate() 來增加 totalRaised
 *      - 里程碑釋放僅做狀態標記，不實際轉移資金
 *      - failAndRefundAll / refundAllInvestors 也不會真的轉移資金，只重設數值
 */
contract DMartProject {
    // ========== 里程碑 ==========

    enum MilestoneStatus { NotStarted, InProgress, Completed }

    struct Milestone {
        MilestoneStatus status; 
        string ipfsCid;         // 指向里程碑報告的 IPFS CID（用來示範）
    }

    Milestone[4] public milestones; 
    uint256 public currentMilestone; // 0~3

    // ========== 專案狀態 ==========

    address public factory;   // Factory 的地址
    address public creator;   // 專案創建者
    uint256 public target;    // 假設的募資目標 (數字表示)
    uint256 public totalRaised; // 假裝的已募資金額

    string public title;
    string public image;
    string public description; // 可再增添更多資料

    // 投資者資訊
    mapping(address => uint256) public userContributions; 
    address[] public donors;

    bool public initialized;      // 確保只初始化一次
    bool public projectFailed;    // 是否已被標記為失敗

    // ========== 事件 ==========

    event ProjectInitialized(address indexed creator, uint256 target);
    event Donated(address indexed donor, uint256 amount);
    event MilestoneReportSubmitted(uint256 indexed milestoneIndex, string ipfsCid);
    event MilestoneFundsReleased(uint256 indexed milestoneIndex);
    event NextMilestoneActivated(uint256 indexed milestoneIndex);
    event MilestoneReset(uint256 indexed milestoneIndex);
    event ProjectFailedAndRefunded(uint256 totalRefundCount);

    // ========== Constructor ==========

    constructor() {
        factory = msg.sender; // 部署者為 Factory
    }

    // ========== 初始化 ==========

    /**
     * @dev 初始化專案(只執行一次)
     * @param _creator 專案創建者
     * @param _target 募資目標(只作紀錄,不會實際操作)
     * @param _title 專案標題
     * @param _image 專案圖片CID或URL
     */
    function initialize(
        address _creator,
        uint256 _target,
        string memory _title,
        string memory _image
    ) external {
        require(msg.sender == factory, "Only factory can init");
        require(!initialized, "Already initialized");

        creator = _creator;
        target = _target;
        title = _title;
        image = _image;
        initialized = true;

        // 預設第一個里程碑為 InProgress
        milestones[0].status = MilestoneStatus.InProgress;
        currentMilestone = 0;

        emit ProjectInitialized(_creator, _target);
    }

    // ========== 投資 / Donate ==========

    /**
     * @dev 假裝捐款: 只增加 totalRaised & userContributions
     * @param amount 用於 Demo 的數字, 不會真的轉 Token
     */
    function donate(uint256 amount) external {
        require(!projectFailed, "Project failed, cannot donate");
        require(amount > 0, "Amount must be > 0");

        totalRaised += amount;
        if (userContributions[msg.sender] == 0) {
            donors.push(msg.sender);
        }
        userContributions[msg.sender] += amount;

        emit Donated(msg.sender, amount);
    }

    // ========== 里程碑報告 & 釋放資金(假) ==========

    function submitMilestoneReport(uint256 milestoneIndex, string calldata cid) external {
        require(msg.sender == creator, "Only creator can submit");
        require(milestoneIndex == currentMilestone, "Not current milestone");
        require(milestones[milestoneIndex].status == MilestoneStatus.InProgress, "Milestone not in progress");

        milestones[milestoneIndex].ipfsCid = cid;
        emit MilestoneReportSubmitted(milestoneIndex, cid);
    }

    /**
     * @dev 假釋放資金: 不實際轉錢,僅做狀態改變 & 事件
     */
    function releaseMilestoneFunds(uint256 milestoneIndex) external {
        require(milestoneIndex == currentMilestone, "Not current milestone");
        require(milestones[milestoneIndex].status == MilestoneStatus.InProgress, "Not in progress");
        require(totalRaised >= target, "Not reached target yet");
        require(!projectFailed, "Project failed, can't release");

        // 標記里程碑已完成
        milestones[milestoneIndex].status = MilestoneStatus.Completed;
        emit MilestoneFundsReleased(milestoneIndex);

        // 若不是最後一個里程碑,自動開啟下一個
        if (milestoneIndex < 3) {
            currentMilestone = milestoneIndex + 1;
            milestones[currentMilestone].status = MilestoneStatus.InProgress;
            emit NextMilestoneActivated(currentMilestone);
        }
    }

    // ========== 重置里程碑 (投票不通過) ==========

    function resetMilestone(uint256 milestoneIndex) external {
        require(msg.sender == factory || msg.sender == creator, "Not authorized");
        require(milestoneIndex == currentMilestone, "Not current milestone");
        require(milestones[milestoneIndex].status == MilestoneStatus.InProgress, "Milestone not in progress");
        milestones[milestoneIndex].ipfsCid = "";
        emit MilestoneReset(milestoneIndex);
    }

    // ========== 專案失敗 ==========

    /**
     * @dev 專案失敗 & 退款(假)
     * @notice 這裡僅將 totalRaised 與 userContributions 歸零, 不做任何金流
     */
    function failAndRefundAll() external {
        require(msg.sender == factory || msg.sender == creator, "Not authorized");
        _setProjectFailed(true);
    }

    /**
     * @dev 當未達標時, 執行退款(假). 只重置變數
     */
    function refundAllInvestors() external {
        require(msg.sender == factory || msg.sender == creator, "Not authorized");
        require(totalRaised < target, "Already reached target");
        _setProjectFailed(false);
    }

    function _setProjectFailed(bool confiscateCollateral) internal {
        require(!projectFailed, "Already failed");
        projectFailed = true;

        // 重置籌資紀錄
        uint256 count = 0;
        for (uint256 i = 0; i < donors.length; i++) {
            address d = donors[i];
            if (userContributions[d] > 0) {
                userContributions[d] = 0;
                count++;
            }
        }
        totalRaised = 0;

        // 觸發事件
        emit ProjectFailedAndRefunded(count);
    }

    // ========== Getter / 輔助查詢 ==========

    function getMilestone(uint256 index) external view returns (MilestoneStatus status, string memory cid) {
        Milestone memory m = milestones[index];
        return (m.status, m.ipfsCid);
    }
}


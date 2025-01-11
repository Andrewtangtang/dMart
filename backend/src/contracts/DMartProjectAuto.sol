// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// 引入 Chainlink 合約，用於自動化和預言機交互
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

// 介面定義
interface IDMartProject {
    function currentMilestone() external view returns (uint256);
    function submitMilestoneReport(uint256 milestoneIndex, string calldata cid) external;
    function releaseMilestoneFunds(uint256 milestoneIndex) external;
    function resetMilestone(uint256 milestoneIndex) external;
    function refundAllInvestors() external;
    function failAndRefundAll() external;       // 新增
    function totalRaised() external view returns(uint256);
    function target() external view returns(uint256);
}

interface IDMartFactory {
    function projectDeadlines(address project) external view returns(uint256);
    function isProject(address addr) external view returns(bool);
}

/**
 * @title DMartProjectAuto
 * @dev 自動化合約，利用 Chainlink Keepers 管理投票提案和資金分配。
 *      它自動創建投票提案，檢索投票結果，並根據結果釋放資金或觸發退款機制。
 *      與 DMartProject 和 DMartFactory 合約整合，確保無縫運作。
 */
contract DMartProjectAuto is ChainlinkClient, KeeperCompatibleInterface, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    // 列舉投票結果的可能結果
    enum VoteOutcome { Undecided, Yes, No }

    // 列舉里程碑自動化狀態
    enum MilestoneAutoStatus { Idle, VotingOpen, VotingEnded }

    /**
     * @dev 儲存每個里程碑的自動化細節結構。
     * @param status 該里程碑的當前自動化狀態。
     * @param proposalId Chainlink 提供的投票提案 ID。
     * @param outcome 投票結果（Yes、No、Undecided）。
     * @param executed 指示該結果是否已被執行。
     */
    struct MilestoneAuto {
        MilestoneAutoStatus status;
        bytes32 proposalId;
        VoteOutcome outcome;
        bool executed;
    }

    // 從里程碑索引到其自動化細節的映射
    mapping(uint256 => MilestoneAuto) public milestoneAutos;

    // Chainlink 相關變數
    address public oracle;            // Chainlink Oracle 地址
    bytes32 public jobIdCreate;       // 創建投票提案的 Job ID
    bytes32 public jobIdResult;       // 獲取投票結果的 Job ID
    uint256 public fee;               // Chainlink 請求的費用

    // 與 DMartProject 和 DMartFactory 合約的參考
    IDMartProject public project;       // 用於與 DMartProject 合約互動的介面
    IDMartFactory public factory;       // 用於與 DMartFactory 合約互動的介面，主要用於截止時間檢查

    // 事件聲明，用於紀錄自動化操作和 Chainlink 請求
    event UpkeepAction(uint indexed milestoneIndex, string action);
    event RequestCreateProposalSent(uint256 indexed milestoneIndex, bytes32 indexed requestId);
    event RequestGetResultSent(uint256 indexed milestoneIndex, bytes32 indexed requestId);

    /**
     * @dev 構造函數，初始化自動化合約，設定必要的參數。
     *      設定 Chainlink 代幣和 Oracle 詳細資訊。
     * @param _project DMartProject 合約的地址，用於自動化管理。
     * @param _factory DMartFactory 合約的地址，用於截止時間檢查。
     * @param _linkToken Chainlink LINK 代幣的地址。
     * @param _oracle Chainlink Oracle 的地址，用於處理請求。
     * @param _jobIdCreate 創建投票提案的 Job ID。
     * @param _jobIdResult 獲取投票結果的 Job ID。
     * @param _fee Chainlink 請求所需的費用。
     */
    constructor(
        address _project,
        address _factory,
        address _linkToken,
        address _oracle,
        bytes32 _jobIdCreate,
        bytes32 _jobIdResult,
        uint256 _fee
    ) ConfirmedOwner(msg.sender) {
        setChainlinkToken(_linkToken); // 設定 LINK 代幣地址

        project = IDMartProject(_project); // 初始化 DMartProject 介面
        factory = IDMartFactory(_factory); // 初始化 DMartFactory 介面

        oracle = _oracle;                   // 設定 Oracle 地址
        jobIdCreate = _jobIdCreate;         // 設定創建提案的 Job ID
        jobIdResult = _jobIdResult;         // 設定獲取結果的 Job ID
        fee = _fee;                         // 設定 Chainlink 請求的費用
    }

    // =================== KeeperCompatibleInterface 實作 ===================

    /**
     * @dev 檢查是否需要執行任何 upkeep。
     *      判斷專案是否已經到期未達目標，或者某個里程碑需要動作。
     * @param checkData 此實作中未使用。
     * @return upkeepNeeded 布林值，指示是否需要 upkeep。
     * @return performData 編碼數據，指示要執行的動作。
     */
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        // 1. 檢查專案是否已經到期且未達募資目標
        uint256 deadline = factory.projectDeadlines(address(project));
        if (block.timestamp > deadline) {
            if (project.totalRaised() < project.target()) {
                upkeepNeeded = true;
                performData = abi.encode("REFUND"); // 指示需要執行退款
                return (upkeepNeeded, performData);
            }
        }

        // 2. 檢查當前里程碑的自動化狀態
        uint256 mIndex = project.currentMilestone(); // 獲取當前里程碑索引
        MilestoneAuto memory ma = milestoneAutos[mIndex]; // 獲取該里程碑的自動化細節

        if (ma.status == MilestoneAutoStatus.Idle) {
            // 如果里程碑處於閒置狀態，需要創建投票提案
            upkeepNeeded = true;
            performData = abi.encode(mIndex, "CREATE"); // 指示創建投票提案
            return (upkeepNeeded, performData);
        }
        if (ma.status == MilestoneAutoStatus.VotingOpen) {
            // 如果投票已開啟，需要最終化投票結果
            upkeepNeeded = true;
            performData = abi.encode(mIndex, "FINALIZE"); // 指示最終化投票
            return (upkeepNeeded, performData);
        }

        // 如果以上條件均不符合，則不需要 upkeep
        return (false, bytes(""));
    }

    /**
     * @dev 執行所需的 upkeep，根據提供的 performData。
     *      處理退款、創建投票提案和最終化投票結果。
     * @param performData 編碼數據，指示要執行的動作。
     */
    function performUpkeep(bytes calldata performData) external override {
        bytes memory data = performData;

        // 解碼 performData 以確定所需的動作
        // 檢查動作是否為退款
        if (keccak256(data) == keccak256(abi.encode("REFUND"))) {
            project.refundAllInvestors(); // 觸發退款過程
            return;
        }

        // 否則，解碼為 (milestoneIndex, action)
        (uint256 milestoneIndex, string memory action) = abi.decode(data, (uint256, string));
        emit UpkeepAction(milestoneIndex, action); // 紀錄正在執行的動作

        // 根據解碼的數據執行對應的動作
        if (keccak256(bytes(action)) == keccak256("CREATE")) {
            // 如果動作是創建投票提案
            requestCreateProposal(milestoneIndex);
        } else if (keccak256(bytes(action)) == keccak256("FINALIZE")) {
            // 如果動作是最終化投票結果
            requestGetProposalResult(milestoneIndex);
        }
    }

    // =================== 投票提案創建 ===================

    /**
     * @dev 內部函式，用於為特定里程碑創建投票提案。
     *      發送 Chainlink 請求以創建提案。
     * @param mIndex 要為其創建提案的里程碑索引。
     */
    function requestCreateProposal(uint256 mIndex) internal {
        MilestoneAuto storage ma = milestoneAutos[mIndex];
        require(ma.status == MilestoneAutoStatus.Idle, "Wrong status"); // 確保里程碑為閒置狀態
        ma.status = MilestoneAutoStatus.VotingOpen; // 更新狀態為投票開啟
        ma.outcome = VoteOutcome.Undecided; // 初始化結果為未決定

        // 建立 Chainlink 請求，用於創建投票提案
        Chainlink.Request memory req = buildChainlinkRequest(
            jobIdCreate, // 創建提案的 Job ID
            address(this), // 回調地址
            this.fulfillCreateProposal.selector // 回調函式
        );

        // 添加 Chainlink 請求的參數
        req.addUint("milestoneIndex", mIndex); // 指定里程碑索引

        // 將 Chainlink 請求發送至指定的 Oracle
        bytes32 requestId = sendChainlinkRequestTo(oracle, req, fee);
        emit RequestCreateProposalSent(mIndex, requestId); // 紀錄請求
    }

    /**
     * @dev Chainlink 回調函式，用於滿足創建提案的請求。
     *      記錄從 Oracle 獲取的提案 ID。
     * @param _requestId Chainlink 請求的唯一標識符。
     * @param milestoneIdx 相關的里程碑索引。
     * @param proposalId 創建的投票提案的唯一 ID。
     */
    function fulfillCreateProposal(bytes32 _requestId, uint256 milestoneIdx, bytes32 proposalId)
        public
        recordChainlinkFulfillment(_requestId)
    {
        MilestoneAuto storage ma = milestoneAutos[milestoneIdx];
        require(ma.status == MilestoneAutoStatus.VotingOpen, "Not in VotingOpen"); // 確保狀態為投票開啟
        ma.proposalId = proposalId; // 記錄提案 ID
    }

    // =================== 投票結果獲取 ===================

    /**
     * @dev 內部函式，用於獲取投票提案的結果。
     *      發送 Chainlink 請求以獲取投票結果。
     * @param mIndex 要獲取結果的里程碑索引。
     */
    function requestGetProposalResult(uint256 mIndex) internal {
        MilestoneAuto storage ma = milestoneAutos[mIndex];
        require(ma.status == MilestoneAutoStatus.VotingOpen, "Wrong status"); // 確保投票處於開啟狀態
        require(ma.proposalId != bytes32(0), "No proposalId"); // 確保提案 ID 存在

        // 建立 Chainlink 請求，用於獲取投票結果
        Chainlink.Request memory req = buildChainlinkRequest(
            jobIdResult, // 獲取結果的 Job ID
            address(this), // 回調地址
            this.fulfillGetProposalResult.selector // 回調函式
        );

        // 添加 Chainlink 請求的參數
        req.addUint("milestoneIndex", mIndex); // 指定里程碑索引
        req.addBytes32("proposalId", ma.proposalId); // 指定提案 ID

        // 將 Chainlink 請求發送至指定的 Oracle
        bytes32 requestId = sendChainlinkRequestTo(oracle, req, fee);
        emit RequestGetResultSent(mIndex, requestId); // 紀錄請求
    }

    /**
     * @dev Chainlink 回調函式，用於滿足獲取投票結果的請求。
     *      根據投票結果執行相應的動作。
     * @param _requestId Chainlink 請求的唯一標識符。
     * @param milestoneIdx 相關的里程碑索引。
     * @param yesCount 贊成票數量。
     * @param noCount 反對票數量。
     */
    function fulfillGetProposalResult(
        bytes32 _requestId,
        uint256 milestoneIdx,
        uint256 yesCount,
        uint256 noCount
    ) public recordChainlinkFulfillment(_requestId) {
        MilestoneAuto storage ma = milestoneAutos[milestoneIdx];
        require(ma.status == MilestoneAutoStatus.VotingOpen, "Not in VotingOpen"); // 確保投票處於開啟狀態

        // 根據投票結果確定結果
        if (yesCount > noCount) {
            ma.outcome = VoteOutcome.Yes; // 投票通過
        } else {
            ma.outcome = VoteOutcome.No; // 投票失敗或平局
        }

        // 更新狀態為投票結束
        ma.status = MilestoneAutoStatus.VotingEnded;
        ma.executed = false; // 重置執行標誌

        // 根據投票結果執行後續動作
        _executeVotingOutcome(milestoneIdx);
    }

    /**
     * @dev 內部函式，根據投票結果執行相應的動作。
     *      如果投票結果為 Yes，則釋放該里程碑的資金。
     *      如果投票結果為 No，則標記專案為失敗並啟動退款。
     * @param milestoneIdx 相關的里程碑索引。
     */
    function _executeVotingOutcome(uint256 milestoneIdx) internal {
        MilestoneAuto storage ma = milestoneAutos[milestoneIdx];
        require(ma.status == MilestoneAutoStatus.VotingEnded, "Voting not ended yet"); // 確保投票已結束
        require(!ma.executed, "Outcome already executed"); // 防止結果被重複執行
        ma.executed = true; // 標記結果已執行

        if (ma.outcome == VoteOutcome.Yes) {
            // 如果投票通過，釋放該里程碑的資金
            project.releaseMilestoneFunds(milestoneIdx);
        } else {
            // 如果投票失敗，標記專案為失敗並啟動退款
            project.failAndRefundAll();
        }
    }

    // =================== 擁有者函式 ===================

    /**
     * @dev 允許合約擁有者更新 Chainlink Oracle 和 Job ID。
     *      僅限合約擁有者調用。
     * @param _oracle 新的 Chainlink Oracle 地址。
     * @param _jobIdCreate 新的創建投票提案的 Job ID。
     * @param _jobIdResult 新的獲取投票結果的 Job ID。
     * @param _fee 新的 Chainlink 請求費用。
     */
    function setOracleJob(
        address _oracle,
        bytes32 _jobIdCreate,
        bytes32 _jobIdResult,
        uint256 _fee
    ) external onlyOwner {
        oracle = _oracle;                 // 更新 Oracle 地址
        jobIdCreate = _jobIdCreate;       // 更新創建提案的 Job ID
        jobIdResult = _jobIdResult;       // 更新獲取結果的 Job ID
        fee = _fee;                       // 更新 Chainlink 請求費用
    }

    /**
     * @dev 允許合約擁有者提領合約中剩餘的 LINK 代幣。
     *      用於回收未使用的資金或管理合約的 LINK 餘額。
     *      僅限合約擁有者調用。
     */
    function withdrawLink() external onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress()); // 與 LINK 代幣互動的介面
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer LINK"); // 將 LINK 轉移給擁有者
    }
}


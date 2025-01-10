// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// 引入 Chainlink 相關接口與合約
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

/**
 * @title DMartProjectAuto
 * @dev 自動化合約，使用 Chainlink Keepers 進行投票創建與結果獲取，並處理退款機制。
 */
contract DMartProjectAuto is ChainlinkClient, KeeperCompatibleInterface, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    // 投票結果枚舉
    enum VoteOutcome { Undecided, Yes, No }
    // 里程碑自動化狀態枚舉
    enum MilestoneAutoStatus { Idle, VotingOpen, VotingEnded }

    // 里程碑自動化結構體
    struct MilestoneAuto {
        MilestoneAutoStatus status;   // 當前狀態
        bytes32 proposalId;           // 投票提案 ID
        VoteOutcome outcome;          // 投票結果
        bool executed;                // 是否已執行結果
    }

    // 里程碑自動化狀態映射（里程碑索引 => 狀態）
    mapping(uint256 => MilestoneAuto) public milestoneAutos;

    // Chainlink 相關參數
    address public oracle;            // Chainlink Oracle 地址
    bytes32 public jobIdCreate;       // 創建投票提案的 Job ID
    bytes32 public jobIdResult;       // 獲取投票結果的 Job ID
    uint256 public fee;               // Chainlink 付費金額

    // 參考的專案合約與 Factory 合約
    DMartProject public project;       // 目標專案合約
    DMartFactory public factory;       // Factory 合約，用於查詢專案截止時間

    // 事件定義
    event UpkeepAction(uint indexed milestoneIndex, string action);
    event RequestCreateProposalSent(uint256 indexed milestoneIndex, bytes32 indexed requestId);
    event RequestGetResultSent(uint256 indexed milestoneIndex, bytes32 indexed requestId);

    /**
     * @dev Constructor，設置 Chainlink 相關參數並初始化專案與 Factory 合約地址
     * @param _project 目標專案合約地址
     * @param _factory Factory 合約地址
     * @param _linkToken Chainlink LINK 代幣地址
     * @param _oracle Chainlink Oracle 地址
     * @param _jobIdCreate 創建投票提案的 Job ID
     * @param _jobIdResult 獲取投票結果的 Job ID
     * @param _fee Chainlink 付費金額
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
        // 設置 Chainlink LINK 代幣地址
        setChainlinkToken(_linkToken);

        // 設定專案與 Factory 合約地址
        project = DMartProject(_project);
        factory = DMartFactory(_factory);
        oracle = _oracle;
        jobIdCreate = _jobIdCreate;
        jobIdResult = _jobIdResult;
        fee = _fee;
    }

    // ============== KeeperCompatibleInterface 實作 ==============
    
    /**
     * @dev 檢查是否需要執行 upkeep（自動化任務）
     *      1. 檢查專案是否逾期且未達標，若是則觸發退款
     *      2. 檢查當前里程碑狀態，決定是否創建投票或結算投票結果
     * @param checkData 不使用的參數
     * @return upkeepNeeded 是否需要執行 upkeep
     * @return performData 要執行的資料（如 "REFUND" 或里程碑索引與動作）
     */
    function checkUpkeep(bytes calldata checkData) external view override returns (bool upkeepNeeded, bytes memory performData) {
        // 1. 檢查專案是否逾期且未達標，若是則需要執行退款
        if(block.timestamp > factory.projectDeadlines(address(project))) {
            if(project.totalRaised() < project.target()){
                upkeepNeeded = true;
                performData = abi.encode("REFUND");
                return (upkeepNeeded, performData);
            }
        }

        // 2. 檢查當前里程碑狀態
        uint256 mIndex = project.currentMilestone();
        MilestoneAuto memory ma = milestoneAutos[mIndex];

        if (ma.status == MilestoneAutoStatus.Idle) {
            // 若狀態為 Idle，需創建投票提案
            upkeepNeeded = true;
            performData = abi.encode(mIndex, "CREATE");
            return (upkeepNeeded, performData);
        }
        if (ma.status == MilestoneAutoStatus.VotingOpen) {
            // 若狀態為 VotingOpen，需結算投票結果
            upkeepNeeded = true;
            performData = abi.encode(mIndex, "FINALIZE");
            return (upkeepNeeded, performData);
        }

        // 若無需執行任何 upkeep
        return (false, bytes(""));
    }

    /**
     * @dev 執行 upkeep，處理相應的自動化任務
     *      1. 若 performData 為 "REFUND"，則執行退款
     *      2. 若 performData 為 (milestoneIndex, "CREATE")，則創建投票提案
     *      3. 若 performData 為 (milestoneIndex, "FINALIZE")，則結算投票結果
     * @param performData 要執行的資料
     */
    function performUpkeep(bytes calldata performData) external override {
        bytes memory data = performData;

        // 檢查是否為 "REFUND" 任務
        if(keccak256(data) == keccak256(abi.encode("REFUND"))){
            // 執行退款
            project.refundAllInvestors();
            return;
        }
        
        // 解碼 performData 為 (milestoneIndex, action)
        (uint256 milestoneIndex, string memory action) = abi.decode(data, (uint256, string));
        emit UpkeepAction(milestoneIndex, action);

        // 根據 action 執行不同的任務
        if (keccak256(bytes(action)) == keccak256("CREATE")) {
            // 創建投票提案
            requestCreateProposal(milestoneIndex);
        } else if (keccak256(bytes(action)) == keccak256("FINALIZE")) {
            // 結算投票結果
            requestGetProposalResult(milestoneIndex);
        }
    }

    // ============== 創建投票提案 ==============
    
    /**
     * @dev 創建投票提案，並發送 Chainlink 請求
     * @param mIndex 里程碑索引
     */
    function requestCreateProposal(uint256 mIndex) internal {
        MilestoneAuto storage ma = milestoneAutos[mIndex];
        require(ma.status == MilestoneAutoStatus.Idle, "Wrong status");
        ma.status = MilestoneAutoStatus.VotingOpen;
        ma.outcome = VoteOutcome.Undecided;

        // 建立 Chainlink 請求
        Chainlink.Request memory req = buildChainlinkRequest(
            jobIdCreate, 
            address(this), 
            this.fulfillCreateProposal.selector
        );
        // 添加參數至請求中（如里程碑索引）
        req.addUint("milestoneIndex", mIndex);

        // 發送 Chainlink 請求
        bytes32 requestId = sendChainlinkRequestTo(oracle, req, fee);
        emit RequestCreateProposalSent(mIndex, requestId);
    }

    /**
     * @dev Chainlink 回調函式，處理創建投票提案的結果
     * @param _requestId 請求 ID
     * @param milestoneIdx 里程碑索引
     * @param proposalId 投票提案 ID
     */
    function fulfillCreateProposal(bytes32 _requestId, uint256 milestoneIdx, bytes32 proposalId)
        public
        recordChainlinkFulfillment(_requestId)
    {
        MilestoneAuto storage ma = milestoneAutos[milestoneIdx];
        require(ma.status == MilestoneAutoStatus.VotingOpen, "Not in VotingOpen");
        ma.proposalId = proposalId;
    }

    // ============== 獲取投票結果 ==============
    
    /**
     * @dev 獲取投票結果，並發送 Chainlink 請求
     * @param mIndex 里程碑索引
     */
    function requestGetProposalResult(uint256 mIndex) internal {
        MilestoneAuto storage ma = milestoneAutos[mIndex];
        require(ma.status == MilestoneAutoStatus.VotingOpen, "Wrong status");
        require(ma.proposalId != bytes32(0), "No proposalId");

        // 建立 Chainlink 請求
        Chainlink.Request memory req = buildChainlinkRequest(
            jobIdResult,
            address(this),
            this.fulfillGetProposalResult.selector
        );
        // 添加參數至請求中（如里程碑索引與提案 ID）
        req.addUint("milestoneIndex", mIndex);
        req.addBytes32("proposalId", ma.proposalId);

        // 發送 Chainlink 請求
        bytes32 requestId = sendChainlinkRequestTo(oracle, req, fee);
        emit RequestGetResultSent(mIndex, requestId);
    }

    /**
     * @dev Chainlink 回調函式，處理投票結果
     * @param _requestId 請求 ID
     * @param milestoneIdx 里程碑索引
     * @param yesCount 贊成票數
     * @param noCount 反對票數
     */
    function fulfillGetProposalResult(
        bytes32 _requestId,
        uint256 milestoneIdx,
        uint256 yesCount,
        uint256 noCount
    ) public recordChainlinkFulfillment(_requestId) {
        MilestoneAuto storage ma = milestoneAutos[milestoneIdx];
        require(ma.status == MilestoneAutoStatus.VotingOpen, "Not in VotingOpen");

        // 判斷投票結果：贊成票多於反對票則為 Yes，否則為 No（包含平手）
        if (yesCount > noCount) {
            ma.outcome = VoteOutcome.Yes;
        } else {
            ma.outcome = VoteOutcome.No;
        }

        // 更新狀態為 VotingEnded
        ma.status = MilestoneAutoStatus.VotingEnded;
        ma.executed = false;

        // 執行投票結果處理
        _executeVotingOutcome(milestoneIdx);
    }

    /**
     * @dev 執行投票結果的後續動作
     *      若結果為 Yes，釋放資金；若為 No，要求募資人重新提交報告
     * @param milestoneIdx 里程碑索引
     */
    function _executeVotingOutcome(uint256 milestoneIdx) internal {
        MilestoneAuto storage ma = milestoneAutos[milestoneIdx];
        require(ma.status == MilestoneAutoStatus.VotingEnded, "Not ended yet");
        require(!ma.executed, "Already executed");
        ma.executed = true;

        if (ma.outcome == VoteOutcome.Yes) {
            // 投票通過，釋放資金
            project.releaseMilestoneFunds(milestoneIdx);
        } else {
            // 投票未通過，重置里程碑，要求重新提交報告
            project.resetMilestone(milestoneIdx);

            // 將 MilestoneAuto 狀態重置為 Idle，以便重新創建投票
            ma.status = MilestoneAutoStatus.Idle;
            ma.proposalId = bytes32(0);
            ma.outcome = VoteOutcome.Undecided;
            ma.executed = false; 
        }
    }

    // ============== 管理者函式 ==========
    
    /**
     * @dev 設定 Chainlink Oracle 與 Job ID，僅限擁有者呼叫
     * @param _oracle Chainlink Oracle 地址
     * @param _jobIdCreate 創建投票提案的 Job ID
     * @param _jobIdResult 獲取投票結果的 Job ID
     * @param _fee Chainlink 付費金額
     */
    function setOracleJob(
        address _oracle,
        bytes32 _jobIdCreate,
        bytes32 _jobIdResult,
        uint256 _fee
    ) external onlyOwner {
        oracle = _oracle;
        jobIdCreate = _jobIdCreate;
        jobIdResult = _jobIdResult;
        fee = _fee;
    }

    /**
     * @dev 提領合約內的 LINK 代幣，僅限擁有者呼叫
     */
    function withdrawLink() external onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer LINK");
    }
}


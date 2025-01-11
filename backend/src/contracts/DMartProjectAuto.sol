// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// --------- Chainlink 相關 ---------
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// --------- DMartProject & Factory 介面 ---------
interface IDMartProject {
    function currentMilestone() external view returns (uint256);
    function submitMilestoneReport(uint256 milestoneIndex, string calldata cid) external;
    function releaseMilestoneFunds(uint256 milestoneIndex) external;
    function resetMilestone(uint256 milestoneIndex) external;
    function refundAllInvestors() external;
    function failAndRefundAll() external;
    function totalRaised() external view returns(uint256);
    function target() external view returns(uint256);
}

interface IDMartFactory {
    function projectDeadlines(address project) external view returns(uint256);
    function isProject(address addr) external view returns(bool);
}

/**
 * @title DMartProjectAuto (Multiple Projects)
 * @dev 單一合約管理多個 DMartProject，以減少部署次數。使用 Chainlink Keepers 自動化投票流程。
 */
contract DMartProjectAuto is ChainlinkClient, KeeperCompatibleInterface, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    // ========== 枚舉 & 結構 ==========

    // 投票結果
    enum VoteOutcome { Undecided, Yes, No }

    // 里程碑自動化狀態
    enum MilestoneAutoStatus { Idle, VotingOpen, VotingEnded }

    /**
     * @dev 每個 (專案, 里程碑) 都會有一個 MilestoneAuto 狀態
     */
    struct MilestoneAuto {
        MilestoneAutoStatus status;  // Idle / VotingOpen / VotingEnded
        bytes32 proposalId;          // 提案ID (經 Chainlink 回傳)
        VoteOutcome outcome;         // Yes / No / Undecided
        bool executed;               // 是否已執行結論
    }

    // ========== 狀態變數 ==========

    // 追蹤的所有專案清單
    address[] public allTrackedProjects;
    // 是否已追蹤
    mapping(address => bool) public isTracked;

    // Milestone 自動化細節：mapping(專案 => (milestoneIndex => MilestoneAuto))
    mapping(address => mapping(uint256 => MilestoneAuto)) public milestoneAutos;

    // Chainlink 相關
    address public oracle;            // Chainlink Oracle 地址
    bytes32 public jobIdCreate;       // 創建提案的 Job ID
    bytes32 public jobIdResult;       // 獲取結果的 Job ID
    uint256 public fee;               // Chainlink 請求費用
    address public linkToken;         // LINK Token 地址

    // 事件
    event ProjectRegistered(address indexed project);
    event UpkeepAction(address indexed project, uint indexed milestoneIndex, string action);
    event RequestCreateProposalSent(address indexed project, uint256 indexed milestoneIndex, bytes32 requestId);
    event RequestGetResultSent(address indexed project, uint256 indexed milestoneIndex, bytes32 requestId);
    event SnapshotProposalCreated(address indexed project, uint256 milestoneIndex, bytes32 proposalId);

    // ========== Constructor ==========

    constructor(
        address _linkToken,
        address _oracle,
        bytes32 _jobIdCreate,
        bytes32 _jobIdResult,
        uint256 _fee
    ) ConfirmedOwner(msg.sender) {
        linkToken = _linkToken;
        _setChainlinkToken(_linkToken);

        oracle = _oracle;
        jobIdCreate = _jobIdCreate;
        jobIdResult = _jobIdResult;
        fee = _fee;
    }

    // ========== 註冊專案 (由 Factory 呼叫) ==========

    /**
     * @dev 將某個 DMartProject 註冊到本合約管理
     *      - 假設只有合約擁有者 (或 factory) 可以呼叫
     */
    function registerProject(address projectAddr) external onlyOwner {
        require(!isTracked[projectAddr], "Already tracked");
        // 也可加個 require(factory.isProject(projectAddr), "...") 如果需要
        isTracked[projectAddr] = true;
        allTrackedProjects.push(projectAddr);

        emit ProjectRegistered(projectAddr);
    }

    /**
     * @dev 取得已追蹤的專案數量
     */
    function allTrackedProjectsLength() external view returns (uint256) {
        return allTrackedProjects.length;
    }

    // ========== KeeperCompatibleInterface ==========

    /**
     * @notice checkUpkeep: 檢查是否有任何專案需要自動化動作
     *
     * @dev 這裡簡單做法：依序掃描 allTrackedProjects，
     *    找出第一個「需要動作」的(專案, 里程碑)。若找到，就回傳 performData。
     *    只要找到一個就結束(因為 Chainlink 每次只執行一次 performUpkeep)。
     *
     *    注意：若專案多且邏輯複雜，可能 gas 不足，需要更進階的「分批檢查」設計。
     */
    function checkUpkeep(bytes calldata)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        for (uint i = 0; i < allTrackedProjects.length; i++) {
            address proj = allTrackedProjects[i];
            if (!isTracked[proj]) continue; // 避免無效

            // 先檢查是否需要Refund
            uint256 deadline = IDMartFactory(owner()).projectDeadlines(proj);
            // 這裡假設owner()就是factory，如果您另有factory變數，需要調整。
            // 或您可在registerProject時把deadline帶進來紀錄(因應您的架構)
            if (block.timestamp > deadline) {
                if (IDMartProject(proj).totalRaised() < IDMartProject(proj).target()) {
                    // Refund
                    // 編碼performData: (專案地址, 0, "REFUND")
                    upkeepNeeded = true;
                    performData = abi.encode(proj, 0, "REFUND");
                    return (true, performData);
                }
            }

            // 如果不需要 refund, 再檢查 Milestone 狀態
            uint256 mIndex = IDMartProject(proj).currentMilestone();
            MilestoneAuto memory ma = milestoneAutos[proj][mIndex];

            if (ma.status == MilestoneAutoStatus.Idle) {
                // 需要 CREATE
                upkeepNeeded = true;
                performData = abi.encode(proj, mIndex, "CREATE");
                return (true, performData);
            } else if (ma.status == MilestoneAutoStatus.VotingOpen) {
                // 需要 FINALIZE
                upkeepNeeded = true;
                performData = abi.encode(proj, mIndex, "FINALIZE");
                return (true, performData);
            }
        }

        // 如果沒有任何需要動作的專案
        return (false, "");
    }

    /**
     * @notice performUpkeep: 執行對應動作
     */
    function performUpkeep(bytes calldata performData) external override {
        (address proj, uint256 mIndex, string memory action) =
            abi.decode(performData, (address, uint256, string));

        emit UpkeepAction(proj, mIndex, action);

        // REFUND
        if (keccak256(bytes(action)) == keccak256("REFUND")) {
            IDMartProject(proj).refundAllInvestors();
            return;
        }

        // CREATE
        if (keccak256(bytes(action)) == keccak256("CREATE")) {
            requestCreateProposal(proj, mIndex);
            return;
        }

        // FINALIZE
        if (keccak256(bytes(action)) == keccak256("FINALIZE")) {
            requestGetProposalResult(proj, mIndex);
            return;
        }
    }

    // ========== 建立投票提案 ==========

    function requestCreateProposal(address proj, uint256 mIndex) internal {
        MilestoneAuto storage ma = milestoneAutos[proj][mIndex];
        require(ma.status == MilestoneAutoStatus.Idle, "Wrong status");
        ma.status = MilestoneAutoStatus.VotingOpen;
        ma.outcome = VoteOutcome.Undecided;

        // 建立 Chainlink 請求
        Chainlink.Request memory req = _buildChainlinkRequest(
            jobIdCreate,
            address(this),
            this.fulfillCreateProposal.selector
        );

        // 可能需要加參數，如 milestoneIndex, projectAddr 等
        req._addUint("milestoneIndex", mIndex);
        // 如果需要 projectAddr, 也可以加:
        req._add("projectAddress", Strings.toHexString(uint160(proj), 20));

        // 發送 Chainlink 請求
        bytes32 requestId = _sendChainlinkRequestTo(oracle, req, fee);
        emit RequestCreateProposalSent(proj, mIndex, requestId);
    }

    // fulfillCreateProposal
    function fulfillCreateProposal(bytes32 _requestId, address proj, uint256 milestoneIdx, bytes32 proposalId)
        public
        recordChainlinkFulfillment(_requestId)
    {
        MilestoneAuto storage ma = milestoneAutos[proj][milestoneIdx];
        require(ma.status == MilestoneAutoStatus.VotingOpen, "Not VotingOpen");

        // 記錄回傳的proposalId
        ma.proposalId = proposalId;

        emit SnapshotProposalCreated(proj, milestoneIdx, proposalId);
    }

    // ========== 獲取投票結果 ==========

    function requestGetProposalResult(address proj, uint256 mIndex) internal {
        MilestoneAuto storage ma = milestoneAutos[proj][mIndex];
        require(ma.status == MilestoneAutoStatus.VotingOpen, "Wrong status");
        require(ma.proposalId != bytes32(0), "No proposalId");

        Chainlink.Request memory req = _buildChainlinkRequest(
            jobIdResult,
            address(this),
            this.fulfillGetProposalResult.selector
        );

        req._addUint("milestoneIndex", mIndex);
        // 這裡可以用 bytes32 -> string
        req._add("proposalId", string(abi.encodePacked(ma.proposalId)));
        req._add("projectAddress", Strings.toHexString(uint160(proj), 20));

        bytes32 requestId = _sendChainlinkRequestTo(oracle, req, fee);
        emit RequestGetResultSent(proj, mIndex, requestId);
    }

    // fulfillGetProposalResult
    function fulfillGetProposalResult(
        bytes32 _requestId,
        address proj,
        uint256 milestoneIdx,
        uint256 yesCount,
        uint256 noCount
    )
        public
        recordChainlinkFulfillment(_requestId)
    {
        MilestoneAuto storage ma = milestoneAutos[proj][milestoneIdx];
        require(ma.status == MilestoneAutoStatus.VotingOpen, "Not VotingOpen");

        if (yesCount > noCount) {
            ma.outcome = VoteOutcome.Yes;
        } else {
            ma.outcome = VoteOutcome.No;
        }

        ma.status = MilestoneAutoStatus.VotingEnded;
        ma.executed = false;

        _executeVotingOutcome(proj, milestoneIdx);
    }

    // 執行投票結果
    function _executeVotingOutcome(address proj, uint256 milestoneIdx) internal {
        MilestoneAuto storage ma = milestoneAutos[proj][milestoneIdx];
        require(ma.status == MilestoneAutoStatus.VotingEnded, "Voting not ended");
        require(!ma.executed, "Already executed");
        ma.executed = true;

        if (ma.outcome == VoteOutcome.Yes) {
            // milestone成功
            IDMartProject(proj).releaseMilestoneFunds(milestoneIdx);
        } else {
            // milestone失敗 -> fail & refund
            IDMartProject(proj).failAndRefundAll();
        }
    }

    // ========== Owner function ==========

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

    function withdrawLink() external onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(_chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer LINK");
    }
}


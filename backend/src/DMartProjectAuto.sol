// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

/**
 * 依賴Chainlink:
 *    "KeeperCompatibleInterface"  => checkUpkeep/performUpkeep
 *    "ChainlinkClient" => sendChainlinkRequestTo + recordChainlinkFulfillment
 */
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

/**
 * @dev 
 *   - NFT投票(Off-chain Snapshot,三選: Yes/No/Incomplete)
 *   - 由 Chainlink Automation 週期檢查 => 
 *       a) 創建投票
 *       b) 結束時抓取投票結果
 *   - 透過 Chainlink Any-API (sendChainlinkRequestTo) 與External Adapter溝通
 */
contract DMartAutoVoteFull is ChainlinkClient, KeeperCompatibleInterface, ConfirmedOwner {

    using Chainlink for Chainlink.Request;

    // --------------------------
    // 參數 & 結構
    // --------------------------
    enum VoteOutcome { Undecided, Yes, No, Incomplete }

    enum MilestoneStatus { NotStarted, VotingOpen, VotingEnded }

    struct Milestone {
        string ipfsHash;          // 報告
        uint startTime;           // 投票開始時間
        uint endTime;             // 投票結束時間
        MilestoneStatus status;
        bytes32 proposalId;       // snapshot proposalId
        VoteOutcome outcome;
        bool executed;            // 是否執行後續動作(釋放funds etc)
    }

    // 里程碑列表
    mapping(uint => Milestone) public milestones;
    uint public totalMilestones;

    // Chainlink Any-API
    address public oracleAddress;     // oracle address
    bytes32 public jobIdCreate;       // job id for create proposal
    bytes32 public jobIdResult;       // job id for get result
    uint256 public fee;               // link fee

    // =========== events ===========
    event MilestoneCreated(uint indexed index, string ipfsHash, uint start, uint end);
    event UpkeepAction(uint indexed index, string action); // e.g. "CREATE", "FINALIZE"
    event RequestCreateProposalSent(bytes32 indexed requestId, uint milestoneIndex);
    event FulfillCreateProposal(bytes32 indexed requestId, uint milestoneIndex, bytes32 proposalId);
    event RequestGetResultSent(bytes32 indexed requestId, uint milestoneIndex);
    event FulfillGetProposalResult(bytes32 indexed requestId, uint milestoneIndex, uint yes, uint no, uint incomplete);

    event VotingExecuted(uint indexed milestoneIndex, VoteOutcome outcome);

    constructor(
        address _linkToken,
        address _oracle,
        bytes32 _jobIdCreate,
        bytes32 _jobIdResult,
        uint256 _fee
    )
        ConfirmedOwner(msg.sender)
    {
        // ChainlinkClient
        setChainlinkToken(_linkToken);

        // set config
        oracleAddress = _oracle;
        jobIdCreate = _jobIdCreate;
        jobIdResult = _jobIdResult;
        fee = _fee;
    }

    /**
     * @dev 設置新的 oracle or jobid
     */
    function setOracleJob(
        address _oracle, 
        bytes32 _createId, 
        bytes32 _resultId, 
        uint256 _newFee
    ) external onlyOwner {
        oracleAddress = _oracle;
        jobIdCreate = _createId;
        jobIdResult = _resultId;
        fee = _newFee;
    }

    /**
     * @dev 初始化某個里程碑
     */
    function initMilestone(
        uint index,
        string calldata ipfsHash,
        uint startTime,
        uint endTime
    ) external onlyOwner {
        Milestone storage m = milestones[index];
        require(m.status == MilestoneStatus.NotStarted && m.proposalId == bytes32(0), "Already init? or used?");
        m.ipfsHash = ipfsHash;
        m.startTime = startTime;
        m.endTime   = endTime;
        m.status    = MilestoneStatus.NotStarted;
        m.outcome   = VoteOutcome.Undecided;
        m.executed  = false;
        if (index >= totalMilestones) {
            totalMilestones = index + 1;
        }
        emit MilestoneCreated(index, ipfsHash, startTime, endTime);
    }

    // --------------- KeeperCompatible ---------------
    /**
     * @dev Keeper nodes週期呼叫 => 檢查是否需要 "CREATE" or "FINALIZE"
     */
    function checkUpkeep(bytes calldata /* checkData */) external view override 
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // 從 0 ~ totalMilestones 找
        for (uint i = 0; i < totalMilestones; i++){
            Milestone memory m = milestones[i];
            if (m.status == MilestoneStatus.NotStarted && block.timestamp >= m.startTime){
                // need CREATE
                return (true, abi.encode(i, "CREATE"));
            }
            if (m.status == MilestoneStatus.VotingOpen && block.timestamp >= m.endTime){
                // need FINALIZE
                return (true, abi.encode(i, "FINALIZE"));
            }
        }
        return (false, bytes(""));
    }

    /**
     * @dev Keeper nodes若 checkUpkeep =true => 呼叫 performUpkeep(performData)
     *   - decode (index, action)
     *   - action="CREATE" => requestCreateProposal
     *   - action="FINALIZE" => requestGetProposalResult
     */
    function performUpkeep(bytes calldata performData) external override {
        (uint index, string memory action) = abi.decode(performData, (uint, string));
        emit UpkeepAction(index, action);

        Milestone storage m = milestones[index];
        if ( keccak256(bytes(action)) == keccak256("CREATE") ){
            // create
            require(m.status == MilestoneStatus.NotStarted, "Invalid status for CREATE");
            requestCreateProposal(index);
        }
        else if ( keccak256(bytes(action)) == keccak256("FINALIZE") ){
            require(m.status == MilestoneStatus.VotingOpen, "Invalid status for FINALIZE");
            requestGetProposalResult(index);
        }
    }

    // --------------- Any-API: create snapshot proposal ---------------
    /**
     * @dev 構建Chainlink.Request => 交由 Node => Node對Snapshot API => create proposal => callback fulfill
     */
    function requestCreateProposal(uint milestoneIndex) internal {
        Milestone storage m = milestones[milestoneIndex];
        // update status
        m.status = MilestoneStatus.VotingOpen;

        Chainlink.Request memory req = buildChainlinkRequest(jobIdCreate, address(this), this.fulfillCreateProposal.selector);
        // 你想傳遞到 external adapter 的資料:
        req.addUint("milestoneIndex", milestoneIndex);
        req.add("ipfsHash", m.ipfsHash);

        // 三選: 你可以用 adapter 內固定 or req.add("options","[YES,NO,INCOMPLETE]") etc

        bytes32 requestId = sendChainlinkRequestTo(oracleAddress, req, fee);
        emit RequestCreateProposalSent(requestId, milestoneIndex);
    }

    /**
     * @dev callback: Node adapter會把 proposalId傳回
     */
    function fulfillCreateProposal(bytes32 _requestId, uint256 milestoneIdx, bytes32 _proposalId)
        public
        recordChainlinkFulfillment(_requestId)
    {
        Milestone storage m = milestones[milestoneIdx];
        require(m.status == MilestoneStatus.VotingOpen, "Not in VotingOpen?");

        m.proposalId = _proposalId;
        // 事件
        emit FulfillCreateProposal(_requestId, milestoneIdx, _proposalId);
    }

    // --------------- Any-API: get snapshot result ---------------
    /**
     * @dev 取得投票結果 => yes/no/incomplete
     */
    function requestGetProposalResult(uint milestoneIndex) internal {
        Milestone storage m = milestones[milestoneIndex];
        require(m.proposalId != bytes32(0), "No proposalId");
        require(m.status == MilestoneStatus.VotingOpen && !m.executed, "Already done or invalid status");

        Chainlink.Request memory req = buildChainlinkRequest(jobIdResult, address(this), this.fulfillGetProposalResult.selector);
        req.addUint("milestoneIndex", milestoneIndex);
        // adapter可用 proposalId找出投票 => yes/no/incomplete
        req.addBytes32("proposalId", m.proposalId);

        bytes32 requestId = sendChainlinkRequestTo(oracleAddress, req, fee);
        emit RequestGetResultSent(requestId, milestoneIndex);
    }

    /**
     * @dev callback: Node adapter會回傳 (yesCount, noCount, incompleteCount)
     */
    function fulfillGetProposalResult(
        bytes32 _requestId,
        uint256 milestoneIdx,
        uint256 yesCount,
        uint256 noCount,
        uint256 incompleteCount
    )
        public
        recordChainlinkFulfillment(_requestId)
    {
        Milestone storage m = milestones[milestoneIdx];
        require(m.status == MilestoneStatus.VotingOpen && !m.executed, "Cannot finalize again");

        emit FulfillGetProposalResult(_requestId, milestoneIdx, yesCount, noCount, incompleteCount);

        // 決定 outcome
        VoteOutcome outcome;
        if (yesCount >= noCount && yesCount >= incompleteCount){
            outcome = VoteOutcome.Yes;
        } else if (noCount >= yesCount && noCount >= incompleteCount){
            outcome = VoteOutcome.No;
        } else {
            outcome = VoteOutcome.Incomplete;
        }

        m.outcome = outcome;
        m.status = MilestoneStatus.VotingEnded;
        m.executed = true;

        // 進行後續動作
        _executeVotingOutcome(milestoneIdx, outcome);
    }

    /**
     * @dev 依投票結果(Yes/No/Incomplete)執行
     */
    function _executeVotingOutcome(uint milestoneIdx, VoteOutcome outcome) internal {
        // e.g. if yes => 釋放funds, if no => refund or kill project, if incomplete => require re-report
        // 這裡示範:
        if (outcome == VoteOutcome.Yes) {
            // ex: releaseFundsToOwner( ... )
        }
        else if (outcome == VoteOutcome.No) {
            // ex: revertProject( ... ), refunds
        }
        else {
            // incomplete => maybe let user re-report or extension
        }
        emit VotingExecuted(milestoneIdx, outcome);
    }

    // ========== 其他: withdraw link, etc ==========

    /**
     * @dev 預防LINK不足or要回收
     */
    function withdrawLink() external onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer LINK");
    }
}


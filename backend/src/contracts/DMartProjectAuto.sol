// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

/**
 * DMartProjectAuto
 * 依賴 Chainlink 進行:
 *   - KeeperCompatibleInterface => checkUpkeep/performUpkeep (自動偵測 CREATE / FINALIZE)
 *   - ChainlinkClient => sendChainlinkRequestTo + recordChainlinkFulfillment (Any-API)
 *
 * 假設:
 *   - 每個里程碑都需要發起投票，投票通過後才釋放該里程碑對應的款項
 *   - 最後里程碑釋放時會連同保證金一併退還給募資人 (邏輯已在 DMartProject 中實作)
 */

interface IDMartProject {
    function currentMilestone() external view returns (uint256);
    function submitMilestoneReport(uint256 milestoneIndex, string calldata cid) external;
    function releaseMilestoneFunds(uint256 milestoneIndex) external;
}

contract DMartProjectAuto is ChainlinkClient, KeeperCompatibleInterface, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    enum VoteOutcome { Undecided, Yes, No }

    enum MilestoneAutoStatus { Idle, VotingOpen, VotingEnded }

    struct MilestoneAuto {
        MilestoneAutoStatus status;
        bytes32 proposalId; // snapshot proposalId
        VoteOutcome outcome;
        bool executed;      // 是否已針對結果執行(撥款或不撥款)
    }

    // 這裡假設每個專案固定 4 個里程碑 => [0,1,2,3]
    mapping(uint256 => MilestoneAuto) public milestoneAutos;

    // 針對此合約需要的 Chainlink Any-API 參數
    address public oracle;
    bytes32 public jobIdCreate;       // create proposal
    bytes32 public jobIdResult;       // get proposal result
    uint256 public fee;

    // 綁定 DMartProject
    IDMartProject public project;

    // events
    event UpkeepAction(uint indexed milestoneIndex, string action);
    event RequestCreateProposalSent(uint256 indexed milestoneIndex, bytes32 indexed requestId);
    event RequestGetResultSent(uint256 indexed milestoneIndex, bytes32 indexed requestId);

    constructor(
        address _project,
        address _linkToken,
        address _oracle,
        bytes32 _jobIdCreate,
        bytes32 _jobIdResult,
        uint256 _fee
    ) ConfirmedOwner(msg.sender) {
        // Chainlink Client
        setChainlinkToken(_linkToken);

        project = IDMartProject(_project);
        oracle = _oracle;
        jobIdCreate = _jobIdCreate;
        jobIdResult = _jobIdResult;
        fee = _fee;
    }

    // ============== KeeperCompatibleInterface ==============
    /**
     * checkUpkeep:
     *   1) 如果 status = Idle => CREATE
     *   2) 如果 status = VotingOpen => FINALIZE
     *
     * 真實情況應加入更多時間/條件判斷，此處簡化
     */
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        uint256 mIndex = project.currentMilestone();
        MilestoneAuto memory ma = milestoneAutos[mIndex];

        // 若是 Idle => 表示該里程碑可發起投票
        if (ma.status == MilestoneAutoStatus.Idle) {
            upkeepNeeded = true;
            performData = abi.encode(mIndex, "CREATE");
            return (upkeepNeeded, performData);
        }

        // 若是 VotingOpen => 表示該里程碑可結算投票
        if (ma.status == MilestoneAutoStatus.VotingOpen) {
            upkeepNeeded = true;
            performData = abi.encode(mIndex, "FINALIZE");
            return (upkeepNeeded, performData);
        }

        return (false, bytes(""));
    }

    function performUpkeep(bytes calldata performData) external override {
        (uint256 milestoneIndex, string memory action) = abi.decode(performData, (uint256, string));
        emit UpkeepAction(milestoneIndex, action);

        if (keccak256(bytes(action)) == keccak256("CREATE")) {
            requestCreateProposal(milestoneIndex);
        } else if (keccak256(bytes(action)) == keccak256("FINALIZE")) {
            requestGetProposalResult(milestoneIndex);
        }
    }

    // ============== Chainlink Any-API: create proposal  ==============
    function requestCreateProposal(uint256 mIndex) internal {
        MilestoneAuto storage ma = milestoneAutos[mIndex];
        require(ma.status == MilestoneAutoStatus.Idle, "Wrong status");
        ma.status = MilestoneAutoStatus.VotingOpen;
        ma.outcome = VoteOutcome.Undecided;

        Chainlink.Request memory req = buildChainlinkRequest(
            jobIdCreate, 
            address(this), 
            this.fulfillCreateProposal.selector
        );

        // 傳遞參數給 External Adapter
        req.addUint("milestoneIndex", mIndex);
        // ... 其他需要的資料 (如 IPFS CID, 里程碑描述, etc)

        bytes32 requestId = sendChainlinkRequestTo(oracle, req, fee);
        emit RequestCreateProposalSent(mIndex, requestId);
    }

    // callback
    function fulfillCreateProposal(bytes32 _requestId, uint256 milestoneIdx, bytes32 proposalId)
        public
        recordChainlinkFulfillment(_requestId)
    {
        MilestoneAuto storage ma = milestoneAutos[milestoneIdx];
        require(ma.status == MilestoneAutoStatus.VotingOpen, "Not in VotingOpen");
        ma.proposalId = proposalId;
        // 其他邏輯
    }

    // ============== Chainlink Any-API: get proposal result  ==============
    function requestGetProposalResult(uint256 mIndex) internal {
        MilestoneAuto storage ma = milestoneAutos[mIndex];
        require(ma.status == MilestoneAutoStatus.VotingOpen, "Wrong status");
        require(ma.proposalId != bytes32(0), "No proposalId");

        Chainlink.Request memory req = buildChainlinkRequest(
            jobIdResult,
            address(this),
            this.fulfillGetProposalResult.selector
        );

        req.addUint("milestoneIndex", mIndex);
        req.addBytes32("proposalId", ma.proposalId);

        bytes32 requestId = sendChainlinkRequestTo(oracle, req, fee);
        emit RequestGetResultSent(mIndex, requestId);
    }

    // callback: Node adapter 會回傳 yes/no 投票數
    function fulfillGetProposalResult(
        bytes32 _requestId,
        uint256 milestoneIdx,
        uint256 yesCount,
        uint256 noCount
    ) public recordChainlinkFulfillment(_requestId) {
        MilestoneAuto storage ma = milestoneAutos[milestoneIdx];
        require(ma.status == MilestoneAutoStatus.VotingOpen, "Not in VotingOpen");

        // 判定結果
        if (yesCount >= noCount) {
            ma.outcome = VoteOutcome.Yes;
        } else {
            ma.outcome = VoteOutcome.No;
        }

        ma.status = MilestoneAutoStatus.VotingEnded;
        ma.executed = false; // 等待後續執行
        // 執行後續動作
        _executeVotingOutcome(milestoneIdx);
    }

    function _executeVotingOutcome(uint256 milestoneIdx) internal {
        MilestoneAuto storage ma = milestoneAutos[milestoneIdx];
        require(ma.status == MilestoneAutoStatus.VotingEnded, "Not ended yet");
        require(!ma.executed, "Already executed");
        ma.executed = true;

        if (ma.outcome == VoteOutcome.Yes) {
            // 呼叫 DMartProject 釋放資金 (此時若是最後里程碑，順便退還保證金)
            project.releaseMilestoneFunds(milestoneIdx);
        } else {
            // 可能代表投票否決 => 不撥款
            // (可在此擴充：終止專案、或允許重新提案等)
        }
    }

    // ============== Owner設定/提領LINK 等 ==============
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
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer LINK");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IAavePool.sol";

/**
 * DMartProject 代表單一募資專案
 * - 募資人需先繳交 30% 保證金 (不計入 target 內)
 * - 實際向投資人募資 100% (target)
 * - 有四個里程碑 (A, B, C, D)，每個通過投票後釋放 1/4 target 給募資人
 * - 最後一個里程碑完成時將保證金退還給募資人
 * - 閒置資金都會存到 Aave 賺取利息
 * - 透過 DMartProjectAuto 進行投票與自動化
 */
contract DMartProject {
    // 里程碑編號
    enum MilestoneStatus { NotStarted, InProgress, Completed }

    // 為簡化：里程碑 0 => A, 1 => B, 2 => C, 3 => D
    struct Milestone {
        MilestoneStatus status;  
        string ipfsCid;         // 募資人上傳報告之 IPFS CID
    }

    address public factory;   // 部署本合約的 factory
    address public creator;   // 募資專案的發起人
    address public usdt;      // 直接使用 USDT 進行交易與存 Aave
    address public aavePool;  // Aave Pool
    address public aToken;    // Aave 中對應的 aToken
    address public platform;  // 平台地址(可收利息分潤)

    uint256 public target;           // 專案目標金額 (投資人需募資的 100%)
    uint256 public collateral;       // 保證金(30% 的 target)，由募資人額外支付
    uint256 public totalRaised;      // 已募集的金額(來自投資人)
    uint256 public stakedInAave;     // 存入 Aave 的本金

    uint256 public currentMilestone; // 當前里程碑索引 (0~3)
    Milestone[4] public milestones;  // 四個里程碑

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "Locked.");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // 事件
    event ProjectInitialized(address indexed creator, uint256 target, uint256 collateral);
    event MilestoneReportSubmitted(uint256 indexed milestoneIndex, string ipfsCid);
    event MilestoneFundsReleased(uint256 indexed milestoneIndex, uint256 amount);
    event NextMilestoneActivated(uint256 indexed milestoneIndex);

    constructor() {
        factory = msg.sender; // factory 部署
    }

    /**
     * 初始化專案：
     * - 傳入 target (需要從投資人募資的金額)，
     * - 募資人需額外提供 30% 的 target 作為保證金
     * - 並設定 Aave / USDT / aToken / platform 等參數
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

        creator   = _creator;
        usdt      = _usdt;
        aavePool  = _aavePool;
        aToken    = _aToken;
        platform  = _platform;
        target    = _target;

        // 募資人需繳交 30% (保證金)
        uint256 _collateral = (_target * 30) / 100;
        collateral = _collateral;

        // 先從募資人那裡把保證金轉進合約
        require(IERC20(usdt).balanceOf(creator) >= collateral, "Not enough balance for collateral");
        IERC20(usdt).transferFrom(creator, address(this), collateral);

        // 全部保證金存入 Aave
        depositToAave(collateral);

        // 預設：里程碑 A (index=0) 進入進行中
        milestones[0].status = MilestoneStatus.InProgress;
        currentMilestone = 0;

        emit ProjectInitialized(creator, target, collateral);
    }

    /**
     * 投資人捐款 (donate)，上限為 target (100%)
     */
    function donate(uint256 amount) external lock {
        // 不可超過 target
        require(totalRaised + amount <= target, "Exceed the max target");
        require(IERC20(usdt).balanceOf(msg.sender) >= amount, "Donator has not enough balance");

        // 轉入合約
        IERC20(usdt).transferFrom(msg.sender, address(this), amount);

        // 增加 totalRaised
        totalRaised += amount;

        // 轉入 Aave 賺利息
        depositToAave(amount);
    }

    /**
     * 募資人上傳里程碑報告(CID)，供後續 Chainlink Auto 監測並進行投票
     */
    function submitMilestoneReport(uint256 milestoneIndex, string calldata cid) external {
        require(msg.sender == creator, "Only creator can submit");
        require(milestoneIndex == currentMilestone, "Not the current milestone");
        require(milestones[milestoneIndex].status == MilestoneStatus.InProgress, "Not in progress");

        milestones[milestoneIndex].ipfsCid = cid;
        emit MilestoneReportSubmitted(milestoneIndex, cid);
    }

    /**
     * 由 DMartProjectAuto 在投票結果 Yes 後呼叫，釋放對應里程碑款項
     * 每個里程碑對應 1/4 的 target
     * 若是最後里程碑(3)，另加退還保證金給募資人
     */
    function releaseMilestoneFunds(uint256 milestoneIndex) external lock {
        require(msg.sender != address(0), "Invalid caller");
        require(milestoneIndex == currentMilestone, "Not the current milestone");
        require(milestones[milestoneIndex].status == MilestoneStatus.InProgress, "Not in progress");

        // 計算要釋放的金額 = target / 4
        uint256 amountToRelease = target / 4;

        // 如果是最後一個里程碑，額外退還保證金
        if (milestoneIndex == 3) {
            amountToRelease += collateral;
        }

        // 從 Aave 提款 (原則上合約目前有足夠金額)
        (uint256 actualPrincipal, , ) = withdrawFromAave(amountToRelease);

        // 撥款給募資人
        IERC20(usdt).transfer(creator, actualPrincipal);

        // 更新里程碑狀態
        milestones[milestoneIndex].status = MilestoneStatus.Completed;
        emit MilestoneFundsReleased(milestoneIndex, actualPrincipal);

        // 若不是最後一個里程碑，進入下一階段
        if (milestoneIndex < 3) {
            currentMilestone = milestoneIndex + 1;
            milestones[currentMilestone].status = MilestoneStatus.InProgress;
            emit NextMilestoneActivated(currentMilestone);
        }
    }

    // === Aave 存款 & 提款邏輯 ===
    function depositToAave(uint256 amount) internal {
        require(aavePool != address(0), "Aave config not set");
        uint256 balance = IERC20(usdt).balanceOf(address(this));
        require(balance >= amount, "Not enough to deposit to Aave");

        IERC20(usdt).approve(aavePool, amount);
        IAavePool(aavePool).supply(usdt, amount, address(this), 0);

        stakedInAave += amount;
    }

    // 從 Aave 依比例提領
    function withdrawFromAave(uint256 principal)
        internal
        returns (uint256 actualPrincipal, uint256 userInterest, uint256 platformInterest)
    {
        require(aavePool != address(0), "Aave config not set");
        require(principal > 0, "Principal must > 0");
        require(principal <= stakedInAave, "Not enough staked principal");

        // 先計算合約目前可贖回多少 aToken
        uint256 totalRedeemable = IERC20(aToken).balanceOf(address(this));
        // 以 (principal / stakedInAave) 算出比例
        uint256 ratio = (principal * 1e18) / stakedInAave;
        uint256 toWithdraw = (totalRedeemable * ratio) / 1e18;

        uint256 actualReceived = IAavePool(aavePool).withdraw(usdt, toWithdraw, address(this));

        if (actualReceived > principal) {
            uint256 interest = actualReceived - principal;
            platformInterest = interest / 2; // 平台收一半利息
            userInterest = interest - platformInterest;
            actualPrincipal = principal;

            // 分利息(此處以募資人為使用者)
            if (userInterest > 0) {
                IERC20(usdt).transfer(creator, userInterest);
            }
            if (platformInterest > 0 && platform != address(0)) {
                IERC20(usdt).transfer(platform, platformInterest);
            }
        } else {
            // 沒有利息
            actualPrincipal = actualReceived;
            userInterest = 0;
            platformInterest = 0;
        }

        // 更新合約內的本金記錄
        stakedInAave -= principal;

        return (actualPrincipal, userInterest, platformInterest);
    }

    // 輔助查詢
    function getMilestone(uint256 index)
        external
        view
        returns (MilestoneStatus status, string memory cid)
    {
        Milestone memory m = milestones[index];
        return (m.status, m.ipfsCid);
    }
}

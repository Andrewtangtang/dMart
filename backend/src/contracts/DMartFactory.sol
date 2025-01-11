// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// 引入必要的合約和介面
import "./DMartERC721.sol";
import "./DMartProject.sol";
import "./DMartProjectAuto.sol";

/**
 * @title DMartFactory
 * @dev 部署並管理所有 DMartProject 實例。
 *      管理集中化的 NFT 合約和自動化合約。
 *      促進專案創建、NFT 鑄造，並處理與專案相關的事件。
 */
contract DMartFactory {
    address public constant USDT      = 0xdcdc73413c6136c9abcc3e8d250af42947ac2fc7;
    address public constant AAVE_POOL = 0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951;
    address public constant A_TOKEN   = 0xAF0F6e8b0Dc5c913bbF4d14c22B4E78Dd14310B6;
    address public constant PLATFORM  = 0x44Ee82519bC19195289e836Bb97B0238CB2f0A58;
    
    // Factory 合約擁有者（部署者）的地址
    address public owner;

    // 集中化的 NFT 合約實例
    DMartERC721 public nftContract;

    // 負責處理投票和資金管理的自動化合約實例
    DMartProjectAuto public autoContract;

    // 將專案創建者地址映射到他們部署的專案地址陣列
    mapping(address => address[]) public getProjectsByCreator;

    // 所有部署的專案地址陣列
    address[] public allProjects;

    // 用於快速驗證地址是否為已部署的專案
    mapping(address => bool) public projectExists;

    // 預定義的募資期間選項映射（例如，1 => 30 天，2 => 60 天，等等）
    mapping(uint8 => uint256) public durationOptions;

    // 專案地址到其募資截止時間戳的映射
    mapping(address => uint256) public projectDeadlines;

    /**
     * @dev 當新的專案被創建時觸發。
     * @param projectAddress 新部署的 DMartProject 合約地址。
     * @param creator 專案創建者的地址。
     * @param target 募資目標金額。
     * @param durationChoice 選擇的募資期間選項。
     * @param deadline 募資截止時間戳。
     */
    event ProjectCreated(address indexed projectAddress, address indexed creator, uint256 target, uint8 durationChoice, uint256 deadline);

    /**
     * @dev 當自動化合約被設定或更新時觸發。
     * @param autoContract 自動化合約的地址。
     */
    event AutoContractSet(address indexed autoContract);

    /**
     * @dev 當 NFT 被鑄造給投資者時觸發。
     * @param to 接收 NFT 的地址。
     * @param tokenId 被鑄造 NFT 的 ID。
     * @param projectId NFT 所屬的專案 ID。
     * @param weight NFT 的投票權重。
     */
    event NFTMinted(address indexed to, uint256 indexed tokenId, uint256 projectId, uint256 weight);

    /**
     * @dev 當自動化合約處理事件時觸發。
     * @param milestoneIndex 被處理的里程碑索引。
     * @param outcome 事件的結果（例如，投票結果）。
     */
    event AutoEventHandled(uint256 indexed milestoneIndex, uint8 outcome);

    // 自訂錯誤以節省 Gas 成本
    error NotOwner();
    error InvalidDurationChoice();
    error NotProject();
    error NotAutoContract();
    error InvalidAutoContractAddress();

    /**
     * @dev 構造函數，初始化 Factory，部署 NFT 合約，並設定預設的募資期間選項。
     *      部署者成為 Factory 的擁有者。
     */
    constructor() {
        owner = msg.sender; // 設定部署者為擁有者

        // 部署集中化的 NFT 合約，名稱為 "DMartNFT" ，符號為 "DMART"
        nftContract = new DMartERC721("DMartNFT", "DMART");

        // 將 NFT 合約的擁有權轉移給 Factory 合約
        nftContract.transferOwnership(address(this));

        // 初始化預設的募資期間選項
        durationOptions[1] = 30 days;
        durationOptions[2] = 60 days;
        durationOptions[3] = 90 days;
    }

    /**
     * @dev 限制函式訪問僅限 Factory 擁有者。
     *      如果呼叫者不是擁有者，則以 `NotOwner` 錯誤回滾。
     */
    modifier onlyOwnerFunc() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /**
     * @dev 限制函式訪問僅限已部署的 DMartProject 合約。
     *      如果呼叫者不是已認證的專案，則以 `NotProject` 錯誤回滾。
     */
    modifier onlyProject() {
        if (!isProject(msg.sender)) revert NotProject();
        _;
    }

    /**
     * @dev 限制函式訪問僅限自動化合約。
     *      如果呼叫者不是自動化合約，則以 `NotAutoContract` 錯誤回滾。
     */
    modifier onlyAuto() {
        if (address(autoContract) == address(0) || msg.sender != address(autoContract)) {
            revert NotAutoContract();
        }
        _;
    }

    /**
     * @dev 設定或更新自動化合約地址。
     *      僅限 Factory 擁有者調用。
     * @param _auto 新的自動化合約地址。
     */
    function setAutoContract(address _auto) external onlyOwnerFunc {
        require(_auto != address(0), "Invalid auto contract");
        autoContract = DMartProjectAuto(_auto);
        emit AutoContractSet(_auto);
    }

    /**
     * @dev 添加或更新募資期間選項。
     *      僅限 Factory 擁有者調用。
     * @param index 募資期間選項的識別碼（例如，1、2、3）。
     * @param secondsValue 對應選項的秒數。
     */
    function setDurationOption(uint8 index, uint256 secondsValue) external onlyOwnerFunc {
        require(index >= 1 && index <= 3, "Invalid duration index");
        durationOptions[index] = secondsValue;
    }

    /**
     * @dev 部署新的 DMartProject 合約並使用提供的參數進行初始化。
     *      僅限 Factory 擁有者調用。
     * @param creator 專案創建者的地址。
     * @param platform 平台的地址，用於接收費用或利息。
     * @param target 募資目標金額（以 USDT 計）。
     * @param durationChoice 選擇的募資期間選項（1、2 或 3）。
     * @param defaultUSDT USDT 代幣合約地址。
     * @param defaultAavePool Aave Pool 合約地址。
     * @param defaultAToken 對應的 Aave aToken 地址。
     * @param title 專案的標題。
     * @param image 專案的圖片 URL 或 IPFS CID。
     * @return projectAddress 新部署的 DMartProject 合約地址。
     */
    function createProject(
        address creator,
        address platform,
        uint256 target,
        uint8 durationChoice,
        address defaultUSDT,
        address defaultAavePool,
        address defaultAToken,
        string memory title,
        string memory image
    ) external onlyOwnerFunc returns (address projectAddress) {
        uint256 dur = durationOptions[durationChoice]; // 獲取募資期間（以秒計）
        if (dur == 0) revert InvalidDurationChoice(); // 確保選擇的募資期間有效

        // 部署新的 DMartProject 合約
        DMartProject p = new DMartProject();
        projectAddress = address(p); // 獲取部署的專案地址

        // 使用提供的參數初始化專案
        p.initialize(
            creator,
            USDT,
            AAVE_POOL,
            A_TOKEN,
            PLATFORM,
            target,
            title,
            image
        );

        // 記錄專案詳細資訊
        allProjects.push(projectAddress); // 添加到所有專案列表
        getProjectsByCreator[creator].push(projectAddress); // 將專案與創建者關聯
        projectExists[projectAddress] = true; // 標記為已認證的專案

        // 設定募資截止時間
        projectDeadlines[projectAddress] = block.timestamp + dur;

        emit ProjectCreated(projectAddress, creator, target, durationChoice, projectDeadlines[projectAddress]);
        return projectAddress;
    }

    /**
     * @dev 為特定專案鑄造 NFT 給投資者。
     *      僅限已認證的 DMartProject 合約調用。
     * @param to 接收 NFT 的地址。
     * @param projectId NFT 所屬的專案 ID。
     * @param weight NFT 的投票權重。
     * @return tokenId 被鑄造 NFT 的 ID。
     */
    function mintNFT(address to, uint256 projectId, uint256 weight) external onlyProject returns (uint256 tokenId) {
        nftContract.mint(to, projectId, weight); // 透過 NFT 合約鑄造 NFT
        tokenId = nftContract.totalSupply(); // 獲取新的 Token ID
        emit NFTMinted(to, tokenId, projectId, weight); // 觸發 NFT 鑄造事件
        return tokenId;
    }

    /**
     * @dev 處理自動化合約觸發的事件。
     *      目前僅觸發事件以記錄里程碑結果，未來可擴展更複雜的互動。
     *      僅限自動化合約調用。
     * @param milestoneIndex 被處理的里程碑索引。
     * @param outcome 事件的結果（例如，投票結果）。
     */
    function onAutoEvent(uint256 milestoneIndex, uint8 outcome) external onlyAuto {
        emit AutoEventHandled(milestoneIndex, outcome);
    }

    /**
     * @dev 檢查給定地址是否為已部署的 DMartProject。
     * @param addr 要驗證的地址。
     * @return 如果地址是已認證的 DMartProject，則返回 true，否則返回 false。
     */
    function isProject(address addr) public view returns (bool) {
        return projectExists[addr];
    }

    /**
     * @dev 獲取已部署專案的總數。
     * @return 已部署的 DMartProject 合約數量。
     */
    function allProjectsLength() external view returns (uint256) {
        return allProjects.length;
    }

    /**
     * @dev 獲取特定創建者所有專案的地址。
     * @param creator 專案創建者的地址。
     * @return 由該創建者創建的專案地址陣列。
     */
    function getProjects(address creator) external view returns (address[] memory) {
        return getProjectsByCreator[creator];
    }

    /**
     * @dev 檢查專案是否已到期並且未達到募資目標，若符合則觸發退款。
     *      允許外部實體調用以檢查和執行退款。
     * @param projectAddr 要檢查的專案地址。
     */
    function checkProjectExpiredAndRefund(address projectAddr) external {
        require(projectExists[projectAddr], "Not a project"); // 確保地址為已認證的專案
        require(block.timestamp > projectDeadlines[projectAddr], "Not expired yet"); // 確保截止時間已過

        DMartProject p = DMartProject(projectAddr); // 與 DMartProject 合約介面互動

        if (p.totalRaised() < p.target()) {
            p.refundAllInvestors(); // 如果募資目標未達，觸發退款
        }
    }
}


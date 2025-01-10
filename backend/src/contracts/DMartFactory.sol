// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./DMartERC721.sol";
import "./DMartProject.sol";
import "./DMartProjectAuto.sol";

contract DMartFactory {
    // ========== State Variables ==========
    address public owner;

    // NFT 合約（由本 Factory 部署並擁有）
    DMartERC721 public nftContract;

    // 自動化合約（可為共享或單獨部署）
    DMartProjectAuto public autoContract;

    // 每個創建者對應的專案列表
    mapping(address => address[]) public getProjectsByCreator;

    // 專案清單
    address[] public allProjects;

    // 募資期限對應秒數 (1 => 30天, 2 => 60天, 3 => 90天)
    mapping(uint8 => uint256) public durationOptions;

    // 紀錄專案的「截止時間」
    mapping(address => uint256) public projectDeadlines;

    // 紀錄專案是否存在
    mapping(address => bool) public projectExists;

    // ========== Events ==========
    event ProjectCreated(
        address indexed projectAddress,
        address indexed creator,
        uint256 target,
        uint8 durationChoice,
        uint256 deadline
    );

    event AutoContractSet(address indexed autoContract);

    event NFTMinted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 projectId,
        uint256 weight
    );

    event AutoEventHandled(uint256 indexed milestoneIndex, uint8 outcome);

    // ========== Errors ==========
    error NotOwner();
    error InvalidDurationChoice();
    error NotProject();
    error NotAutoContract();
    error InvalidAutoContractAddress();

    // ========== Constructor ==========
    constructor() {
        owner = msg.sender;

        // 部署中央 NFT 合約，由本 Factory 擁有
        nftContract = new DMartERC721("DMartNFT", "DMART");
        // 將 NFT 合約的擁有權轉移給 Factory
        nftContract.transferOwnership(address(this));

        // 設定預設的募資期限選項
        durationOptions[1] = 30 days;
        durationOptions[2] = 60 days;
        durationOptions[3] = 90 days;
    }

    // ========== Modifiers ==========
    modifier onlyOwnerFunc() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    // 驗證是否為已建立之 Project
    modifier onlyProject() {
        if (!isProject(msg.sender)) {
            revert NotProject();
        }
        _;
    }

    // 驗證是否為已設定的 Auto contract
    modifier onlyAuto() {
        if (address(autoContract) == address(0) || msg.sender != address(autoContract)) {
            revert NotAutoContract();
        }
        _;
    }

    // ========== External / Public Functions ==========

    /**
     * @dev 由 owner (平台) 設置/更新 DMartProjectAuto 合約地址
     */
    function setAutoContract(address _autoContract) external onlyOwnerFunc {
        require(_autoContract != address(0), "Invalid auto contract address");
        autoContract = DMartProjectAuto(_autoContract);
        emit AutoContractSet(_autoContract);
    }

    /**
     * @dev 新增或修改募資期限選項 (例如: 1 => 30天, 2 => 60天, 3 => 90天)
     */
    function setDurationOption(uint8 index, uint256 secondsValue) external onlyOwnerFunc {
        require(index >=1 && index <=3, "Invalid duration index");
        durationOptions[index] = secondsValue;
    }

    /**
     * @dev 建立一個新的 Project
     * @param creator 發起人
     * @param usdt  USDT 地址
     * @param aavePool Aave Pool
     * @param aToken Aave 對應的 aToken
     * @param platform 平台地址
     * @param target 募資目標金額(100%)
     * @param durationChoice 募資期限選項 (1=>30天, 2=>60天, 3=>90天)
     */
    function createProject(
        address creator,
        address usdt,
        address aavePool,
        address aToken,
        address platform,
        uint256 target,
        uint8 durationChoice
    ) external onlyOwnerFunc returns (address projectAddress) {
        // 檢查 durationChoice 是否有效
        uint256 dur = durationOptions[durationChoice];
        if (dur == 0) {
            revert InvalidDurationChoice();
        }

        // 1. 部署 DMartProject
        DMartProject project = new DMartProject();
        projectAddress = address(project);

        // 2. 初始化
        project.initialize(
            creator,
            usdt,
            aavePool,
            aToken,
            platform,
            target
        );

        // 3. 紀錄 & push
        allProjects.push(projectAddress);
        getProjectsByCreator[creator].push(projectAddress);
        projectExists[projectAddress] = true;
        nounces[creator]++;
        
        // 4. 設定專案 deadline
        projectDeadlines[projectAddress] = block.timestamp + dur;

        emit ProjectCreated(projectAddress, creator, target, durationChoice, projectDeadlines[projectAddress]);
    }

    /**
     * @notice 由 Project 合約呼叫，用於「投資人捐贈後」鑄造 NFT
     * @param to 投資人地址
     * @param projectId projectId 可以用 Project 合約地址或內部定義 ID
     * @param weight 投票權重
     */
    function mintNFT(
        address to,
        uint256 projectId,
        uint256 weight
    ) external onlyProject returns (uint256 tokenId) {
        // 由 Factory(擁有 NFT) 幫忙 mint
        nftContract.mint(to, projectId, weight);

        tokenId = nftContract.totalSupply(); // 剛好就是最新鑄造的 Token ID
        emit NFTMinted(to, tokenId, projectId, weight);
        return tokenId;
    }

    /**
     * @notice 由 Auto Contract 呼叫，通知 Factory 某些事件
     * @param milestoneIndex 里程碑索引
     * @param outcome 投票結果（1 => Yes, 2 => No）
     */
    function onAutoEvent(uint256 milestoneIndex, uint8 outcome) external onlyAuto {
        // 根據 outcome 處理不同邏輯
        if (outcome == 1) {
            // 投票通過，觸發資金釋放
            address projectAddress = allProjects[milestoneIndex];
            DMartProject(projectAddress).releaseMilestoneFunds(milestoneIndex);
        } else if (outcome == 2) {
            // 投票未通過，處理相應邏輯（如終止專案）
        }

        // 紀錄事件
        emit AutoEventHandled(milestoneIndex, outcome);
    }

    // ========== Helper / View Functions ==========

    /**
     * @dev 檢查某地址是否為已創建的 Project
     */
    function isProject(address _addr) public view returns (bool) {
        return projectExists[_addr];
    }

    /**
     * @dev 回傳所有專案數量
     */
    function allProjectsLength() external view returns (uint256) {
        return allProjects.length;
    }

    /**
     * @dev 回傳某創建者所擁有的專案列表
     */
    function getProjects(address creator) external view returns (address[] memory) {
        return getProjectsByCreator[creator];
    }
}


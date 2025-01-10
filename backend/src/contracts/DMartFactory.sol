// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// 引入其他合約的接口
import "./DMartERC721.sol";
import "./DMartProject.sol";
import "./DMartProjectAuto.sol";

/**
 * @title DMartFactory
 * @dev 部署並管理所有 DMartProject 專案，管理 NFT 合約及自動化合約。
 */
contract DMartFactory {
    // ========== 狀態變數 ==========
    address public owner;                    // Factory 擁有者（平台管理者）
    DMartERC721 public nftContract;          // 中央化的 NFT 合約，由 Factory 部署並擁有
    DMartProjectAuto public autoContract;    // 自動化合約，用於處理投票與資金釋放

    // 每個創建者對應的專案列表
    mapping(address => address[]) public getProjectsByCreator;
    address[] public allProjects;            // 所有專案的地址列表
    mapping(address => bool) public projectExists;   // 檢查某地址是否為已創建的專案

    // 募資期限選項（1 => 30天, 2 => 60天, 3 => 90天）
    mapping(uint8 => uint256) public durationOptions;
    mapping(address => uint256) public projectDeadlines; // 紀錄每個專案的截止時間

    // 事件定義
    event ProjectCreated(
        address indexed projectAddress,
        address indexed creator,
        uint256 target,
        uint8 durationChoice,
        uint256 deadline
    );
    event AutoContractSet(address indexed autoContract);
    event NFTMinted(address indexed to, uint256 indexed tokenId, uint256 projectId, uint256 weight);
    event AutoEventHandled(uint256 indexed milestoneIndex, uint8 outcome);

    // 錯誤定義
    error NotOwner();
    error InvalidDurationChoice();
    error NotProject();
    error NotAutoContract();
    error InvalidAutoContractAddress();

    /**
     * @dev Constructor，設置擁有者為部署者，部署 NFT 合約，並設定募資期限選項
     */
    constructor() {
        owner = msg.sender;

        // 部署中央化的 NFT 合約，並轉移擁有權給 Factory
        nftContract = new DMartERC721("DMartNFT","DMART");
        nftContract.transferOwnership(address(this));

        // 設定預設的募資期限選項
        durationOptions[1] = 30 days;
        durationOptions[2] = 60 days;
        durationOptions[3] = 90 days;
    }

    // ========== 修飾符 ==========
    
    /**
     * @dev 僅限擁有者呼叫的修飾符
     */
    modifier onlyOwnerFunc() {
        if(msg.sender != owner){
            revert NotOwner();
        }
        _;
    }

    /**
     * @dev 僅限已建立的專案呼叫的修飾符
     */
    modifier onlyProject() {
        if(!isProject(msg.sender)){
            revert NotProject();
        }
        _;
    }

    /**
     * @dev 僅限已設定的自動化合約呼叫的修飾符
     */
    modifier onlyAuto() {
        if(address(autoContract) == address(0) || msg.sender != address(autoContract)) {
            revert NotAutoContract();
        }
        _;
    }

    // ========== 外部與公共函式 ==========
    
    /**
     * @dev 設置或更新自動化合約地址，僅限擁有者呼叫
     * @param _autoContract 新的自動化合約地址
     */
    function setAutoContract(address _autoContract) external onlyOwnerFunc {
        require(_autoContract != address(0), "Invalid auto contract address");
        autoContract = DMartProjectAuto(_autoContract);
        emit AutoContractSet(_autoContract);
    }

    /**
     * @dev 新增或修改募資期限選項，僅限擁有者呼叫
     * @param index 募資期限選項編號（1, 2, 3）
     * @param secondsValue 對應的秒數
     */
    function setDurationOption(uint8 index, uint256 secondsValue) external onlyOwnerFunc {
        require(index >=1 && index <=3, "Invalid duration index");
        durationOptions[index] = secondsValue;
    }

    /**
     * @dev 創建一個新的專案，使用指定的 USDT、AavePool 與 aToken 地址，僅限擁有者呼叫
     * @param creator 募資專案發起人
     * @param platform 平台地址，用於接收利息分潤
     * @param target 募資目標金額（100%）
     * @param durationChoice 募資期限選項（1=>30天, 2=>60天, 3=>90天）
     * @param defaultUSDT USDT 代幣地址
     * @param defaultAavePool Aave Pool 地址
     * @param defaultAToken Aave 對應的 aToken 地址
     * @return projectAddress 新創建的專案合約地址
     */
    function createProject(
        address creator,
        address platform,
        uint256 target,
        uint8 durationChoice,
        address defaultUSDT,
        address defaultAavePool,
        address defaultAToken
    ) external onlyOwnerFunc returns(address projectAddress) {
        // 確認募資期限選項有效
        uint256 dur = durationOptions[durationChoice];
        if(dur == 0) revert InvalidDurationChoice();

        // 部署新的 DMartProject 合約
        DMartProject p = new DMartProject();
        projectAddress = address(p);

        // 初始化專案，使用指定的 USDT、AavePool 與 aToken 地址
        p.initialize(
            creator,
            defaultUSDT,
            defaultAavePool,
            defaultAToken,
            platform,
            target
        );

        // 紀錄專案資訊
        allProjects.push(projectAddress);
        getProjectsByCreator[creator].push(projectAddress);
        projectExists[projectAddress] = true;
        projectDeadlines[projectAddress] = block.timestamp + dur;

        emit ProjectCreated(projectAddress, creator, target, durationChoice, projectDeadlines[projectAddress]);
        return projectAddress;
    }

    /**
     * @dev 由專案合約呼叫，用於投資人捐贈後鑄造 NFT
     * @param to NFT 接收者地址
     * @param projectId 專案 ID
     * @param weight NFT 的投票權重
     * @return tokenId 鑄造的 NFT Token ID
     */
    function mintNFT(address to, uint256 projectId, uint256 weight) external onlyProject returns(uint256 tokenId) {
        // 呼叫中央化的 NFT 合約鑄造 NFT
        nftContract.mint(to, projectId, weight);
        tokenId = nftContract.totalSupply(); // 獲取最新的 Token ID
        emit NFTMinted(to, tokenId, projectId, weight);
        return tokenId;
    }

    /**
     * @dev 由自動化合約呼叫，通知 Factory 某些事件（如投票結果）
     * @param milestoneIndex 里程碑索引
     * @param outcome 投票結果（1 => Yes, 2 => No）
     */
    function onAutoEvent(uint256 milestoneIndex, uint8 outcome) external onlyAuto {
        // 在此可以根據投票結果進行額外處理，現階段僅發出事件
        emit AutoEventHandled(milestoneIndex, outcome);
    }

    /**
     * @dev 檢查某地址是否為已創建的專案
     * @param addr 要檢查的地址
     * @return bool 是否為已創建的專案
     */
    function isProject(address addr) public view returns(bool){
        return projectExists[addr];
    }

    /**
     * @dev 獲取所有專案的數量
     * @return uint256 所有專案的數量
     */
    function allProjectsLength() external view returns(uint256){
        return allProjects.length;
    }

    /**
     * @dev 獲取某創建者所擁有的所有專案地址
     * @param creator 創建者地址
     * @return address[] 該創建者的所有專案地址陣列
     */
    function getProjects(address creator) external view returns(address[] memory){
        return getProjectsByCreator[creator];
    }

    /**
     * @dev 檢查專案是否到期且未達標，並執行退款
     *      可由管理者、Keeper 或任何人呼叫
     * @param projectAddr 專案合約地址
     */
    function checkProjectExpiredAndRefund(address projectAddr) external {
        // 確認該地址為已創建的專案
        require(projectExists[projectAddr], "Not a project");
        // 確認已超過募資截止時間
        require(block.timestamp > projectDeadlines[projectAddr], "Not expired yet");

        DMartProject p = DMartProject(projectAddr);
        // 若募資金額未達標，執行退款
        if(p.totalRaised() < p.target()){
            p.refundAllInvestors();
        }
    }
}


// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./DMartERC721.sol";
import "./DMartProject.sol";
import "./DMartProjectAuto.sol";

/**
 * @title DMartFactory (Demo Version)
 * @dev 精簡版本：不需要 USDT、水龍頭、Aave 等互動。僅示範專案建立與投票流程。
 */
contract DMartFactory {
    // ========== 省略: Owner、Event、Error 定義 ==========

    address public owner;
    DMartERC721 public nftContract;
    DMartProjectAuto public autoContract;

    mapping(address => address[]) public getProjectsByCreator;
    address[] public allProjects;
    mapping(address => bool) public projectExists;

    // 簡單的募資期限對照表
    mapping(uint8 => uint256) public durationOptions;
    mapping(address => uint256) public projectDeadlines; // project -> deadline

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

    error NotOwner();
    error NotProject();
    error NotAutoContract();
    error InvalidDurationChoice();

    constructor() {
        owner = msg.sender;

        // 部署集中化的 NFT 合約
        nftContract = new DMartERC721("DMartNFT", "DMART");
        nftContract.transferOwnership(address(this)); // Factory 管理 NFT 鑄造

        // 預設的募資期限
        durationOptions[1] = 30 days;
        durationOptions[2] = 60 days;
        durationOptions[3] = 90 days;
    }

    modifier onlyOwnerFunc() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }
    modifier onlyProject() {
        if (!projectExists[msg.sender]) revert NotProject();
        _;
    }
    modifier onlyAuto() {
        if (address(autoContract) == address(0) || msg.sender != address(autoContract)) {
            revert NotAutoContract();
        }
        _;
    }

    // ========== 設定 / 建立合約 相關 ==========

    function setAutoContract(address _auto) external onlyOwnerFunc {
        require(_auto != address(0), "Invalid auto contract");
        autoContract = DMartProjectAuto(_auto);
        emit AutoContractSet(_auto);
    }

    function setDurationOption(uint8 index, uint256 secondsValue) external onlyOwnerFunc {
        durationOptions[index] = secondsValue;
    }

    /**
     * @dev 建立專案 (Demo)：不需要傳入 USDT / Aave 參數，僅示範 target、title、image、durationChoice。
     */
    function createProject(
        address creator,
        uint256 target,
        uint8 durationChoice,
        string memory title,
        string memory image
    ) external onlyOwnerFunc returns (address projectAddress) {
        uint256 dur = durationOptions[durationChoice];
        if (dur == 0) revert InvalidDurationChoice();

        // 建立 DMartProject
        DMartProject p = new DMartProject();
        projectAddress = address(p);

        // 初始化時，不傳任何 USDT / Aave
        // 僅保留基本的 target, title, image
        p.initialize(creator, target, title, image);

        allProjects.push(projectAddress);
        getProjectsByCreator[creator].push(projectAddress);
        projectExists[projectAddress] = true;

        projectDeadlines[projectAddress] = block.timestamp + dur;

        emit ProjectCreated(projectAddress, creator, target, durationChoice, projectDeadlines[projectAddress]);
        return projectAddress;
    }

    // ========== NFT 鑄造 ==========

    function mintNFT(address to, uint256 projectId, uint256 weight) external onlyProject returns (uint256 tokenId) {
        nftContract.mint(to, projectId, weight);
        tokenId = nftContract.totalSupply();
        emit NFTMinted(to, tokenId, projectId, weight);
        return tokenId;
    }

    // ========== 自動化事件回調 ==========

    function onAutoEvent(uint256 milestoneIndex, uint8 outcome) external onlyAuto {
        emit AutoEventHandled(milestoneIndex, outcome);
    }

    // ========== 外部查詢/輔助 ==========

    function isProject(address addr) public view returns (bool) {
        return projectExists[addr];
    }

    function allProjectsLength() external view returns (uint256) {
        return allProjects.length;
    }

    function getProjects(address creator) external view returns (address[] memory) {
        return getProjectsByCreator[creator];
    }

    /**
     * @dev 簡單的檢查若已過期限且 totalRaised < target 就標記失敗。
     *      這裡只呼叫 project.failAndRefundAll() 或類似。
     */
    function checkProjectExpiredAndRefund(address projectAddr) external {
        require(projectExists[projectAddr], "Not a project");
        require(block.timestamp > projectDeadlines[projectAddr], "Not expired yet");

        DMartProject p = DMartProject(projectAddr);
        if (p.totalRaised() < p.target()) {
            p.failAndRefundAll();
        }
    }
}


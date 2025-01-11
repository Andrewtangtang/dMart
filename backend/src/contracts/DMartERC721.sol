// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

// 引入 OpenZeppelin 的 ERC721 標準實現
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DMartERC721
 * @dev 管理 NFT 的鑄造和追蹤。每個 NFT 代表投資者在特定專案中的貢獻和投票權重。
 *      只有 Factory 合約的擁有者可以鑄造新的 NFT。
 */
contract DMartERC721 is ERC721, Ownable {
    // 合約擁有者（Factory 合約）的地址
    address private _owner;

    // 代幣 ID 的計數器，每次鑄造時遞增
    uint256 private _tokenIds;

    /**
     * @dev 儲存每個 NFT 的元數據結構。
     * @param projectID 此 NFT 所屬的專案 ID。
     * @param weight 此 NFT 的投票權重。
     */
    struct TokenMetadata {
        uint256 projectID;
        uint256 weight;
    }

    // 從 Token ID 到其元數據的映射
    mapping(uint256 => TokenMetadata) public tokenMetadata;

    // 從專案 ID 到與該專案相關的 Token ID 陣列的映射
    mapping(uint256 => uint256[]) public projectTokens;

    /**
     * @dev 當新的 NFT 被鑄造時觸發。
     * @param to 接收 NFT 的地址。
     * @param tokenId 被鑄造 NFT 的 ID。
     * @param projectId NFT 所屬的專案 ID。
     * @param weight NFT 的投票權重。
     */
    event TokenMinted(address indexed to, uint256 indexed tokenId, uint256 projectId, uint256 weight);

    // 未經授權訪問的自訂錯誤
    error NotOwner();

    /**
     * @dev 構造函數，初始化 ERC721 代幣，設定名稱和符號。
     *      將部署者設為初始擁有者。
     * @param name_ ERC721 代幣集合的名稱。
     * @param symbol_ ERC721 代幣的符號。
     */
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) Ownable(msg.sender) {
        _owner = msg.sender; // 初始設定為部署地址（Factory 合約）
    }

    /**
     * @dev 限制函式訪問僅限合約擁有者。
     *      如果呼叫者不是擁有者，則以 `NotOwner` 錯誤回滾。
     */
    modifier OnlyOwner() {
        if (msg.sender != _owner) revert NotOwner();
        _;
    }

    /**
     * @dev 鑄造新的 NFT 給指定地址，並設定相關的專案 ID 和投票權重。
     *      只有合約擁有者（Factory）可以調用此函式。
     * @param to 接收被鑄造 NFT 的地址。
     * @param projectID NFT 所屬的專案 ID。
     * @param weight NFT 的投票權重。
     */
    function mint(
        address to,
        uint256 projectID,
        uint256 weight
    ) external OnlyOwner {
        _tokenIds += 1; // 增加代幣 ID 計數器
        uint256 newId = _tokenIds; // 指派新的代幣 ID

        _safeMint(to, newId); // 安全地鑄造 NFT 給指定地址
        tokenMetadata[newId] = TokenMetadata(projectID, weight); // 儲存元數據
        projectTokens[projectID].push(newId); // 將代幣與專案關聯

        emit TokenMinted(to, newId, projectID, weight); // 觸發鑄造事件
    }

    /**
     * @dev 返回已鑄造的 NFT 總數量。
     * @return NFT 的總供應量。
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIds;
    }

    /**
     * @dev 檢查特定地址是否持有與給定專案相關的任何 NFT。
     * @param voter 要檢查 NFT 擁有權的地址。
     * @param projectId 要驗證的專案 ID。
     * @return 如果地址持有至少一個該專案的 NFT，則返回 true，否則返回 false。
     */
    function hasVotingRights(address voter, uint256 projectId) external view returns (bool) {
        uint256 len = projectTokens[projectId].length; // 專案的代幣數量
        for (uint256 i = 0; i < len; i++) {
            uint256 tId = projectTokens[projectId][i];
            if (ownerOf(tId) == voter) {
                return true; // 該地址擁有該專案的 NFT
            }
        }
        return false; // 該地址未持有該專案的 NFT
    }

    /**
     * @dev 獲取特定地址在給定專案中的總投票權重。
     *      將該地址持有的所有該專案的 NFT 的權重相加。
     * @param voter 要計算投票權重的地址。
     * @param projectId 要計算的專案 ID。
     * @return 該地址在該專案中的總投票權重。
     */
    function getVotingWeight(address voter, uint256 projectId) external view returns (uint256) {
        uint256 totalWeight = 0;
        uint256 len = projectTokens[projectId].length; // 專案的代幣數量
        for (uint256 i = 0; i < len; i++) {
            uint256 tId = projectTokens[projectId][i];
            if (ownerOf(tId) == voter) {
                totalWeight += tokenMetadata[tId].weight; // 累加投票權重
            }
        }
        return totalWeight;
    }

    /**
     * @dev 獲取特定 NFT 的元數據。
     * @param tokenId 要查詢的 NFT ID。
     * @return projectID NFT 所屬的專案 ID。
     * @return weight NFT 的投票權重。
     */
    function getTokenInfo(uint256 tokenId) external view returns (uint256 projectID, uint256 weight) {
        TokenMetadata memory meta = tokenMetadata[tokenId];
        return (meta.projectID, meta.weight);
    }

    /**
     * @dev 獲取與特定專案相關的所有 NFT ID。
     * @param projectId 要查詢的專案 ID。
     * @return 與該專案相關的 NFT ID 陣列。
     */
    function getProjectTokens(uint256 projectId) external view returns (uint256[] memory) {
        return projectTokens[projectId];
    }
}


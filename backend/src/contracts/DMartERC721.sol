// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract DMartERC721 is ERC721 {
    /// @dev 只有一個合約Owner（通常是 Factory）可以呼叫 mint()
    address private _owner;
    
    /// @dev 自動遞增的 TokenID 計數器
    uint256 private _tokenIds;

    /// @dev 每個 Token 所屬的專案ID 和投票權重
    struct TokenMetadata {
        uint256 projectID; // 所屬專案 ID
        uint256 weight;    // 投票權重
    }

    /// @dev TokenID => Metadata
    mapping(uint256 => TokenMetadata) public tokenMetadata;

    /// @dev 專案ID => TokenIDs
    mapping(uint256 => uint256[]) public projectTokens;

    // ========== Events ==========
    event TokenMinted(address indexed to, uint256 indexed tokenId, uint256 projectId, uint256 weight);

    // ========== Errors ==========
    error NotOwner();

    // ========== Constructor ==========
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        _owner = msg.sender;
    }

    // ========== Modifiers ==========
    modifier onlyOwner() {
        if (msg.sender != _owner) {
            revert NotOwner();
        }
        _;
    }

    // ========== Mint邏輯 ==========
    /**
     * @notice 鑄造新的 NFT 給 to，並記錄其 projectID、投票權重
     * @param to 接收 NFT 的地址
     * @param projectID 專案 ID
     * @param weight 此 Token 的投票權重
     */
    function mint(
        address to, 
        uint256 projectID, 
        uint256 weight
    ) external onlyOwner {
        _tokenIds += 1;
        uint256 newId = _tokenIds;

        // 1. 鑄造 NFT
        _safeMint(to, newId);

        // 2. 記錄 metadata
        tokenMetadata[newId] = TokenMetadata({
            projectID: projectID,
            weight: weight
        });
        
        // 3. 更新 projectTokens 對應表
        projectTokens[projectID].push(newId);

        emit TokenMinted(to, newId, projectID, weight);
    }

    /**
     * @dev 回傳已經鑄造的所有 Token 數量
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIds;
    }

    // ========== 投票相關查詢邏輯 ==========
    /**
     * @notice 檢查指定 voter 是否擁有某專案的投票權
     * @param voter 要查詢的投票者地址
     * @param projectId 要查詢的專案ID
     * @return true 若 voter 持有該專案的任一個 Token
     */
    function hasVotingRights(address voter, uint256 projectId) external view returns (bool) {
        uint256 len = projectTokens[projectId].length;
        for (uint256 i = 0; i < len; i++) {
            uint256 tId = projectTokens[projectId][i];
            if (ownerOf(tId) == voter) {
                return true;
            }
        }

        return false;
    }

    /**
     * @notice 取得指定 voter 在某專案的投票權重
     * @param voter 要查詢的投票者地址
     * @param projectId 要查詢的專案ID
     * @return 權重數值 (若沒有 Token 則回傳 0)
     */
    function getVotingWeight(address voter, uint256 projectId) external view returns (uint256) {
        uint256 len = projectTokens[projectId].length;
        for (uint256 i = 0; i < len; i++) {
            uint256 tId = projectTokens[projectId][i];
            if (ownerOf(tId) == voter) {
                return tokenMetadata[tId].weight;
            }
        }

        return 0;
    }

    // ========== 只讀輔助 ==========
    /**
     * @notice 查詢 Token ID 對應的專案ID與投票權重
     * @param tokenId 要查詢的 Token
     * @return projectID 該 Token 屬於哪個專案
     * @return weight   該 Token 的投票權重
     */
    function getTokenInfo(uint256 tokenId) external view returns (uint256 projectID, uint256 weight) {
        TokenMetadata memory meta = tokenMetadata[tokenId];
        return (meta.projectID, meta.weight);
    }

    /**
     * @notice 查詢專案底下的所有 TokenID
     * @param projectId 要查詢的專案ID
     * @return tokenIds 該專案所有的 TokenID 陣列
     */
    function getProjectTokens(uint256 projectId) external view returns (uint256[] memory) {
        return projectTokens[projectId];
    }
}

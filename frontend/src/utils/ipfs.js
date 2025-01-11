// IPFS Gateway URL
const GATEWAY_URL = "https://ipfs.io/ipfs/";

// 將 CID 轉換為完整的 IPFS URL
export const getIPFSUrl = (cid) => {
  if (!cid) return '';
  return `${GATEWAY_URL}${cid}`;
};

// 從 IPFS URL 中提取 CID
export const getCIDFromUrl = (url) => {
  if (!url) return '';
  return url.replace(GATEWAY_URL, '');
}; 
import { ethers } from 'ethers';
import Web3Modal from 'web3modal';

class Web3Service {
  constructor() {
    this.web3Modal = new Web3Modal({
      network: "sepolia", // 使用 Sepolia 測試網
      cacheProvider: true,
      providerOptions: {}
    });
    
    this.provider = null;
    this.signer = null;
    this.account = null;
  }

  async connectWallet() {
    try {
      console.log('開始連接錢包...');
      // 連接錢包
      const provider = await this.web3Modal.connect();
      console.log('已獲取 provider');
      
      this.provider = new ethers.providers.Web3Provider(provider);
      console.log('已創建 ethers provider');
      
      // 獲取簽名者和帳戶
      this.signer = this.provider.getSigner();
      console.log('已獲取 signer');
      
      this.account = await this.signer.getAddress();
      console.log('已獲取帳戶地址:', this.account);
      
      // 獲取網路資訊
      const network = await this.provider.getNetwork();
      console.log('當前網路:', network);
      
      // 監聽錢包事件
      provider.on("accountsChanged", this.handleAccountsChanged);
      provider.on("chainChanged", this.handleChainChanged);
      provider.on("disconnect", this.handleDisconnect);
      
      return {
        address: this.account,
        provider: this.provider,
        signer: this.signer
      };
    } catch (error) {
      console.error("錢包連接詳細錯誤:", error);
      if (error.code === 4001) {
        throw new Error('用戶拒絕了連接請求');
      } else if (error.code === -32002) {
        throw new Error('MetaMask 已經有一個待處理的請求，請檢查 MetaMask');
      } else {
        throw error;
      }
    }
  }

  async disconnectWallet() {
    if (this.provider?.provider?.disconnect) {
      await this.provider.provider.disconnect();
    }
    await this.web3Modal.clearCachedProvider();
    this.provider = null;
    this.signer = null;
    this.account = null;
  }

  handleAccountsChanged = (accounts) => {
    if (accounts.length === 0) {
      // 用戶已斷開錢包
      this.disconnectWallet();
    } else {
      // 用戶切換了帳戶
      this.account = accounts[0];
      window.location.reload();
    }
  };

  handleChainChanged = () => {
    // 當鏈改變時重新載入頁面
    window.location.reload();
  };

  handleDisconnect = () => {
    // 斷開連接時清理狀態
    this.disconnectWallet();
  };

  // 檢查是否在正確的網路上
  async checkNetwork() {
    if (!this.provider) return false;
    
    try {
      const network = await this.provider.getNetwork();
      console.log('檢查網路:', network);
      return network.chainId === 11155111; // Sepolia 的 chainId
    } catch (error) {
      console.error('檢查網路失敗:', error);
      return false;
    }
  }

  // 獲取當前連接的帳戶
  getCurrentAccount() {
    return this.account;
  }

  // 檢查是否已連接
  isConnected() {
    return !!this.account && !!this.provider;
  }
}

export const web3Service = new Web3Service();
export default web3Service; 
import React, { useState, useEffect } from 'react';
import web3Service from '../services/web3Service';

const LoginButton = () => {
  const [isConnected, setIsConnected] = useState(false);
  const [account, setAccount] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    // 檢查是否已經連接
    const checkConnection = async () => {
      if (web3Service.isConnected()) {
        setIsConnected(true);
        setAccount(web3Service.getCurrentAccount());
      }
    };
    
    checkConnection();
  }, []);

  const handleConnect = async () => {
    try {
      setIsLoading(true);
      const { address } = await web3Service.connectWallet();
      setIsConnected(true);
      setAccount(address);
      
      // 檢查網路
      const isCorrectNetwork = await web3Service.checkNetwork();
      if (!isCorrectNetwork) {
        alert('請切換到 Sepolia 測試網');
      }
    } catch (error) {
      console.error('連接錢包失敗:', error);
      alert('連接錢包失敗，請確保已安裝 MetaMask');
    } finally {
      setIsLoading(false);
    }
  };

  const handleDisconnect = async () => {
    try {
      await web3Service.disconnectWallet();
      setIsConnected(false);
      setAccount('');
    } catch (error) {
      console.error('斷開連接失敗:', error);
    }
  };

  const formatAddress = (address) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  return (
    <div>
      {isConnected ? (
        <div className="flex items-center gap-2">
          <span className="text-sm text-gray-600">
            {formatAddress(account)}
          </span>
          <button
            onClick={handleDisconnect}
            className="px-4 py-2 text-white bg-[#FFAD36] rounded-md hover:bg-[#FF9D16] transition-colors"
          >
            斷開連接
          </button>
        </div>
      ) : (
        <button
          onClick={handleConnect}
          disabled={isLoading}
          className={`px-4 py-2 text-white rounded-md transition-colors ${
            isLoading 
              ? 'bg-gray-400 cursor-not-allowed' 
              : 'bg-[#FFAD36] hover:bg-[#FF9D16]'
          }`}
        >
          {isLoading ? '連接中...' : '連接錢包'}
        </button>
      )}
    </div>
  );
};

export default LoginButton; 
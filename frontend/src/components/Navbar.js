import React, { useState, useEffect, useRef } from 'react';
import { Link } from 'react-router-dom';
import web3Service from '../services/web3Service';

const Navbar = () => {
  const [isUserMenuOpen, setIsUserMenuOpen] = useState(false);
  const [isConnected, setIsConnected] = useState(false);
  const [account, setAccount] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const menuRef = useRef(null);
  
  const categories = [
    '地方創生',
    '時尚',
    '設計',
    '藝術',
    '展演',
    '科技',
    '教育',
    '更多分類'
  ];

  useEffect(() => {
    // 檢查是否已經連接
    const checkConnection = async () => {
      if (web3Service.isConnected()) {
        setIsConnected(true);
        setAccount(web3Service.getCurrentAccount());
      }
    };
    
    checkConnection();

    // 添加點擊外部關閉選單的事件監聽
    const handleClickOutside = (event) => {
      if (menuRef.current && !menuRef.current.contains(event.target)) {
        setIsUserMenuOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  const handleConnect = async () => {
    try {
      setIsLoading(true);
      
      // 檢查是否安裝了 MetaMask
      if (!window.ethereum) {
        throw new Error('請先安裝 MetaMask');
      }

      const { address } = await web3Service.connectWallet();
      
      // 檢查網路
      const isCorrectNetwork = await web3Service.checkNetwork();
      if (!isCorrectNetwork) {
        // 嘗試切換網路
        try {
          await window.ethereum.request({
            method: 'wallet_switchEthereumChain',
            params: [{ chainId: '0xaa36a7' }], // Sepolia 的 chainId
          });
        } catch (switchError) {
          throw new Error('請手動切換到 Sepolia 測試網');
        }
      }

      setIsConnected(true);
      setAccount(address);
    } catch (error) {
      console.error('連接錢包失敗:', error);
      alert(error.message || '連接錢包失敗，請確保已安裝 MetaMask 並切換到 Sepolia 測試網');
    } finally {
      setIsLoading(false);
    }
  };

  const handleDisconnect = async () => {
    try {
      await web3Service.disconnectWallet();
      setIsConnected(false);
      setAccount('');
      setIsUserMenuOpen(false);
    } catch (error) {
      console.error('斷開連接失敗:', error);
    }
  };

  const formatAddress = (address) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  return (
    <nav className="bg-[#00AA9F] shadow-md">
      <div className="max-w-7xl mx-auto px-4 py-4">
        <div className="flex justify-between items-center h-16">
          {/* Logo */}
          <div className="flex-shrink-0">
            <Link to="/" className="text-2xl font-bold text-white hover:text-white/90 transition-colors">
              dMart
            </Link>
          </div>

          {/* Search Bar */}
          <div className="flex-1 max-w-2xl mx-4">
            <div className="relative">
              <input
                type="text"
                className="w-full px-4 py-2.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-white/50"
                placeholder="搜尋募資項目..."
              />
              <button className="absolute right-3 top-2.5">
                <svg className="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
              </button>
            </div>
          </div>

          {/* User Menu or Connect Button */}
          <div className="relative" ref={menuRef}>
            {isConnected ? (
              <div>
                <button
                  className="flex items-center space-x-2 text-white hover:text-white/90 transition-colors"
                  onClick={() => setIsUserMenuOpen(!isUserMenuOpen)}
                >
                  <img
                    src="https://picsum.photos/32/32"
                    alt="用戶頭像"
                    className="w-8 h-8 rounded-full"
                  />
                  <span className="text-white">{formatAddress(account)}</span>
                  <svg
                    className="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M19 9l-7 7-7-7"
                    />
                  </svg>
                </button>

                {/* 下拉選單 */}
                {isUserMenuOpen && (
                  <div className="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg py-1 z-50">
                    <Link
                      to="/profile"
                      className="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                      onClick={() => setIsUserMenuOpen(false)}
                    >
                      個人資料
                    </Link>
                    <Link
                      to="/my-projects"
                      className="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                      onClick={() => setIsUserMenuOpen(false)}
                    >
                      我的專案
                    </Link>
                    <Link
                      to="/bookmarks"
                      className="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                      onClick={() => setIsUserMenuOpen(false)}
                    >
                      收藏清單
                    </Link>
                    <button
                      onClick={() => {
                        handleDisconnect();
                        setIsUserMenuOpen(false);
                      }}
                      className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    >
                      斷開連接
                    </button>
                  </div>
                )}
              </div>
            ) : (
              <div className="flex items-center gap-2">
                <img
                  src="https://upload.wikimedia.org/wikipedia/commons/3/36/MetaMask_Fox.svg"
                  alt="MetaMask"
                  className="w-8 h-8"
                />
                <button 
                  onClick={handleConnect}
                  disabled={isLoading}
                  className={`bg-[#FFAD36] text-white px-6 py-2.5 rounded-md hover:bg-[#FF9D16] transition-colors ${
                    isLoading ? 'opacity-50 cursor-not-allowed' : ''
                  }`}
                >
                  {isLoading ? '連接中...' : '連接錢包'}
                </button>
              </div>
            )}
          </div>
        </div>

        {/* Categories */}
        <div className="flex space-x-8 py-4 mt-2">
          {categories.map((category) => (
            <button
              key={category}
              className="text-white hover:text-white/80 transition-colors"
            >
              {category}
            </button>
          ))}
        </div>
      </div>
    </nav>
  );
};

export default Navbar; 
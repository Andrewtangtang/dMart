import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import LoginModal from './LoginModal';

const Navbar = () => {
  const [isLoginModalOpen, setIsLoginModalOpen] = useState(false);
  const [isUserMenuOpen, setIsUserMenuOpen] = useState(false);
  // 模擬用戶登入狀態
  const [user, setUser] = useState(null);
  
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

  const handleLogin = (userData) => {
    setUser(userData);
    setIsLoginModalOpen(false);
  };

  const handleLogout = () => {
    setUser(null);
    setIsUserMenuOpen(false);
  };

  return (
    <>
      <nav className="bg-[#00AA9F] shadow-md">
        <div className="max-w-7xl mx-auto px-4 pt-5">
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
                  <span className="text-gray-400">×</span>
                </button>
              </div>
            </div>

            {/* User Menu or Login Button */}
            <div className="relative">
              {user ? (
                <div>
                  <button
                    className="flex items-center space-x-2 text-white hover:text-white/90 transition-colors"
                    onClick={() => setIsUserMenuOpen(!isUserMenuOpen)}
                  >
                    <img
                      src={user.avatar || 'https://picsum.photos/32/32'}
                      alt="用戶頭像"
                      className="w-8 h-8 rounded-full"
                    />
                    <span>{user.name}</span>
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
                      >
                        個人資料
                      </Link>
                      <Link
                        to="/my-projects"
                        className="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                      >
                        我的專案
                      </Link>
                      <Link
                        to="/bookmarks"
                        className="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                      >
                        收藏清單
                      </Link>
                      <button
                        onClick={handleLogout}
                        className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                      >
                        登出
                      </button>
                    </div>
                  )}
                </div>
              ) : (
                <button 
                  className="bg-[#FFAD36] text-white px-6 py-2.5 rounded-md hover:bg-[#FF9D16] transition-colors"
                  onClick={() => setIsLoginModalOpen(true)}
                >
                  登入/註冊
                </button>
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

      <LoginModal 
        isOpen={isLoginModalOpen} 
        onClose={() => setIsLoginModalOpen(false)}
        onLogin={handleLogin}
      />
    </>
  );
};

export default Navbar; 
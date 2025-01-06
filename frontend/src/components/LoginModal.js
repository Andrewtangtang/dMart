import React, { useState } from 'react';

const LoginModal = ({ isOpen, onClose, onLogin }) => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  if (!isOpen) return null;

  const handleSubmit = (e) => {
    e.preventDefault();
    setError('');

    // 模擬登入驗證
    if (email && password) {
      // 模擬成功登入
      const mockUserData = {
        id: 1,
        name: email.split('@')[0], // 使用郵箱前綴作為用戶名
        email: email,
        avatar: `https://picsum.photos/seed/${email}/32/32`, // 根據郵箱生成隨機頭像
      };
      
      onLogin(mockUserData);
    } else {
      setError('請輸入電子郵件和密碼');
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg p-8 max-w-md w-full mx-4">
        <div className="text-center mb-8">
          <h2 className="text-2xl font-bold text-[#00AA9F]">dMart</h2>
          <p className="text-gray-600 mt-2">距離夢想實現的第一步之遙</p>
        </div>

        {error && (
          <div className="mb-4 p-2 bg-red-100 text-red-600 rounded-md text-sm">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-1">
              電子郵件
            </label>
            <input
              type="email"
              id="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-[#00AA9F] focus:border-transparent"
              placeholder="請輸入電子郵件"
              required
            />
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-1">
              密碼
            </label>
            <input
              type="password"
              id="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-[#00AA9F] focus:border-transparent"
              placeholder="請輸入密碼"
              required
            />
          </div>

          <div className="flex items-center justify-between text-sm">
            <div className="flex items-center">
              <input
                type="checkbox"
                id="remember"
                className="h-4 w-4 text-[#00AA9F] focus:ring-[#00AA9F] border-gray-300 rounded"
              />
              <label htmlFor="remember" className="ml-2 text-gray-600">
                記住我
              </label>
            </div>
            <button type="button" className="text-[#00AA9F] hover:text-[#009990]">
              忘記密碼？
            </button>
          </div>

          <button
            type="submit"
            className="w-full bg-[#FFAD36] text-white py-2.5 rounded-md hover:bg-[#FF9D16] transition-colors font-medium"
          >
            登入
          </button>

          <div className="text-center text-sm text-gray-600">
            還沒有帳號？
            <button type="button" className="text-[#00AA9F] hover:text-[#009990] ml-1">
              立即註冊
            </button>
          </div>
        </form>

        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-gray-400 hover:text-gray-600"
        >
          <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    </div>
  );
};

export default LoginModal; 
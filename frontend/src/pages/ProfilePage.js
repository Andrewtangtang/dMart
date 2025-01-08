import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import ProjectCard from '../components/ProjectCard';
import { mockProjects } from '../data/mockData';
import CreateProjectModal from '../components/CreateProjectModal';
import web3Service from '../services/web3Service';

const ProfilePage = () => {
  const [activeTab, setActiveTab] = useState('my-projects');
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [walletAddress, setWalletAddress] = useState('');

  useEffect(() => {
    if (web3Service.isConnected()) {
      setWalletAddress(web3Service.getCurrentAccount());
    }
  }, []);

  // 模擬用戶數據
  const userStats = {
    participatedCount: 51,
    createdCount: 1
  };

  return (
    <div className="container mx-auto px-8 mt-8">
      <div className="grid grid-cols-1 lg:grid-cols-4 gap-8">
        {/* 左側：用戶資訊 */}
        <div className="lg:col-span-1">
          <div className="bg-white rounded-lg shadow-md p-6 space-y-6">
            {/* 用戶頭像和名稱 */}
            <div className="text-center">
              <div className="w-32 h-32 mx-auto mb-4">
                <img
                  src="https://picsum.photos/200"
                  alt="用戶頭像"
                  className="w-full h-full rounded-full object-cover"
                />
              </div>
              <h2 className="text-xl font-bold">User Name</h2>
              <p className="text-gray-500 text-sm mt-1">abcdefg@gmail.com</p>
            </div>

            {/* 用戶錢包地址 */}
            <div>
              <p className="text-sm text-gray-500 mb-1">錢包地址</p>
              <div className="flex items-center gap-2 bg-gray-50 p-2 rounded-md">
                <code className="text-xs text-gray-700 flex-1 overflow-hidden text-ellipsis">
                  {walletAddress}
                </code>
                <button 
                  className="text-[#00AA9F] hover:text-[#009990]"
                  onClick={() => {
                    navigator.clipboard.writeText(walletAddress);
                    alert('已複製到剪貼簿');
                  }}
                >
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                  </svg>
                </button>
              </div>
            </div>

            {/* 參與統計 */}
            <div className="grid grid-cols-2 gap-4 pt-4 border-t">
              <div className="text-center">
                <p className="text-3xl font-bold text-[#00AA9F]">{userStats.participatedCount}</p>
                <p className="text-sm text-gray-500">已參與募資</p>
              </div>
              <div className="text-center">
                <p className="text-3xl font-bold text-[#00AA9F]">{userStats.createdCount}</p>
                <p className="text-sm text-gray-500">已發起募資</p>
              </div>
            </div>
          </div>
        </div>

        {/* 右側：導航和內容 */}
        <div className="lg:col-span-3">
          {/* 頂部導航區域 */}
          <div className="border-b mb-8">
            <div className="flex justify-between items-center">
              {/* 分頁按鈕 */}
              <div className="flex space-x-4">
                <button
                  className={`px-8 py-4 text-sm font-medium transition-colors relative
                    ${activeTab === 'my-projects' 
                      ? 'text-[#00AA9F] border-b-2 border-[#00AA9F]' 
                      : 'text-gray-500 hover:text-[#00AA9F]'}`}
                  onClick={() => setActiveTab('my-projects')}
                >
                  我發起的募資
                  <span className="ml-2 text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full">
                    {userStats.createdCount}
                  </span>
                </button>
                <button
                  className={`px-8 py-4 text-sm font-medium transition-colors relative
                    ${activeTab === 'participated' 
                      ? 'text-[#00AA9F] border-b-2 border-[#00AA9F]' 
                      : 'text-gray-500 hover:text-[#00AA9F]'}`}
                  onClick={() => setActiveTab('participated')}
                >
                  我參與的募資
                  <span className="ml-2 text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full">
                    {userStats.participatedCount}
                  </span>
                </button>
                <button
                  className={`px-8 py-4 text-sm font-medium transition-colors relative
                    ${activeTab === 'bookmarks' 
                      ? 'text-[#00AA9F] border-b-2 border-[#00AA9F]' 
                      : 'text-gray-500 hover:text-[#00AA9F]'}`}
                  onClick={() => setActiveTab('bookmarks')}
                >
                  我收藏的募資
                </button>
              </div>

              {/* 發起募資按鈕 */}
              <button
                onClick={() => setIsCreateModalOpen(true)}
                className="flex items-center gap-2 px-6 py-2 bg-[#FFAD36] text-white rounded-full hover:bg-[#FF9D16] transition-colors"
              >
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                </svg>
                發起募資
              </button>
            </div>
          </div>

          {/* 專案列表 */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {activeTab === 'my-projects' && mockProjects.slice(0, 1).map(project => (
              <ProjectCard key={project.id} {...project} />
            ))}
            {activeTab === 'participated' && mockProjects.slice(0, 3).map(project => (
              <ProjectCard key={project.id} {...project} />
            ))}
            {activeTab === 'bookmarks' && mockProjects.slice(3, 4).map(project => (
              <ProjectCard key={project.id} {...project} />
            ))}
          </div>

          {/* 空狀態 */}
          {((activeTab === 'my-projects' && userStats.createdCount === 0) ||
            (activeTab === 'participated' && userStats.participatedCount === 0) ||
            (activeTab === 'bookmarks' && mockProjects.length === 0)) && (
            <div className="text-center py-12">
              <div className="text-gray-400 mb-4">
                <svg className="w-16 h-16 mx-auto" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
                </svg>
              </div>
              <h3 className="text-lg font-medium text-gray-900 mb-2">
                {activeTab === 'my-projects' && '還沒有發起過募資專案'}
                {activeTab === 'participated' && '還沒有參與過募資專案'}
                {activeTab === 'bookmarks' && '還沒有收藏的募資專案'}
              </h3>
              <p className="text-gray-500">
                {activeTab === 'my-projects' && '點擊上方的「發起募資」按鈕來創建您的第一個專案'}
                {activeTab === 'participated' && '瀏覽首頁發現感興趣的專案並參與募資'}
                {activeTab === 'bookmarks' && '瀏覽專案時點擊收藏按鈕來保存感興趣的專案'}
              </p>
            </div>
          )}
        </div>
      </div>

      {/* 發起募資�窗 */}
      <CreateProjectModal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
      />
    </div>
  );
};

export default ProfilePage; 
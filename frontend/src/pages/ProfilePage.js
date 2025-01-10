import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import ProjectCard from '../components/ProjectCard';
import CreateProjectModal from '../components/CreateProjectModal';
import web3Service from '../services/web3Service';

// 獲取用戶資訊
const getUserProfile = async (address) => {
  // TODO: 這裡將來要改為實際從智能合約獲取資料
  return {
    address: address,
    name: 'John Doe',
    email: 'john@example.com',
    avatar: 'https://picsum.photos/200',
    participatedCount: 51,
    createdCount: 1
  };
};

// 獲取用戶發起的專案列表
const getUserCreatedProjects = async (address) => {
  // TODO: 這裡將來要改為實際從智能合約獲取資料
  return [
    {
      id: 1,
      title: '創新科技產品開發計畫',
      author: address,
      image: 'https://picsum.photos/400/300',
      progress: 75,
      currentAmount: 1500,
      targetAmount: 2000,
      category: '科技'
    }
  ];
};

// 獲取用戶參與的專案列表
const getUserParticipatedProjects = async (address) => {
  // TODO: 這裡將來要改為實際從智能合約獲取資料
  return [
    {
      id: 2,
      title: '永續時尚設計專案',
      author: '0x9876...4321',
      image: 'https://picsum.photos/400/301',
      progress: 100,
      currentAmount: 3000,
      targetAmount: 3000,
      category: '時尚'
    },
    {
      id: 3,
      title: '在地小農支持計畫',
      author: '0x2468...1357',
      image: 'https://picsum.photos/400/302',
      progress: 90,
      currentAmount: 4500,
      targetAmount: 5000,
      category: '地方創生'
    },
    {
      id: 4,
      title: '藝術展覽募資計畫',
      author: '0x1357...2468',
      image: 'https://picsum.photos/400/303',
      progress: 30,
      currentAmount: 600,
      targetAmount: 2000,
      category: '藝術'
    }
  ];
};

// 獲取用戶收藏的專案列表
const getUserBookmarkedProjects = async (address) => {
  // TODO: 這裡將來要改為實際從智能合約獲取資料
  return [
    {
      id: 5,
      title: '教育創新專案',
      author: '0x8765...4321',
      image: 'https://picsum.photos/400/304',
      progress: 45,
      currentAmount: 900,
      targetAmount: 2000,
      category: '教育'
    }
  ];
};

const ProfilePage = () => {
  const [activeTab, setActiveTab] = useState('my-projects');
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [userProfile, setUserProfile] = useState(null);
  const [createdProjects, setCreatedProjects] = useState([]);
  const [participatedProjects, setParticipatedProjects] = useState([]);
  const [bookmarkedProjects, setBookmarkedProjects] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const loadUserData = async () => {
      if (!web3Service.isConnected()) {
        setError('請先連接錢包');
        setLoading(false);
        return;
      }

      const address = web3Service.getCurrentAccount();
      
      try {
        setLoading(true);
        const [profile, created, participated, bookmarked] = await Promise.all([
          getUserProfile(address),
          getUserCreatedProjects(address),
          getUserParticipatedProjects(address),
          getUserBookmarkedProjects(address)
        ]);

        setUserProfile(profile);
        setCreatedProjects(created);
        setParticipatedProjects(participated);
        setBookmarkedProjects(bookmarked);
      } catch (err) {
        setError(err.message);
        console.error('獲取用戶資料失敗:', err);
      } finally {
        setLoading(false);
      }
    };

    loadUserData();
  }, []);

  if (loading) {
    return (
      <div className="container mx-auto px-8 py-12 text-center">
        <p>載入中...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="container mx-auto px-8 py-12 text-center text-red-600">
        <p>錯誤：{error}</p>
      </div>
    );
  }

  if (!userProfile) {
    return (
      <div className="container mx-auto px-8 py-12 text-center">
        <p>找不到用戶資料</p>
      </div>
    );
  }

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
                  src={userProfile.avatar}
                  alt="用戶頭像"
                  className="w-full h-full rounded-full object-cover"
                />
              </div>
              <h2 className="text-xl font-bold">{userProfile.name}</h2>
              <p className="text-gray-500 text-sm mt-1">{userProfile.email}</p>
            </div>

            {/* 用戶錢包地址 */}
            <div>
              <p className="text-sm text-gray-500 mb-1">錢包地址</p>
              <div className="flex items-center gap-2 bg-gray-50 p-2 rounded-md">
                <code className="text-xs text-gray-700 flex-1 overflow-hidden text-ellipsis">
                  {userProfile.address}
                </code>
                <button 
                  className="text-[#00AA9F] hover:text-[#009990]"
                  onClick={() => {
                    navigator.clipboard.writeText(userProfile.address);
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
                <p className="text-3xl font-bold text-[#00AA9F]">{userProfile.participatedCount}</p>
                <p className="text-sm text-gray-500">已參與募資</p>
              </div>
              <div className="text-center">
                <p className="text-3xl font-bold text-[#00AA9F]">{userProfile.createdCount}</p>
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
                    {createdProjects.length}
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
                    {participatedProjects.length}
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
                  <span className="ml-2 text-xs bg-gray-100 text-gray-600 px-2 py-0.5 rounded-full">
                    {bookmarkedProjects.length}
                  </span>
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
            {activeTab === 'my-projects' && createdProjects.map(project => (
              <ProjectCard key={project.id} {...project} />
            ))}
            {activeTab === 'participated' && participatedProjects.map(project => (
              <ProjectCard key={project.id} {...project} />
            ))}
            {activeTab === 'bookmarks' && bookmarkedProjects.map(project => (
              <ProjectCard key={project.id} {...project} />
            ))}
          </div>

          {/* 空狀態 */}
          {((activeTab === 'my-projects' && createdProjects.length === 0) ||
            (activeTab === 'participated' && participatedProjects.length === 0) ||
            (activeTab === 'bookmarks' && bookmarkedProjects.length === 0)) && (
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

      {/* 發起募資彈窗 */}
      <CreateProjectModal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
      />
    </div>
  );
};

export default ProfilePage; 
import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import ProjectCard from '../components/ProjectCard';
import CreateProjectModal from '../components/CreateProjectModal';
import web3Service from '../services/web3Service';
import { FactoryAbi } from "../data/FactoryAbi.json";
import { ProjectAbi } from "../data/ProjectAbi.json";

const infuraProjectId = process.env.REACT_APP_INFURA_PROJECT_ID;
const provider = new providers.JsonRpcProvider(`https://sepolia.infura.io/v3/${infuraProjectId}`);
const factoryAddress = process.env.REACT_APP_FACTORY_ADDRESS;
const factory = new Contract(factoryAddress, FactoryAbi, provider);

// 獲取用戶資訊
const getUserProfile = async (address) => {
  // TODO: 這裡將來要改為實際從智能合約獲取資料
  const [createdProjects, participatedProjects] = await Promise.all([
    getUserCreatedProjects(address),
    getUserParticipatedProjects(address)
  ]);

  return {
    address: address,
    avatar: 'https://picsum.photos/200',
    participatedCount: participatedProjects.length,
    createdCount: createdProjects.length
  };
};

// 獲取用戶發起的專案列表
const getUserCreatedProjects = async (creatorAddress) => {
  // TODO: 這裡將來要改為實際從智能合約獲取資料
  const allProjects = await factory.allProjects(); // Assuming this returns an array of all project addresses

  return await Promise.all(
    allProjects.map(async (address, index) => {
      const project = new ethers.Contract(address, ProjectAbi, provider); // Initialize the project contract

      // Fetch the creator and project details in parallel
      const [creator, title, image, target, totalRaised] = await Promise.all([
        project.creator().catch(() => "0x0000000000000000000000000000000000000000"), // Get creator address or default
        project.title().catch(() => "no title"), // Get title or default
        project.image().catch(() => null), // Get image or default
        project.target().catch(() => 0), // Get target amount or default
        project.totalRaised().catch(() => 0) // Get total raised or default
      ]);

      const resolvedImage = image ? getIPFSUrl(image) : 'https://picsum.photos/400/300';

      // Only include projects created by the specified creator
      if (creator.toLowerCase() === creatorAddress.toLowerCase()) {
        return {
          id: index + 1, // Unique ID based on index
          title,
          contractAddress: address,
          image: resolvedImage,
          targetAmount: target.toString(), // Convert BigNumber to string
          currentAmount: totalRaised.toString() // Convert BigNumber to string
        };
      }

      // If the creator does not match, return null
      return null;
    })
  ).then((projects) => projects.filter((project) => project !== null)); // Remove null entries

};

// 獲取用戶參與的專案列表
const getUserParticipatedProjects = async (participantAddress) => {
  // TODO: 這裡將來要改為實際從智能合約獲取資料
  const allProjects = await factory.allProjects(); // Assuming this returns an array of all project addresses

  return await Promise.all(
    allProjects.map(async (address, index) => {
      const project = new ethers.Contract(address, ProjectAbi, provider); // Initialize the project contract

      // Fetch the creator and project details in parallel
      const [title, image, target, totalRaised, events] = await Promise.all([
        project.title().catch(() => "no title"), // Get title or default
        project.image().catch(() => 'https://picsum.photos/400/300'), // Get image or default
        project.target().catch(() => 0), // Get target amount or default
        project.totalRaised().catch(() => 0), // Get total raised or default
        project.queryFilter(project.filters.Donated(participantAddress)).catch(() => []) // Get donation events
      ]);

      // Only include projects where the participant has donated
      if (events.length > 0) {
        return {
          id: index + 1, // Unique ID based on index
          title,
          contractAddress: address,
          image,
          targetAmount: target.toString(), // Convert BigNumber to string
          currentAmount: totalRaised.toString(), // Convert BigNumber to string
        };
      }

      // If no donation found, return null
      return null;
    })
  ).then((projects) => projects.filter((project) => project !== null)); // Remove null entries

};

const ProfilePage = () => {
  const [activeTab, setActiveTab] = useState('my-projects');
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [userProfile, setUserProfile] = useState(null);
  const [createdProjects, setCreatedProjects] = useState([]);
  const [participatedProjects, setParticipatedProjects] = useState([]);
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
        const [profile, created, participated] = await Promise.all([
          getUserProfile(address),
          getUserCreatedProjects(address),
          getUserParticipatedProjects(address)
        ]);

        setUserProfile(profile);
        setCreatedProjects(created);
        setParticipatedProjects(participated);
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
            {/* 用戶頭像 */}
            <div className="text-center">
              <div className="w-32 h-32 mx-auto mb-4">
                <img
                  src={userProfile.avatar}
                  alt="用戶頭像"
                  className="w-full h-full rounded-full object-cover"
                />
              </div>
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
              <ProjectCard 
                key={project.id} 
                {...project} 
                progress={Math.round((project.currentAmount / project.targetAmount) * 100)}
              />
            ))}
            {activeTab === 'participated' && participatedProjects.map(project => (
              <ProjectCard 
                key={project.id} 
                {...project} 
                progress={Math.round((project.currentAmount / project.targetAmount) * 100)}
              />
            ))}
          </div>

          {/* 空狀態 */}
          {((activeTab === 'my-projects' && createdProjects.length === 0) ||
            (activeTab === 'participated' && participatedProjects.length === 0)) && (
            <div className="text-center py-12">
              <div className="text-gray-400 mb-4">
                <svg className="w-16 h-16 mx-auto" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
                </svg>
              </div>
              <h3 className="text-lg font-medium text-gray-900 mb-2">
                {activeTab === 'my-projects' && '還沒有發起過募資專案'}
                {activeTab === 'participated' && '還沒有參與過募資專案'}
              </h3>
              <p className="text-gray-500">
                {activeTab === 'my-projects' && '點擊上方的「發起募資」按鈕來創建您的第一個專案'}
                {activeTab === 'participated' && '瀏覽首頁發現感興趣的專案並參與募資'}
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